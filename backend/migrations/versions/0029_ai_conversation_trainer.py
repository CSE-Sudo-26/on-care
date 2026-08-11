"""트레이너의 고객 코칭 질의를 회원 대화와 분리

트레이너가 `/trainer/clients/{id}/ai-coach` 로 담당 회원에 대해 AI 에게 묻는다.
검색 스코프는 회원(`user_id=member`)이지만, 그 문답은 **회원의 대화가 아니다**.
같은 스레드에 넣으면 회원이 앱을 열었을 때 자기가 하지 않은 대화를 보게 된다.

`trainer_id` 로 스레드를 가른다:
  * NULL       — 회원 본인의 대화(회원 앱 `/ai-coach/*` 가 읽는 것)
  * 값 있음    — 그 트레이너가 이 회원에 대해 물어본 대화

기존 행은 전부 회원 본인 대화이므로 NULL 이 맞다. 백필이 필요 없다.

Revision ID: 0029_aiconv_trainer
Revises: 0028_routine_client_req
Create Date: 2026-08-11
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0029_aiconv_trainer"
down_revision: str | Sequence[str] | None = "0028_routine_client_req"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "ai_conversations",
        sa.Column("trainer_id", sa.String(length=64), nullable=True),
    )
    op.create_foreign_key(
        "fk_ai_conversations_trainer_id_users",
        "ai_conversations",
        "users",
        ["trainer_id"],
        ["id"],
        ondelete="CASCADE",
    )
    # 예전 get-or-create 는 동시 요청에서 같은 회원의 활성 스레드를 둘 이상 만들 수
    # 있었다. 현재 조회가 선택하던 최신 한 건만 활성으로 남겨 유니크 인덱스 생성이
    # 기존 데이터 때문에 실패하지 않게 한다. 이 시점의 기존 행은 전부 trainer_id=NULL.
    op.execute(
        sa.text(
            """
            WITH ranked AS (
                SELECT
                    id,
                    row_number() OVER (
                        PARTITION BY user_id
                        ORDER BY created_at DESC, id DESC
                    ) AS position
                FROM ai_conversations
                WHERE archived_at IS NULL AND trainer_id IS NULL
            )
            UPDATE ai_conversations AS conversation
            SET archived_at = CURRENT_TIMESTAMP
            FROM ranked
            WHERE conversation.id = ranked.id AND ranked.position > 1
            """
        )
    )

    # PostgreSQL 의 UNIQUE 는 NULL 끼리를 같은 값으로 보지 않는다. 따라서 회원 본인
    # 스레드(trainer_id IS NULL)와 트레이너별 스레드를 별도 부분 인덱스로 보호한다.
    op.create_index(
        "uq_ai_conversations_active_member",
        "ai_conversations",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("archived_at IS NULL AND trainer_id IS NULL"),
    )
    op.create_index(
        "uq_ai_conversations_active_trainer",
        "ai_conversations",
        ["user_id", "trainer_id"],
        unique=True,
        postgresql_where=sa.text("archived_at IS NULL AND trainer_id IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_ai_conversations_active_trainer", table_name="ai_conversations"
    )
    op.drop_index(
        "uq_ai_conversations_active_member", table_name="ai_conversations"
    )
    op.drop_constraint(
        "fk_ai_conversations_trainer_id_users",
        "ai_conversations",
        type_="foreignkey",
    )
    op.drop_column("ai_conversations", "trainer_id")
