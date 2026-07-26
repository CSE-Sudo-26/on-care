"""exercise_sessions.intensity (운동 강도)

운동 강도(light|moderate|high)를 저장해 수정 시트가 원래 강도로 복원되고
칼로리 추정이 강도 기준으로 일관되게 계산되도록 한다.
기존 행 보존을 위한 추가형(additive) 마이그레이션 — 기본값 moderate.

Revision ID: 0008_exercise_intensity
Revises: 0007_coach_embedding_768
Create Date: 2026-07-17
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0008_exercise_intensity"
down_revision: str | Sequence[str] | None = "0007_coach_embedding_768"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "exercise_sessions",
        sa.Column(
            "intensity",
            sa.String(20),
            nullable=False,
            server_default="moderate",
        ),
    )


def downgrade() -> None:
    op.drop_column("exercise_sessions", "intensity")
