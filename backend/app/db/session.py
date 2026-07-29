"""데이터베이스 엔진과 세션 (SQLAlchemy 2.0 동기)."""
from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings

settings = get_settings()

# sqlalchemy_database_url: 관리형 Postgres(Railway/Neon/Supabase)가 주는
# postgres:// · bare postgresql:// 를 psycopg v3 드라이버로 정규화한 URL.
engine = create_engine(settings.sqlalchemy_database_url, pool_pre_ping=True, echo=False)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
