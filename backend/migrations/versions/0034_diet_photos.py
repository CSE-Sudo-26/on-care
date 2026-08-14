"""Store meal photos so the member app and the trainer console see the same picture.

Revision ID: 0034_diet_photos
Revises: 0033_routine_completion
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0034_diet_photos"
down_revision: str | Sequence[str] | None = "0033_routine_completion"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "diet_photos",
        sa.Column("id", sa.String(length=64), primary_key=True),
        # 끼니와 소유자 양쪽에서 CASCADE — 식단 기록을 지우거나 탈퇴하면 사진도
        # 함께 사라진다. 남기면 주인 없는 바이트가 DB 에 쌓인다.
        sa.Column(
            "entry_id",
            sa.String(length=64),
            sa.ForeignKey("diet_entries.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column(
            "user_id",
            sa.String(length=64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "content_type",
            sa.String(length=40),
            nullable=False,
            server_default="image/jpeg",
        ),
        sa.Column("width", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("height", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("byte_size", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("data", sa.LargeBinary(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    # entry_id 는 unique 제약이 이미 인덱스를 만든다 — user_id 만 따로 건다.
    op.create_index("ix_diet_photos_user_id", "diet_photos", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_diet_photos_user_id", table_name="diet_photos")
    op.drop_table("diet_photos")
