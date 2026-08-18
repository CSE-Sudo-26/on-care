"""Keep a cancelled PT as a record instead of erasing it with the schedule row.

일정에서 `삭제` 하나로 두 가지 다른 일을 처리하고 있었다(#871) — 잘못 만든
데이터를 없애는 일과, 실제로 있었던 약속이 진행되지 않았다는 사실. 뒤엣것까지
삭제로 처리하면 "왜 그 PT 가 진행되지 않았나" 가 사라진다. 나중에 회원의 낮은
완료율을 볼 때 본인의 미이행 때문인지 트레이너 사정의 취소 때문인지 구분할 수
없다.

그래서 `trainer_schedule.status` 에 `취소`·`노쇼` 를 더하고, 그때의 시각·주체·
사유를 함께 남긴다. 상태값은 DB 계약값이라 기존 표기(한국어)를 그대로 따른다 —
표기 체계를 갈아 끼우면 기존 행이 어느 질의에도 걸리지 않는다.

새 컬럼은 전부 NULL 또는 빈 문자열로 시작한다. 기존 행은 예정·완료·공백뿐이라
백필할 값이 없다.

Revision ID: 0048_schedule_cancel_no_show
Revises: 0047_trainer_follow_up_task
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0048_schedule_cancel_no_show"
down_revision: str | Sequence[str] | None = "0047_trainer_follow_up_task"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "trainer_schedule",
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "trainer_schedule",
        sa.Column(
            "cancellation_source",
            sa.String(16),
            nullable=False,
            server_default="",
        ),
    )
    op.add_column(
        "trainer_schedule",
        sa.Column(
            "cancellation_reason",
            sa.String(200),
            nullable=False,
            server_default="",
        ),
    )
    op.add_column(
        "trainer_schedule",
        sa.Column("no_show_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_check_constraint(
        "ck_trainer_schedule_cancellation_source",
        "trainer_schedule",
        "cancellation_source IN ('', 'member', 'trainer', 'other')",
    )


def downgrade() -> None:
    # 취소·노쇼 상태로 남은 행은 되돌릴 자리가 없다 — 컬럼을 지우기 전에 상태만
    # 되돌리면 "진행되지 않은 약속" 이 예정으로 되살아나 오늘 목록에 다시 선다.
    # 그래서 그 행들은 예정이 아니라 완료 이전 상태가 아닌 **삭제**로 정리한다:
    # 다운그레이드는 이 기능이 없던 시점으로 가는 것이고, 그 시점의 표현은
    # "일정이 없음" 이었다.
    op.execute("DELETE FROM trainer_schedule WHERE status IN ('취소', '노쇼')")
    op.drop_constraint(
        "ck_trainer_schedule_cancellation_source",
        "trainer_schedule",
        type_="check",
    )
    op.drop_column("trainer_schedule", "no_show_at")
    op.drop_column("trainer_schedule", "cancellation_reason")
    op.drop_column("trainer_schedule", "cancellation_source")
    op.drop_column("trainer_schedule", "cancelled_at")
