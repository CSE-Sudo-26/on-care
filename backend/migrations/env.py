"""Alembic 환경 설정.

DB URL 과 메타데이터를 app 코드에서 가져와, 마이그레이션과 앱이
같은 스키마 정의를 공유하게 합니다. (URL 은 .env 의 DATABASE_URL)
"""
from __future__ import annotations

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.core.config import get_settings
from app.db.session import Base

# app 모델을 import 해야 Base.metadata 에 테이블이 등록된다.
from app.models import models  # noqa: F401

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# 실행 시점의 실제 DB URL 주입 (하드코딩 방지).
# sqlalchemy_database_url: 관리형 Postgres(Railway/Neon/Supabase)가 주는
# postgres:// · bare postgresql:// 를 psycopg v3 드라이버로 정규화한 값. Alembic 도
# 앱과 동일한 URL 로 엔진을 만들어야 bare URL 에서 psycopg2 dialect 오류로 마이그레이션이
# 실패하지 않는다(앱 기동 전 단계).
config.set_main_option("sqlalchemy.url", get_settings().sqlalchemy_database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """오프라인(--sql) 모드: DB 연결 없이 SQL 생성."""
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """온라인 모드: 실제 DB 에 연결해 마이그레이션."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
