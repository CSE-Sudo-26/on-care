#!/usr/bin/env bash
# 운영 컨테이너 기동 엔트리포인트.
# 1) 스키마를 Alembic head 까지 마이그레이션(운영은 AUTO_CREATE_TABLES=false 권장 →
#    Alembic 이 유일한 스키마 소스). 2) uvicorn 시작.
# App Runner/프록시 뒤이므로 --proxy-headers 로 X-Forwarded-Proto 를 신뢰(HTTPS 판정).
set -euo pipefail

echo "[start] alembic upgrade head"
alembic upgrade head

echo "[start] launching uvicorn on :8000"
exec uvicorn app.main:app \
  --host 0.0.0.0 --port 8000 \
  --proxy-headers --forwarded-allow-ips="*"
