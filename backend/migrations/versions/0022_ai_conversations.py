"""AI 코치 대화 영속화

`/ai-coach/chat` 이 무상태라 대화가 서버에 남지 않았다. 히스토리를 클라가 매번
실어 보내는 구조여서 앱을 다시 켜거나 다른 기기로 옮기면 대화가 사라졌다. (#274)

대화 스레드(ai_conversations)와 메시지(ai_messages)를 나눠 저장한다. 답변의 근거
문서 제목은 메시지에 함께 남긴다 — 복원했을 때 근거 표시가 사라지면 "왜 그렇게
답했는지"를 되짚을 수 없기 때문이다.

트레이너↔회원 채팅(chat_messages)과는 별개 도메인이라 테이블을 공유하지 않는다.

Revision ID: 0022_ai_conversations
Revises: 0021_member_gym_link
Create Date: 2026-08-08
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0022_ai_conversations"
down_revision: str | Sequence[str] | None = "0021_member_gym_link"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "ai_conversations",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.String(length=64), nullable=False),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_ai_conversations_user_id", "ai_conversations", ["user_id"]
    )

    op.create_table(
        "ai_messages",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("conversation_id", sa.String(length=64), nullable=False),
        # 대화 내 순번. created_at 으로 정렬할 수 없어서 둔다 — now() 는 트랜잭션
        # 시각이라 같은 커밋의 질문·답변이 동일한 값을 갖는다.
        sa.Column("seq", sa.Integer(), server_default="0", nullable=False),
        sa.Column("role", sa.String(length=10), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "sources_json", sa.Text(), server_default="[]", nullable=False
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["conversation_id"], ["ai_conversations.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "conversation_id", "seq", name="uq_ai_messages_convo_seq"
        ),
    )
    op.create_index(
        "ix_ai_messages_conversation_id", "ai_messages", ["conversation_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_ai_messages_conversation_id", table_name="ai_messages")
    op.drop_table("ai_messages")
    op.drop_index("ix_ai_conversations_user_id", table_name="ai_conversations")
    op.drop_table("ai_conversations")
