#!/usr/bin/env bash
set -euo pipefail

if ! curl --fail --silent http://localhost:8000/health >/dev/null; then
  echo 'backend is not ready at http://localhost:8000'
  exit 1
fi

if ! curl --fail --silent http://localhost:4444/status >/dev/null; then
  echo 'chromedriver is not ready on port 4444'
  echo 'start it in another terminal: chromedriver --port=4444'
  exit 1
fi

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/trainer_web_core_flows_test.dart \
  -d chrome \
  --headless \
  --browser-dimension=1600x1024 \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8000/v1
