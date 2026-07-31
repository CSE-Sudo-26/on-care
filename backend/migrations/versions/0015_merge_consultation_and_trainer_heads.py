"""Merge consultation request and trainer index migration heads.

Revision ID: 0015_merge_alembic_heads
Revises: 0014_consultation_requests, 0014_drop_trainer_prof_ix
Create Date: 2026-07-30
"""
from __future__ import annotations

from collections.abc import Sequence

revision: str = "0015_merge_alembic_heads"
down_revision: str | Sequence[str] | None = (
    "0014_consultation_requests",
    "0014_drop_trainer_prof_ix",
)
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Merge both migration branches without changing the database schema."""
    pass


def downgrade() -> None:
    """Restore the two parent heads without changing the database schema."""
    pass
