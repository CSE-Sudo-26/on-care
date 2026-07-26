"""health_profiles.daily_sugar_g (일일 당류 제한 목표)

프론트 MY 건강 목표의 '당류 제한'을 실서버에도 영속하기 위한 컬럼.
daily_calories/daily_sodium_mg 와 동일하게 nullable(미설정 허용) 추가형
마이그레이션이므로 기존 행은 그대로 보존된다.

Revision ID: 0011_health_daily_sugar_g
Revises: 0010_diet_entry_macros
Create Date: 2026-07-18
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0011_health_daily_sugar_g"
down_revision: str | Sequence[str] | None = "0010_diet_entry_macros"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "health_profiles",
        sa.Column("daily_sugar_g", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("health_profiles", "daily_sugar_g")
