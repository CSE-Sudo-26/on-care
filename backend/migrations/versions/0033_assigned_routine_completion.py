"""Link assigned routines to member exercise completion and feedback.

Revision ID: 0033_routine_completion
Revises: 0032_member_weight
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0033_routine_completion"
down_revision: str | Sequence[str] | None = "0032_member_weight"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "exercise_sessions",
        sa.Column("assigned_routine_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "exercise_sessions",
        sa.Column("assigned_trainer_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "exercise_sessions",
        sa.Column(
            "assigned_routine_name", sa.String(length=100),
            nullable=False, server_default="",
        ),
    )
    op.add_column(
        "exercise_sessions",
        sa.Column("member_note", sa.Text(), nullable=False, server_default=""),
    )
    op.add_column(
        "exercise_sessions",
        sa.Column("trainer_feedback", sa.Text(), nullable=False, server_default=""),
    )
    op.add_column(
        "exercise_sessions",
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_exercise_sessions_assigned_trainer",
        "exercise_sessions", "users", ["assigned_trainer_id"], ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_exercise_sessions_assigned_trainer_id",
        "exercise_sessions", ["assigned_trainer_id"], unique=False,
    )
    op.create_index(
        "ix_exercise_sessions_assigned_routine_id",
        "exercise_sessions", ["assigned_routine_id"], unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_exercise_sessions_assigned_routine_id", table_name="exercise_sessions"
    )
    op.drop_index(
        "ix_exercise_sessions_assigned_trainer_id", table_name="exercise_sessions"
    )
    op.drop_constraint(
        "fk_exercise_sessions_assigned_trainer",
        "exercise_sessions", type_="foreignkey",
    )
    for column in (
        "completed_at",
        "trainer_feedback",
        "member_note",
        "assigned_routine_name",
        "assigned_trainer_id",
        "assigned_routine_id",
    ):
        op.drop_column("exercise_sessions", column)
