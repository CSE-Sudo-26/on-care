#!/usr/bin/env bash
#
# 회원↔담당 트레이너 텍스트 채팅 실 API E2E (#639).
#
# `tool/run_reservation_e2e.sh`(#637)와 같은 구조다 — 두 앱은 서로 다른 Dart 패키지라
# 한 프로세스에 함께 띄울 수 없어, 한 시나리오를 단계로 쪼개 번갈아 실행한다.
#
#   1. (회원)     member-send     회원 UI 발신이 서버에 한 건 남는다
#   2. (트레이너) trainer-thread  수신 · 열린 화면 polling · 읽음 처리 · UI 답장
#   3. (회원)     member-receive  답장 수신 · 열린 화면 polling · 읽음 · 재로그인 유지
#   4. (회원)     idempotency     같은 client_request_id 재시도가 한 건으로 접힌다
#   5. (회원)     isolation       다른 회원 스레드로 새지 않는다
#   6. 정리                        메시지와 파생 개인 RAG 문서를 DB 에서 지운다
#
# **정리가 이 스위트의 일부다.** 채팅은 삭제 API 가 없어서, 지우지 않으면 실행할 때마다
# 데모 대화가 늘고 AI 코치 근거까지 오염된다. 그래서 마지막 단계가 실패해도 정리는 돈다.
#
# 사용법:
#   bash tool/run_chat_e2e.sh
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly API_BASE_URL="${API_BASE_URL:-http://localhost:8000/v1}"
readonly STATE_FILE="${E2E_STATE_FILE:-$(mktemp -t oncare_chat_e2e_XXXXXX.json)}"
readonly FLUTTER="${FLUTTER:-flutter}"
# 실행마다 새 마커. 고정 마커면 앞선 실행의 정리가 실패했을 때 이번 실행의 단언이
# 남의 메시지를 세게 된다.
readonly MARKER="${E2E_MARKER:-e2e-639-$(date +%s)}"

if ! curl --fail --silent --max-time 10 "${API_BASE_URL%/v1}/v1/healthz" >/dev/null; then
  echo "백엔드가 준비되지 않았습니다: ${API_BASE_URL%/v1}/v1/healthz" >&2
  echo "  cd backend && docker compose up -d" >&2
  exit 1
fi

printf '{"marker":"%s"}' "$MARKER" >"$STATE_FILE"
echo "상태 파일: $STATE_FILE"
echo "마커:      $MARKER"
echo

run_phase() {
  local package="$1" target="$2" phase="$3"
  echo "── [$phase] $package"
  (
    cd "$ROOT/$package"
    "$FLUTTER" test "$target" \
      --dart-define=USE_MOCK_API=false \
      --dart-define=API_BASE_URL="$API_BASE_URL" \
      --dart-define=E2E_PHASE="$phase" \
      --dart-define=E2E_STATE_FILE="$STATE_FILE"
  )
  echo
}

member() { run_phase frontend/flutter test_e2e/chat_member_test.dart "$1"; }
trainer() { run_phase frontend/flutter_trainer test_e2e/chat_trainer_test.dart "$1"; }

# 정리는 실패 경로에서도 반드시 돈다. 지우지 않으면 다음 실행과 AI 코치 근거가 함께
# 오염되고, 그 오염은 이 스위트 밖에서 드러난다.
cleanup() {
  local status=$?
  echo "── [정리] 채팅 메시지와 파생 개인 RAG 문서 삭제"
  # 스크립트를 stdin 으로 흘려 넣는다. `python -m scripts.clean_e2e_chat` 로 부르면 이
  # 파일이 이미지에 들어간 뒤에만 동작해서, 고칠 때마다 이미지를 다시 만들어야 한다.
  #
  # 백엔드가 어디에 떠 있는지는 환경마다 다르다. 로컬은 compose 서비스라 컨테이너
  # 안에서 돌려야 하고, CI 는 러너에서 uvicorn 을 직접 띄우므로 컨테이너가 없다.
  # 컨테이너가 있으면 그 안에서, 없으면 러너의 python 으로 돌린다.
  if ! (
    cd "$ROOT/backend"
    if [ -n "$(docker compose ps -q app 2>/dev/null)" ]; then
      docker compose exec -T app python - --marker "$MARKER" <scripts/clean_e2e_chat.py
    else
      python - --marker "$MARKER" <scripts/clean_e2e_chat.py
    fi
  ); then
    echo "::error::정리에 실패했습니다. 남은 데이터: marker=$MARKER" >&2
    echo "  cd backend && python - --marker $MARKER <scripts/clean_e2e_chat.py" >&2
    echo "  (컨테이너로 띄웠다면 docker compose exec -T app 를 앞에 붙입니다)" >&2
    status=1
  fi
  if [ -n "${failed_phase:-}" ]; then
    echo "::error::[$failed_phase] 에서 실패했습니다. 상태 파일: $STATE_FILE" >&2
  elif [ "$status" -eq 0 ]; then
    echo "✅ 채팅 실 API E2E 전 단계 통과"
  fi
  exit "$status"
}
trap cleanup EXIT

failed_phase='member-send'
member member-send

failed_phase='trainer-thread'
trainer trainer-thread

for phase in member-receive idempotency isolation; do
  failed_phase="$phase"
  member "$phase"
done

failed_phase=''
