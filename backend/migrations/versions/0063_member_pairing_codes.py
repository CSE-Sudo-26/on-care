"""회원-트레이너 연결용 6자리 일회용 동기화 코드. (#1634)

회원 앱 MY 탭이 `users.id`(`user-<12자리 hex>`)를 "내 회원 ID"로 보여 주고
트레이너가 그것을 완전 일치로 입력했다. 마주 앉아 불러 주기에는 옮겨 적을 수
있는 형태가 아니었다. 회원이 그 자리에서 발급하는 6자리 코드로 바꾼다.

회원당 한 행이라 `member_id` 가 기본키다. 코드는 유일 — 만료된 행이 남아 있는
동안에도 같은 코드가 두 번 발급되지 않는다.

`users.id` 는 건드리지 않는다. 화면이 더 이상 보여 주지 않으므로 형식을 바꿀
이유가 없다.

Revision ID: 0063_member_pairing_codes
Revises: 0062_chat_report_week
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0063_member_pairing_codes"
down_revision: str | Sequence[str] | None = "0062_chat_report_week"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "member_pairing_codes",
        sa.Column(
            "member_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("code", sa.String(6), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_member_pairing_codes_code",
        "member_pairing_codes",
        ["code"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_member_pairing_codes_code", table_name="member_pairing_codes"
    )
    op.drop_table("member_pairing_codes")
