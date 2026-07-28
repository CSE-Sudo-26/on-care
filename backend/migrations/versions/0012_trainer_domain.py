"""trainer domain (role + 트레이너↔회원 공유 테이블)

트레이너 앱 백엔드의 뼈대. users.role(member|trainer)로 두 앱 계정을 구분하고,
트레이너↔회원 상호작용(프로필·담당링크·루틴배정·완료기록·채팅·스케줄)을 담는
6개 테이블을 추가한다. 고객의 식단/운동/바이탈은 별도 복제 없이 회원의 실제
레코드를 읽으므로 여기서 만들지 않는다(진짜 데이터 공유).

기존 행 보존 추가형(additive) 마이그레이션. role 은 server_default='member' 로
기존 회원 계정을 자동 채운다.

Revision ID: 0012_trainer_domain
Revises: 0011_health_daily_sugar_g
Create Date: 2026-07-25

머지 순서상 트레이너 스택이 가장 마지막에 들어오므로, 병렬로 갈라졌던 0010
(원래 down_revision=0009)을 재선형화해 0010_diet_entry_macros(#207) →
0011_health_daily_sugar_g(#230/#231) 뒤에 잇는다. 반드시 그 둘이 main에 반영된
뒤 머지한다(단일 alembic head 유지).
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0012_trainer_domain"
down_revision: str | Sequence[str] | None = "0011_health_daily_sugar_g"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # --- users.role ---
    op.add_column(
        "users",
        sa.Column("role", sa.String(20), nullable=False, server_default="member"),
    )
    op.create_index("ix_users_role", "users", ["role"])

    # --- trainer_profiles ---
    op.create_table(
        "trainer_profiles",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "trainer_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column("phone", sa.String(20), nullable=False, server_default=""),
        sa.Column("specialty", sa.String(50), nullable=False, server_default=""),
        sa.Column("career_years", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("intro", sa.Text(), nullable=False, server_default=""),
        sa.Column("certifications_json", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("gym_name", sa.String(100), nullable=False, server_default=""),
        sa.Column("gym_address", sa.String(300), nullable=False, server_default=""),
        sa.Column("gym_hours", sa.String(50), nullable=False, server_default=""),
        sa.Column("gym_phone", sa.String(20), nullable=False, server_default=""),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("trainer_id", name="uq_trainer_profiles_trainer"),
    )
    op.create_index("ix_trainer_profiles_trainer_id", "trainer_profiles", ["trainer_id"])

    # --- trainer_clients (담당 링크) ---
    op.create_table(
        "trainer_clients",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "trainer_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column(
            "member_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column("goal", sa.String(200), nullable=False, server_default=""),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("trainer_id", "member_id", name="uq_trainer_client"),
    )
    op.create_index("ix_trainer_clients_trainer_id", "trainer_clients", ["trainer_id"])
    op.create_index("ix_trainer_clients_member_id", "trainer_clients", ["member_id"])

    # --- trainer_routines (배정 루틴) ---
    op.create_table(
        "trainer_routines",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "trainer_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column(
            "member_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("minutes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("reason", sa.String(200), nullable=False, server_default=""),
        sa.Column("source", sa.String(20), nullable=False, server_default="ai"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_trainer_routines_trainer_id", "trainer_routines", ["trainer_id"])
    op.create_index("ix_trainer_routines_member_id", "trainer_routines", ["member_id"])

    # --- routine_history (완료 기록) ---
    op.create_table(
        "routine_history",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "member_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column(
            "trainer_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True,
        ),
        sa.Column("date", sa.String(10), nullable=False),
        sa.Column("kind_label", sa.String(50), nullable=False, server_default=""),
        sa.Column("completion_rate", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("exercises_json", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("client_feedback", sa.Text(), nullable=False, server_default=""),
        sa.Column("trainer_note", sa.Text(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_routine_history_member_id", "routine_history", ["member_id"])
    op.create_index("ix_routine_history_trainer_id", "routine_history", ["trainer_id"])
    op.create_index("ix_routine_history_date", "routine_history", ["date"])

    # --- chat_messages ---
    op.create_table(
        "chat_messages",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "trainer_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column(
            "member_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column("sender", sa.String(20), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_chat_messages_trainer_id", "chat_messages", ["trainer_id"])
    op.create_index("ix_chat_messages_member_id", "chat_messages", ["member_id"])
    op.create_index("ix_chat_messages_created_at", "chat_messages", ["created_at"])

    # --- trainer_schedule ---
    op.create_table(
        "trainer_schedule",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "trainer_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
        ),
        sa.Column(
            "member_id", sa.String(64),
            sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True,
        ),
        sa.Column("date", sa.String(10), nullable=False),
        sa.Column("time", sa.String(10), nullable=False, server_default=""),
        sa.Column("client_name", sa.String(100), nullable=False, server_default=""),
        sa.Column("type", sa.String(30), nullable=False, server_default=""),
        sa.Column("duration_minutes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(10), nullable=False, server_default="예정"),
        sa.Column("note", sa.Text(), nullable=False, server_default=""),
        sa.Column("program_json", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_trainer_schedule_trainer_id", "trainer_schedule", ["trainer_id"])
    op.create_index("ix_trainer_schedule_member_id", "trainer_schedule", ["member_id"])
    op.create_index("ix_trainer_schedule_date", "trainer_schedule", ["date"])


def downgrade() -> None:
    op.drop_table("trainer_schedule")
    op.drop_table("chat_messages")
    op.drop_table("routine_history")
    op.drop_table("trainer_routines")
    op.drop_table("trainer_clients")
    op.drop_table("trainer_profiles")
    op.drop_index("ix_users_role", table_name="users")
    op.drop_column("users", "role")
