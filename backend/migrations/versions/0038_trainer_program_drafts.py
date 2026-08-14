"""Let trainers save a program draft on the server instead of losing it on reload.

Revision ID: 0038_program_drafts
Revises: 0037_client_dormant
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0038_program_drafts"
down_revision: str | Sequence[str] | None = "0037_client_dormant"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trainer_program_drafts",
        sa.Column("id", sa.String(length=64), primary_key=True),
        # 초안은 만든 트레이너의 것이다 — 탈퇴하면 함께 사라진다. 회원과는
        # 묶이지 않는다(배정은 초안을 불러와서 하는 별개의 행동).
        sa.Column(
            "trainer_id",
            sa.String(length=64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(length=100), nullable=False, server_default=""),
        sa.Column("goal", sa.String(length=200), nullable=False, server_default=""),
        sa.Column("period", sa.String(length=100), nullable=False, server_default=""),
        sa.Column("memo", sa.Text(), nullable=False, server_default=""),
        sa.Column(
            "session_name", sa.String(length=100), nullable=False, server_default=""
        ),
        # 편집기의 운동 목록 그대로. 값이 전부 자유 문자열이라 숫자로 정규화하면
        # 트레이너가 적어 둔 표현이 사라진다.
        sa.Column(
            "exercises_json", sa.Text(), nullable=False, server_default="[]"
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index(
        "ix_trainer_program_drafts_trainer_id",
        "trainer_program_drafts",
        ["trainer_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_trainer_program_drafts_trainer_id", table_name="trainer_program_drafts"
    )
    op.drop_table("trainer_program_drafts")
