#!/usr/bin/env bash
# 운영 컨테이너 기동 엔트리포인트.
# 1) 스키마를 Alembic head 까지 마이그레이션(운영은 AUTO_CREATE_TABLES=false 권장 →
#    Alembic 이 유일한 스키마 소스). 2) uvicorn 시작.
# App Runner/프록시 뒤이므로 --proxy-headers 로 X-Forwarded-Proto 를 신뢰(HTTPS 판정).
set -euo pipefail

echo "[start] migrate (advisory-lock serialized)"
python scripts/migrate.py

# 포트: Railway 등 일부 플랫폼은 동적 $PORT 를 주입한다. 없으면(App Runner·로컬·
# docker-compose) 8000 으로 폴백 → 한 이미지가 두 플랫폼 모두에서 그대로 뜬다.
PORT="${PORT:-8000}"
echo "[start] launching uvicorn on :${PORT}"
exec uvicorn app.main:app \
  --host 0.0.0.0 --port "${PORT}" \
  --proxy-headers --forwarded-allow-ips="*"
