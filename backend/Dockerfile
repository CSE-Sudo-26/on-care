FROM python:3.12-slim
WORKDIR /code

# psycopg[binary] 휠이 libpq 를 번들하므로 apt 빌드 툴체인(build-essential/libpq-dev)이
# 불필요하다 — 이미지에서 수백 MB 를 덜어낸다. (소스 빌드로 바꾸면 psycopg[c] + libpq-dev 필요)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 앱 + 마이그레이션 자산(운영은 Alembic 이 스키마의 정답이므로 반드시 포함).
COPY app ./app
COPY migrations ./migrations
COPY alembic.ini ./alembic.ini
COPY scripts ./scripts
RUN chmod +x scripts/start.sh

# 비루트 유저로 실행 (컨테이너 탈출 시 피해 범위 축소)
RUN useradd --create-home --uid 10001 appuser && chown -R appuser:appuser /code
USER appuser

EXPOSE 8000
# 기동: alembic upgrade head 후 uvicorn(프록시 뒤이므로 --proxy-headers).
CMD ["scripts/start.sh"]
