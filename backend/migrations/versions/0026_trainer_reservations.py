"""Persist trainer availability slots and member reservations.

Revision ID: 0026_trainer_reservations
Revises: 0025_member_noti_settings
Create Date: 2026-08-08
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0026_trainer_reservations"
down_revision: str | Sequence[str] | None = "0025_member_noti_settings"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trainer_reservation_slots",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("trainer_id", sa.String(length=64), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("capacity", sa.Integer(), nullable=False),
        sa.Column("remaining", sa.Integer(), nullable=False),
        sa.Column("is_closed", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "capacity > 0", name="ck_reservation_slot_capacity_positive"
        ),
        sa.CheckConstraint(
            "remaining >= 0 AND remaining <= capacity",
            name="ck_reservation_slot_remaining_range",
        ),
        sa.ForeignKeyConstraint(["trainer_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_trainer_reservation_slots_trainer_id",
        "trainer_reservation_slots",
        ["trainer_id"],
    )
    op.create_index(
        "ix_trainer_reservation_slots_starts_at",
        "trainer_reservation_slots",
        ["starts_at"],
    )
    op.create_index(
        "ix_reservation_slots_trainer_starts",
        "trainer_reservation_slots",
        ["trainer_id", "starts_at"],
    )

    op.create_table(
        "trainer_reservations",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("member_id", sa.String(length=64), nullable=False),
        sa.Column("slot_id", sa.String(length=64), nullable=False),
        sa.Column("schedule_id", sa.String(length=64), nullable=False),
        sa.Column(
            "status", sa.String(length=20), server_default="booked", nullable=False
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["member_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(
            ["slot_id"], ["trainer_reservation_slots.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(
            ["schedule_id"], ["trainer_schedule.id"], ondelete="RESTRICT"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("member_id", "slot_id", name="uq_reservation_member_slot"),
        sa.UniqueConstraint("schedule_id"),
    )
    op.create_index(
        "ix_trainer_reservations_member_id", "trainer_reservations", ["member_id"]
    )
    op.create_index(
        "ix_trainer_reservations_slot_id", "trainer_reservations", ["slot_id"]
    )
    op.create_index(
        "ix_reservations_slot_status",
        "trainer_reservations",
        ["slot_id", "status"],
    )


def downgrade() -> None:
    op.drop_index("ix_reservations_slot_status", table_name="trainer_reservations")
    op.drop_index("ix_trainer_reservations_slot_id", table_name="trainer_reservations")
    op.drop_index(
        "ix_trainer_reservations_member_id", table_name="trainer_reservations"
    )
    op.drop_table("trainer_reservations")
    op.drop_index(
        "ix_reservation_slots_trainer_starts",
        table_name="trainer_reservation_slots",
    )
    op.drop_index(
        "ix_trainer_reservation_slots_starts_at",
        table_name="trainer_reservation_slots",
    )
    op.drop_index(
        "ix_trainer_reservation_slots_trainer_id",
        table_name="trainer_reservation_slots",
    )
    op.drop_table("trainer_reservation_slots")
