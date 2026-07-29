"""데이터베이스 엔진과 세션 (SQLAlchemy 2.0 동기)."""
from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings

settings = get_settings()

# connect_timeout: 네트워크 파티션/DB 무응답 시 커넥션 인출이 스레드를 무한 점유하지 않게
# 상한을 둔다(특히 /readyz 폴링). libpq 파라미터라 psycopg 로 전달된다.
engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
    echo=False,
    connect_args={"connect_timeout": settings.db_connect_timeout_seconds},
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
