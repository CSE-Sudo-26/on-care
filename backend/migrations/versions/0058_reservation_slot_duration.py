"""store reservation slot duration

Revision ID: 0058_reservation_slot_duration
Revises: 0057_exercise_session_sets
"""

from alembic import op
import sqlalchemy as sa

revision = "0058_reservation_slot_duration"
down_revision = "0057_exercise_session_sets"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "trainer_reservation_slots",
        sa.Column("duration_minutes", sa.Integer(), server_default="60", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("trainer_reservation_slots", "duration_minutes")
