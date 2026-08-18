"""Link the sessions created by one recurring-booking setup.

주 2회 PT 를 하는 고객이 15명이면 트레이너는 매주 같은 일정을 30번 다시
입력한다(#870). 반복을 표현하지 못하면 그 입력이 매주 되풀이되고, 그 과정에서
주차 누락·시간 오입력이 생긴다 — 일정은 회원 앱에도 나가는 데이터라 그대로
운영 혼선이 된다.

규칙(요일·종료 기준)을 저장하는 표는 두지 않는다. 만들고 나면 각 회차는 독립된
약속이라 개별로 옮기고 지우는 것이 실제 운영이고, 규칙을 남겨 두면 규칙과 실제
회차가 조용히 어긋난다. 필요한 것은 "이 회차들이 한 번에 잡힌 것" 이라는 사실
뿐이라, 회차 행에 `series_id` 하나를 둔다.

기존 행은 전부 단일 일정이므로 NULL 로 시작한다.

Revision ID: 0049_schedule_series
Revises: 0048_schedule_cancel_no_show
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0049_schedule_series"
down_revision: str | Sequence[str] | None = "0048_schedule_cancel_no_show"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "trainer_schedule",
        sa.Column("series_id", sa.String(64), nullable=True),
    )
    # 같은 시리즈의 회차를 모아 읽는 질의(멱등 재요청·시리즈 조회)가 이 인덱스를 탄다.
    op.create_index(
        "ix_trainer_schedule_series_id", "trainer_schedule", ["series_id"]
    )


def downgrade() -> None:
    # 회차 행은 남긴다 — 반복으로 만들었다는 사실만 사라질 뿐, 각 회차는 그대로
    # 유효한 약속이다. 지우면 트레이너의 앞으로 일정이 통째로 없어진다.
    op.drop_index("ix_trainer_schedule_series_id", table_name="trainer_schedule")
    op.drop_column("trainer_schedule", "series_id")
