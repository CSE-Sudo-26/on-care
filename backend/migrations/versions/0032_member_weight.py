"""Restore member body weight for shared coaching profiles.

Revision ID: 0032_member_weight
Revises: 0031_create_action_ids
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0032_member_weight"
down_revision: str | Sequence[str] | None = "0031_create_action_ids"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "health_profiles",
        sa.Column("weight_kg", sa.Float(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("health_profiles", "weight_kg")
