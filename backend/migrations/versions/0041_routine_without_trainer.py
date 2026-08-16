"""Let an assigned routine exist without a trainer, for members who have none.

담당 트레이너가 없는 회원에게도 안전 범위의 개인운동을 내려주려면 배정 행이
트레이너 없이 설 수 있어야 한다(#782). 지금까지는 `trainer_id` 가 NOT NULL 이라
그런 회원에게는 루틴을 만들 수 없었고, 회원 조회는 늘 빈 목록이었다.

기존 행은 그대로다 — 값이 있던 행이 NULL 이 되지 않는다.

Revision ID: 0041_routine_without_trainer
Revises: 0040_routine_review_status
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0041_routine_without_trainer"
down_revision: str | Sequence[str] | None = "0040_routine_review_status"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "trainer_routines",
        "trainer_id",
        existing_type=sa.String(length=64),
        nullable=True,
    )


def downgrade() -> None:
    # 트레이너 없이 만들어진 행은 되돌릴 자리가 없다. NOT NULL 로 되돌리기 전에
    # 지운다 — 남겨 두면 alter 자체가 실패한다.
    op.execute("DELETE FROM trainer_routines WHERE trainer_id IS NULL")
    op.alter_column(
        "trainer_routines",
        "trainer_id",
        existing_type=sa.String(length=64),
        nullable=False,
    )
