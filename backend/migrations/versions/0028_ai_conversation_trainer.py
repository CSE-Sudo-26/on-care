"""트레이너의 고객 코칭 질의를 회원 대화와 분리

트레이너가 `/trainer/clients/{id}/ai-coach` 로 담당 회원에 대해 AI 에게 묻는다.
검색 스코프는 회원(`user_id=member`)이지만, 그 문답은 **회원의 대화가 아니다**.
같은 스레드에 넣으면 회원이 앱을 열었을 때 자기가 하지 않은 대화를 보게 된다.

`trainer_id` 로 스레드를 가른다:
  * NULL       — 회원 본인의 대화(회원 앱 `/ai-coach/*` 가 읽는 것)
  * 값 있음    — 그 트레이너가 이 회원에 대해 물어본 대화

기존 행은 전부 회원 본인 대화이므로 NULL 이 맞다. 백필이 필요 없다.

Revision ID: 0028_aiconv_trainer
Revises: 0027_exercise_source
Create Date: 2026-08-11
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0028_aiconv_trainer"
down_revision: str | Sequence[str] | None = "0027_exercise_source"
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
    # 스레드 조회는 항상 (user_id, trainer_id) 로 좁힌다.
    op.create_index(
        "ix_ai_conversations_user_trainer",
        "ai_conversations",
        ["user_id", "trainer_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_ai_conversations_user_trainer", table_name="ai_conversations")
    op.drop_constraint(
        "fk_ai_conversations_trainer_id_users",
        "ai_conversations",
        type_="foreignkey",
    )
    op.drop_column("ai_conversations", "trainer_id")
