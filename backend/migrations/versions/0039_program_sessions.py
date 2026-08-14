"""Carry a program's sessions through saving, assigning and scheduling.

The editor has always let a trainer build several sessions in one program, but
storage stopped at one: drafts kept a single session, an assignment collapsed
into one flat routine, and the schedule kept a flat item list. This widens all
three, keeping existing single-session rows working.

Revision ID: 0039_program_sessions
Revises: 0038_program_drafts
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0039_program_sessions"
down_revision: str | Sequence[str] | None = "0038_program_drafts"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # ---- 초안: 세션 하나 → 세션 배열 ----
    op.add_column(
        "trainer_program_drafts",
        sa.Column(
            "sessions_json", sa.Text(), nullable=False, server_default="[]"
        ),
    )
    # 이미 저장된 초안을 세션 1개짜리 배열로 옮긴다. 이름이 비어 있어도 세션은
    # 그대로 하나이므로 배열에 담는다 — 여기서 흘리면 저장해 둔 구성이 사라진다.
    op.execute(
        """
        UPDATE trainer_program_drafts
        SET sessions_json = json_build_array(
            json_build_object(
                'id', 'session-1',
                'name', session_name,
                'exercises', COALESCE(exercises_json, '[]')::json
            )
        )::text
        """
    )
    op.drop_column("trainer_program_drafts", "session_name")
    op.drop_column("trainer_program_drafts", "exercises_json")

    # ---- 배정: 세션 이름·순서와 운동 구성 ----
    op.add_column(
        "trainer_routines",
        sa.Column(
            "program_name", sa.String(length=100), nullable=False,
            server_default="",
        ),
    )
    op.add_column(
        "trainer_routines",
        sa.Column(
            "session_name", sa.String(length=100), nullable=False,
            server_default="",
        ),
    )
    op.add_column(
        "trainer_routines",
        sa.Column(
            "session_order", sa.Integer(), nullable=False, server_default="0"
        ),
    )
    op.add_column(
        "trainer_routines",
        sa.Column(
            "exercises_json", sa.Text(), nullable=False, server_default="[]"
        ),
    )


def downgrade() -> None:
    op.drop_column("trainer_routines", "exercises_json")
    op.drop_column("trainer_routines", "session_order")
    op.drop_column("trainer_routines", "session_name")
    op.drop_column("trainer_routines", "program_name")

    op.add_column(
        "trainer_program_drafts",
        sa.Column(
            "session_name", sa.String(length=100), nullable=False,
            server_default="",
        ),
    )
    op.add_column(
        "trainer_program_drafts",
        sa.Column(
            "exercises_json", sa.Text(), nullable=False, server_default="[]"
        ),
    )
    # 첫 세션만 되돌린다 — 단일 세션 스키마에는 나머지를 담을 자리가 없다.
    op.execute(
        """
        UPDATE trainer_program_drafts
        SET session_name = COALESCE(
                (sessions_json::json -> 0 ->> 'name'), ''
            ),
            exercises_json = COALESCE(
                (sessions_json::json -> 0 -> 'exercises')::text, '[]'
            )
        """
    )
    op.drop_column("trainer_program_drafts", "sessions_json")
