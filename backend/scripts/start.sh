#!/usr/bin/env bash
# 운영 컨테이너 기동 엔트리포인트.
# 1) 스키마를 Alembic head 까지 마이그레이션(운영은 AUTO_CREATE_TABLES=false 권장 →
#    Alembic 이 유일한 스키마 소스). 2) uvicorn 시작.
# App Runner/프록시 뒤이므로 --proxy-headers 로 X-Forwarded-Proto 를 신뢰(HTTPS 판정).
set -euo pipefail

echo "[start] migrate (advisory-lock serialized)"
python scripts/migrate.py

# 포트: Railway 등 일부 플랫폼은 동적 $PORT 를 주입한다. 없거나 비어 있으면
# (App Runner·로컬·docker-compose) 8000 으로 폴백 → 한 이미지가 두 플랫폼 모두에서
# 그대로 뜬다.
PORT="${PORT:-8000}"
# 잘못 주입된 $PORT(비숫자·범위 밖)를 그대로 uvicorn 에 넘기면 불명확한 오류로
# 기동에 실패하므로, 여기서 1~65535 정수인지 검증하고 아니면 명확히 종료한다.
if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "[start] invalid PORT='${PORT}' — 1~65535 범위의 정수여야 합니다." >&2
  exit 1
fi
echo "[start] launching uvicorn on :${PORT}"
exec uvicorn app.main:app \
  --host 0.0.0.0 --port "${PORT}" \
  --proxy-headers --forwarded-allow-ips="*"
