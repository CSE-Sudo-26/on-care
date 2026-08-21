"""회원이 데이터 공유에 동의한 시각을 남긴다.

트레이너는 담당이 되는 순간 회원의 식단·운동·신체 정보를 읽는다. 그런데 연결
과정 어디에도 "무엇이 넘어가는지 확인하고 동의한다" 는 자리가 없었고, 동의를
언제 받았는지도 답할 수 없었다(#1022).

동의를 받는 자리가 둘이라 컬럼도 둘이다:

* `trainer_clients.data_consent_at` — 트레이너의 담당 요청을 회원이 수락할 때.
  회원이 그 자리에서 동의하므로 링크에 바로 적는다.
* `consultation_requests.data_consent_at` — 회원이 상담을 신청할 때. 연결은
  나중에 트레이너가 수락하며 만들어지므로, 수락 시점에 이 값을 링크로 옮긴다.

기존 행은 비워 둔다. 이 기능 이전에 만들어진 담당이라는 뜻이고, 소급해서 동의를
받은 척할 수는 없다.

Revision ID: 0054_data_sharing_consent
Revises: 0053_exercise_type_four_buckets
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0054_data_sharing_consent"
down_revision: str | Sequence[str] | None = "0053_exercise_type_four_buckets"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "trainer_clients",
        sa.Column("data_consent_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "consultation_requests",
        sa.Column("data_consent_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("consultation_requests", "data_consent_at")
    op.drop_column("trainer_clients", "data_consent_at")
