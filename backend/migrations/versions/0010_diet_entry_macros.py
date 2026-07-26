"""Add macronutrients to diet_entries.

Revision ID: 0010_diet_entry_macros
Revises: 0009_diet_idempotency_key
Create Date: 2026-07-17
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0010_diet_entry_macros"
down_revision: str | Sequence[str] | None = "0009_diet_idempotency_key"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # The server default safely backfills existing rows during each ADD COLUMN.
    for name in ("carbs_g", "protein_g", "fat_g"):
        op.add_column(
            "diet_entries",
            sa.Column(name, sa.Float(), nullable=False, server_default="0"),
        )


def downgrade() -> None:
    for name in ("fat_g", "protein_g", "carbs_g"):
        op.drop_column("diet_entries", name)
