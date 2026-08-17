"""Give an assigned routine a review status so AI suggestions wait for the trainer.

AI 가 만든 개인운동 후보가 곧바로 회원에게 배정되면, 트레이너가 알고 있는
부상·회복 상태가 반영되지 않은 운동이 회원 화면에 뜬다. 배정 행에 검토 상태를
두어 승인 전에는 회원 조회에서 빠지게 한다.

기존 행은 모두 `approved` 로 채운다 — 지금까지 배정된 루틴은 이미 트레이너가
보낸 것이므로, 이 마이그레이션 뒤에도 회원 화면이 달라지지 않는다.

Revision ID: 0042_routine_review_status
Revises: 0041_schedule_program_sent
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0042_routine_review_status"
down_revision: str | Sequence[str] | None = "0041_schedule_program_sent"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # server_default 를 둬야 이미 있는 행이 NOT NULL 을 만족한다. 기본값을
    # `approved` 로 잡는 것이 하위 호환의 핵심이다 — 예전 배정은 전부 승인된
    # 것으로 읽혀야 회원 화면이 그대로다.
    op.add_column(
        "trainer_routines",
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="approved",
        ),
    )
    op.add_column(
        "trainer_routines",
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "trainer_routines",
        sa.Column("reviewed_by", sa.String(length=64), nullable=True),
    )
    # 회원 조회는 status 로 거른다. 트레이너·회원 조합에 이미 인덱스가 있으므로
    # 상태만 따로 걸어 두면 검토 대기 목록 조회가 전체 스캔으로 떨어지지 않는다.
    op.create_index(
        "ix_trainer_routines_status",
        "trainer_routines",
        ["status"],
    )


def downgrade() -> None:
    op.drop_index("ix_trainer_routines_status", table_name="trainer_routines")
    op.drop_column("trainer_routines", "reviewed_by")
    op.drop_column("trainer_routines", "reviewed_at")
    op.drop_column("trainer_routines", "status")
