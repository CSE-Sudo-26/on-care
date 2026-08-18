"""Add optional weekly-report PDF metadata to chat messages.

Revision ID: 0045_chat_pdf_attachments
Revises: 0044_routine_suggestion_evidence
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0045_chat_pdf_attachments"
down_revision: str | Sequence[str] | None = "0044_routine_suggestion_evidence"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("chat_messages", sa.Column("attachment_type", sa.String(20), nullable=True))
    op.add_column("chat_messages", sa.Column("attachment_file_name", sa.String(255), nullable=True))
    op.add_column("chat_messages", sa.Column("attachment_file_id", sa.String(64), nullable=True))
    op.add_column("chat_messages", sa.Column("attachment_file_size", sa.Integer(), nullable=True))
    op.create_index("ix_chat_messages_attachment_file_id", "chat_messages", ["attachment_file_id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_chat_messages_attachment_file_id", table_name="chat_messages")
    op.drop_column("chat_messages", "attachment_file_size")
    op.drop_column("chat_messages", "attachment_file_id")
    op.drop_column("chat_messages", "attachment_file_name")
    op.drop_column("chat_messages", "attachment_type")
