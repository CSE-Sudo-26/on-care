"""채팅 발신·스케줄 생성의 재시도 중복 방지

Revision ID: 0031_create_action_ids
Revises: 0030_doc_source_ref
Create Date: 2026-08-11
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0031_create_action_ids"
down_revision: str | Sequence[str] | None = "0030_doc_source_ref"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # nullable 이므로 기존 행은 그대로 유지되고 구버전 클라이언트도
    # 유니크 제약 밖이다.
    op.add_column(
        "chat_messages",
        sa.Column("client_request_id", sa.String(length=64), nullable=True),
    )
    op.create_unique_constraint(
        "uq_chat_messages_client_request",
        "chat_messages",
        ["trainer_id", "member_id", "sender", "client_request_id"],
    )
    op.add_column(
        "trainer_schedule",
        sa.Column("client_request_id", sa.String(length=64), nullable=True),
    )
    op.create_unique_constraint(
        "uq_trainer_schedule_client_request",
        "trainer_schedule",
        ["trainer_id", "client_request_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_trainer_schedule_client_request",
        "trainer_schedule",
        type_="unique",
    )
    op.drop_column("trainer_schedule", "client_request_id")
    op.drop_constraint(
        "uq_chat_messages_client_request",
        "chat_messages",
        type_="unique",
    )
    op.drop_column("chat_messages", "client_request_id")
