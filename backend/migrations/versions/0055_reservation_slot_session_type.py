"""예약 슬롯에 종류(1:1 PT/상담)를 더한다.

슬롯은 늘 한 사람 몫이라 정원을 고를 이유가 없다(#1012). 그런데도 회원 예약이
만드는 일정은 `type="1:1 PT"` 로 고정돼 있어, 회원 앱을 통해서는 상담 자리를
열 방법이 없었다(#1083).

기존 행은 전부 `1:1 PT` 로 채운다 — 이 컬럼이 생기기 전에 열린 슬롯은 실제로
전부 1:1 PT 였다(예약 확정 로직이 그렇게 하드코딩돼 있었다).

Revision ID: 0055_reservation_slot_session_type
Revises: 0054_data_sharing_consent
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0055_reservation_slot_session_type"
down_revision: str | Sequence[str] | None = "0054_data_sharing_consent"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "trainer_reservation_slots",
        sa.Column(
            "session_type",
            sa.String(length=16),
            nullable=False,
            server_default="1:1 PT",
        ),
    )
    op.create_check_constraint(
        "ck_reservation_slot_session_type",
        "trainer_reservation_slots",
        "session_type IN ('1:1 PT', '상담')",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_reservation_slot_session_type",
        "trainer_reservation_slots",
        type_="check",
    )
    op.drop_column("trainer_reservation_slots", "session_type")
