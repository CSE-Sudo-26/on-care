"""Give the trainer a place to leave "check this client again later".

트레이너 웹은 고객 상태를 확인하고 즉시 행동하는 경로는 갖췄지만, 며칠 뒤
다시 확인해야 하는 일을 남겨 둘 곳이 없었다(#869). 그래서 트레이너가 메모장이나
외부 도구에 적어 두고, 그 기록은 On-Care 밖에 남는다.

메모(`trainer_client_memos`)와 나누는 까닭은 답하는 질문이 다르기 때문이다 —
메모는 "무엇을 알아 두었나", 이 표는 "언제까지 무엇을 해야 하나"다. 예정일과
완료 상태를 갖고 대시보드가 오늘 처리할 목록으로 읽는다.

(trainer, client_request_id) 유니크 — 끊긴 네트워크로 재시도한 등록이 같은 할
일을 두 번 만들지 않게 한다(`uq_trainer_schedule_client_request` 와 같은 규약).

Revision ID: 0047_trainer_follow_up_task
Revises: 0046_report_feedback_draft
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0047_trainer_follow_up_task"
down_revision: str | Sequence[str] | None = "0046_report_feedback_draft"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trainer_follow_up_tasks",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "trainer_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "member_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("due_date", sa.String(10), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending"),
        sa.Column(
            "context_type", sa.String(16), nullable=False, server_default="general"
        ),
        sa.Column("client_request_id", sa.String(64), nullable=True),
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
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint(
            "trainer_id",
            "client_request_id",
            name="uq_trainer_follow_up_task_client_request",
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'completed')",
            name="ck_trainer_follow_up_task_status",
        ),
        sa.CheckConstraint(
            "context_type IN "
            "('general', 'diet', 'exercise', 'message', 'program', 'schedule')",
            name="ck_trainer_follow_up_task_context",
        ),
    )
    op.create_index(
        "ix_trainer_follow_up_tasks_member_id",
        "trainer_follow_up_tasks",
        ["member_id"],
    )
    # 대시보드 질의 그대로 — 내 미완료 할 일을 예정일 순으로.
    op.create_index(
        "ix_trainer_follow_up_tasks_queue",
        "trainer_follow_up_tasks",
        ["trainer_id", "status", "due_date"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_trainer_follow_up_tasks_queue", table_name="trainer_follow_up_tasks"
    )
    op.drop_index(
        "ix_trainer_follow_up_tasks_member_id", table_name="trainer_follow_up_tasks"
    )
    op.drop_table("trainer_follow_up_tasks")
