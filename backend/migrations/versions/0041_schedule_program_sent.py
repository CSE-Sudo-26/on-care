"""Record when a completed session's program was delivered to the member.

트레이너가 수업을 마친 뒤 그날 한 프로그램을 회원에게 보내는 자리가 화면에는
있었지만 저장할 곳이 없어 눌리지 않았다(#822). 보낸 시각을 세션 행에 남겨,
같은 세션을 두 번 보내지 않고 화면이 '전송됨' 을 사실대로 말할 수 있게 한다.

Revision ID: 0041_schedule_program_sent
Revises: 0039_program_sessions
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0041_schedule_program_sent"
down_revision: str | Sequence[str] | None = "0039_program_sessions"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 기존 행은 모두 '보낸 적 없음'(NULL)이다 — 보낸 적이 있었다면 그 사실이
    # 어딘가에 남아 있었을 텐데, 지금까지 보낼 방법 자체가 없었다.
    op.add_column(
        "trainer_schedule",
        sa.Column("program_sent_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("trainer_schedule", "program_sent_at")
