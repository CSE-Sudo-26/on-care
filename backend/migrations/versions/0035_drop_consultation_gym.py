"""Drop the retired gym target from consultation requests.

상담 요청은 트레이너 한 사람에게만 간다(#717). 헬스장 전체를 대상으로 하던 갈래는
폐지됐고 그때 만들어진 이력도 남아 있지 않아, 컬럼과 전용 인덱스를 걷어낸다(#726).

`target_type` 컬럼은 남긴다 — 값이 `trainer` 하나뿐이지만, 회원당 대기 요청을 하나로
막는 `uq_consultation_requests_pending_trainer` 의 조건이 이 값을 참조한다.

Revision ID: 0035_drop_consultation_gym
Revises: 0034_diet_photos
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0035_drop_consultation_gym"
down_revision: str | Sequence[str] | None = "0034_diet_photos"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 인덱스가 컬럼을 참조하므로 인덱스를 먼저 지운다. 컬럼을 지우면 딸린 외래키도
    # 함께 사라진다.
    op.drop_index(
        "uq_consultation_requests_pending_gym",
        table_name="consultation_requests",
        if_exists=True,
    )
    op.drop_index(
        "ix_consultation_requests_gym_status",
        table_name="consultation_requests",
        if_exists=True,
    )
    op.drop_column("consultation_requests", "gym_id")


def downgrade() -> None:
    # 구조만 되돌린다. 폐지된 갈래라 값은 복구할 것이 없다(내려받는 시점에도 0건).
    op.add_column(
        "consultation_requests",
        sa.Column(
            "gym_id",
            sa.String(length=64),
            sa.ForeignKey("places.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index(
        "uq_consultation_requests_pending_gym",
        "consultation_requests",
        ["member_id", "gym_id"],
        unique=True,
        postgresql_where=sa.text("target_type = 'gym' AND status = 'pending'"),
    )
    op.create_index(
        "ix_consultation_requests_gym_status",
        "consultation_requests",
        ["gym_id", "status"],
    )
