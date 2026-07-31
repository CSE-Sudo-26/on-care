"""바이탈(체중·혈압·혈당) 기능 제거: vitals 테이블 + health_profiles 목표/체중 컬럼 드롭

체중/혈압/혈당 바디 지표 기능과 건강 목표(목표 체중·혈압·혈당) 및 현재 체중
프로필 컬럼을 백엔드에서 완전히 제거한다. 식단 일일 영양 목표(daily_*)는 유지.

Revision ID: 0016_drop_vitals
Revises: 0015_merge_alembic_heads
Create Date: 2026-07-31
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0016_drop_vitals"
down_revision: str | Sequence[str] | None = "0015_merge_alembic_heads"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# health_profiles 에서 제거하는 컬럼 (이름, 타입) — downgrade 재생성용.
_DROPPED_COLUMNS: list[tuple[str, sa.types.TypeEngine]] = [
    ("weight_kg", sa.Float()),
    ("goal_weight_kg", sa.Float()),
    ("goal_bp_systolic", sa.Integer()),
    ("goal_blood_sugar", sa.Integer()),
]


def upgrade() -> None:
    for name, _ in _DROPPED_COLUMNS:
        op.drop_column("health_profiles", name)

    op.drop_index("ix_vitals_kind", table_name="vitals")
    op.drop_index("ix_vitals_user_id", table_name="vitals")
    op.drop_table("vitals")


def downgrade() -> None:
    op.create_table(
        "vitals",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("value_json", sa.Text(), nullable=False, server_default="{}"),
        sa.Column(
            "recorded_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index("ix_vitals_user_id", "vitals", ["user_id"])
    op.create_index("ix_vitals_kind", "vitals", ["kind"])

    for name, col_type in _DROPPED_COLUMNS:
        op.add_column("health_profiles", sa.Column(name, col_type, nullable=True))
