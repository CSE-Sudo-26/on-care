"""diet_entries.idempotency_key (재시도 중복 저장 방지)

/diet/analyze 는 분석과 저장을 함께 수행하므로 응답 유실 뒤 클라 재시도 시
동일 식단이 중복 저장될 수 있다. 요청당 멱등키를 저장하고 (user_id, key)
유니크 제약으로 재시도 중복을 차단한다. NULL 허용 → 기존/무키 요청은 제약 밖.
기존 행 보존을 위한 추가형(additive) 마이그레이션.

Revision ID: 0009_diet_idempotency_key
Revises: 0008_exercise_intensity
Create Date: 2026-07-17
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0009_diet_idempotency_key"
down_revision: str | Sequence[str] | None = "0008_exercise_intensity"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "diet_entries",
        sa.Column("idempotency_key", sa.String(64), nullable=True),
    )
    op.create_unique_constraint(
        "uq_diet_entries_user_idem",
        "diet_entries",
        ["user_id", "idempotency_key"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_diet_entries_user_idem", "diet_entries", type_="unique")
    op.drop_column("diet_entries", "idempotency_key")
