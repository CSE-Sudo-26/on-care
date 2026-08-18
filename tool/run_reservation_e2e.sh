#!/usr/bin/env bash
#
# 회원↔트레이너 예약·취소 실 API E2E (#637).
#
# 회원 앱과 트레이너 웹은 **서로 다른 Dart 패키지**라 한 프로세스에 함께 띄울 수 없다.
# 그래서 한 시나리오를 단계로 쪼개 번갈아 실행하고, 단계 사이의 상태는 서버 DB 와
# 상태 파일(id 만)로 넘긴다. 이 스크립트가 그 순서를 강제한다 — 순서가 곧 계약이다.
#
#   1. (트레이너) create-slot            미래 슬롯을 UI 로 연다
#   2. (회원)     reserve                그 자리를 보고 예약 · 재로그인 후에도 유지
#   3. (트레이너) verify-schedule        예약이 만든 일정이 트레이너 화면에 보인다
#   4. (회원)     cancel                 취소 · 좌석 복구 · 재예약 가능
#   5. (트레이너) verify-schedule-cancelled 일정이 취소 기록으로 남고 좌석 복구
#   6. (회원)     edge-cases             중복·권한·정원 경쟁이 초과 예약을 못 만든다
#   7. (트레이너) cleanup                이번 실행이 연 슬롯을 닫는다
#
# 매 실행은 **새 슬롯**을 연다. 앞선 실행이 중간에 죽어 예약이 남아 있어도 다음 실행이
# 그것을 건드리지 않는다 — 반복 실행이 서로 간섭하지 않는 것이 완료 조건이다.
#
# 사용법:
#   bash tool/run_reservation_e2e.sh
#   API_BASE_URL=http://localhost:8000/v1 bash tool/run_reservation_e2e.sh
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly API_BASE_URL="${API_BASE_URL:-http://localhost:8000/v1}"
readonly STATE_FILE="${E2E_STATE_FILE:-$(mktemp -t oncare_e2e_XXXXXX.json)}"
readonly FLUTTER="${FLUTTER:-flutter}"

# 백엔드 확인은 `/v1/healthz` 로 한다. `/health` 는 존재한 적 없거나 옮겨졌고,
# 그 경로로 확인하면 백엔드가 멀쩡해도 "준비 안 됨" 으로 읽힌다.
if ! curl --fail --silent --max-time 10 "${API_BASE_URL%/v1}/v1/healthz" >/dev/null; then
  echo "백엔드가 준비되지 않았습니다: ${API_BASE_URL%/v1}/v1/healthz" >&2
  echo "  cd backend && docker compose up -d" >&2
  exit 1
fi

: >"$STATE_FILE"
echo "상태 파일: $STATE_FILE"
echo "백엔드:    $API_BASE_URL"
echo

# 단계 실행. $1=패키지 디렉터리, $2=테스트 파일, $3=단계 이름
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

trainer() { run_phase frontend/flutter_trainer test_e2e/reservation_trainer_test.dart "$1"; }
member() { run_phase frontend/flutter test_e2e/reservation_member_test.dart "$1"; }

# 어느 단계에서 멈췄는지 남긴다. 단계 이름만으로 실패 지점이 특정된다.
failed_phase=''
report_failure() {
  if [ -n "$failed_phase" ]; then
    echo "::error::[$failed_phase] 에서 실패했습니다. 상태 파일: $STATE_FILE" >&2
    echo "이번 실행이 만든 슬롯·예약은 남아 있을 수 있습니다(다음 실행은 새 슬롯을 씁니다)." >&2
  fi
}
trap report_failure EXIT

for phase in create-slot reserve verify-schedule cancel verify-schedule-cancelled; do
  failed_phase="$phase"
  case "$phase" in
    reserve | cancel) member "$phase" ;;
    *) trainer "$phase" ;;
  esac
done

failed_phase='edge-cases'
member edge-cases

failed_phase='cleanup'
trainer cleanup

failed_phase=''
echo "✅ 예약·취소 실 API E2E 전 단계 통과"
