"""Separate the trainer's 활성/휴면 management state from the assignment link.

`trainer_clients.active` means "the assignment itself is alive" — dropping it
takes the member's coach away in the member app. The trainer console's
활성/휴면 badge is a different question ("am I actively coaching them right
now?"), so it gets its own column and leaves the link untouched.

Revision ID: 0036_client_dormant
Revises: 0035_drop_consultation_gym
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0036_client_dormant"
down_revision: str | Sequence[str] | None = "0035_drop_consultation_gym"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 기존 링크는 전부 관리 중(휴면 아님)으로 시작한다 — 지금까지 화면이
    # 보여 주던 값이 `active` 였고, 담당이 살아 있는 링크는 모두 활성으로
    # 표시됐기 때문이다.
    op.add_column(
        "trainer_clients",
        sa.Column(
            "dormant", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
    )


def downgrade() -> None:
    op.drop_column("trainer_clients", "dormant")
