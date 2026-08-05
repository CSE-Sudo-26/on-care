"""데이터베이스 엔진과 세션 (SQLAlchemy 2.0 동기)."""
from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings

settings = get_settings()

# Use the psycopg-normalized URL for managed Postgres providers, and bound
# connection attempts so readiness probes cannot occupy a worker indefinitely.
engine = create_engine(
    settings.sqlalchemy_database_url,
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
