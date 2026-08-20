"""Give logout something to revoke.

로그아웃이 두 앱 모두에서 **로컬 저장소를 지우는 것**뿐이었다. JWT 는 발급 뒤
만료까지 유효하므로, 공용 PC 에서 브라우저 저장소가 복사되거나 토큰이 새면
사용자가 로그아웃을 눌러도 그 refresh 토큰으로 최대 30일 동안 세션을 계속
되살릴 수 있었다. 트레이너 계정은 담당 회원의 식단·운동·건강 정보를 전부 읽는
계정이라 영향 범위가 좁지 않다(#966).

토큰 전체가 아니라 `jti`(토큰 한 장의 이름)만 담는다 — 표가 새어도 그것으로
인증할 수는 없다. 만료된 항목은 JWT 검증에서 이미 걸리므로 남겨 둘 이유가 없어
새 폐기가 생길 때마다 지운다.

Revision ID: 0052_refresh_token_revocation
Revises: 0051_trainer_program_template
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0052_refresh_token_revocation"
down_revision: str | Sequence[str] | None = "0051_trainer_program_template"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "revoked_refresh_tokens",
        sa.Column("jti", sa.String(64), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(64),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "revoked_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_revoked_refresh_tokens_user_id", "revoked_refresh_tokens", ["user_id"]
    )
    # 정리(purge)는 만료 시각으로 훑는다.
    op.create_index(
        "ix_revoked_refresh_tokens_expires_at", "revoked_refresh_tokens", ["expires_at"]
    )


def downgrade() -> None:
    op.drop_index(
        "ix_revoked_refresh_tokens_expires_at", table_name="revoked_refresh_tokens"
    )
    op.drop_index(
        "ix_revoked_refresh_tokens_user_id", table_name="revoked_refresh_tokens"
    )
    op.drop_table("revoked_refresh_tokens")
