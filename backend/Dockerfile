FROM python:3.12-slim
WORKDIR /code

# psycopg(libpq) 빌드 의존성. 슬림 이미지 기준.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && rm -rf /var/lib/apt/lists/*

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
