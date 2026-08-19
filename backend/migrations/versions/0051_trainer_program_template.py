"""Give each trainer their own reusable exercise blocks.

AI 코칭 탭의 프로그램 템플릿은 앱 소스의 `const` 목록 셋이었다. 트레이너마다
다른 것이 템플릿의 존재 이유인데 모두가 같은 셋을 봤고, 한국어로 고정된 내용이
영어 화면에도 그대로 남았다(#920).

초안(`trainer_program_drafts`)과 나누는 까닭은 답하는 질문이 다르기 때문이다 —
초안은 "이 회원에게 짜 둔 프로그램", 템플릿은 "어느 회원에게든 끼워 넣는 블록"
이다. 그래서 세션 개념 없이 운동 목록 하나만 갖는다.

Revision ID: 0051_trainer_program_template
Revises: 0050_trainer_client_invite
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0051_trainer_program_template"
down_revision: str | Sequence[str] | None = "0050_trainer_client_invite"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trainer_program_templates",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "trainer_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(100), nullable=False, server_default=""),
        sa.Column("goal", sa.String(200), nullable=False, server_default=""),
        sa.Column("exercises_json", sa.Text(), nullable=False, server_default="[]"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_trainer_program_templates_trainer_id",
        "trainer_program_templates",
        ["trainer_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_trainer_program_templates_trainer_id",
        table_name="trainer_program_templates",
    )
    op.drop_table("trainer_program_templates")
