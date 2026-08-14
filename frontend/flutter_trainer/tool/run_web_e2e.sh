#!/usr/bin/env bash
set -euo pipefail

# 헬스 체크는 `/v1/healthz` 다. `/health` 로 물으면 백엔드가 멀쩡해도 404 가 돌아와
# `--fail` 이 0 이 아닌 코드를 내고, 이 스크립트가 "준비 안 됨" 으로 멈춘다.
if ! curl --fail --silent http://localhost:8000/v1/healthz >/dev/null; then
  echo 'backend is not ready at http://localhost:8000'
  exit 1
fi

if ! curl --fail --silent http://localhost:4444/status >/dev/null; then
  echo 'chromedriver is not ready on port 4444'
  echo 'start it in another terminal: chromedriver --port=4444'
  exit 1
fi

# 이 스위트는 화면마다 로그인부터 다시 한다(각 테스트가 로그아웃 상태에서 부팅한다).
# 픽스처의 회원 로그인까지 더하면 한 번 돌 때 로그인이 6~7 회다. 백엔드 기본 한도는
# IP·엔드포인트당 분당 10 회(`rate_limit_auth_per_minute`)라, 연달아 돌리면 로그인이
# 429 로 막히고 테스트는 "로그인 화면에서 안 넘어감" 으로 보인다. 백엔드를
# `RATE_LIMIT_ENABLED=false` 로 띄워 두고 돌린다.
echo 'note: run the backend with RATE_LIMIT_ENABLED=false — this suite logs in 6~7 times per run'

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/trainer_web_core_flows_test.dart \
  -d chrome \
  --headless \
  --browser-dimension=1600x1024 \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8000/v1
