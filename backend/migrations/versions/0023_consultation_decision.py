"""상담 요청 승인·거절 처리 기록

상담 요청은 `pending` 으로 저장된 뒤 상태가 바뀔 길이 없었다 — 트레이너가 요청을
조회할 엔드포인트도, 승인해서 담당 링크(trainer_clients)를 만들 경로도 없었기
때문이다. 그래서 실서비스에서 신규 회원이 트레이너를 가질 수 없었다. (#467)

여기서는 **처리 흔적을 남길 컬럼만** 더한다. 상태값 자체(`pending`/`accepted`/
`rejected`)는 기존 `status` 문자열을 그대로 쓴다 — CHECK 제약을 새로 걸면 기존
행과 시드까지 검증 대상이 되어 마이그레이션이 데이터에 의존하게 된다.

- `decided_by`  처리한 트레이너. 헬스장으로 온 요청은 소속 트레이너 중 누가
                받았는지가 남아야 하므로 `trainer_id`(요청 대상)와 별개 컬럼이다.
- `decided_at`  처리 시각. `updated_at` 은 어떤 수정으로도 갱신되므로 승인 시점의
                근거로 쓸 수 없다.
- `decision_note` 거절 사유. 승인 시에는 비어 있다.

셋 다 nullable 이고 백필하지 않는다. 기존 `pending` 행은 그대로 미처리 상태이며,
응답 스키마도 기존 필드를 바꾸지 않으므로 이미 배포된 앱 화면은 영향받지 않는다.

Revision ID: 0023_consultation_decision
Revises: 0022_ai_conversations
Create Date: 2026-08-08
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0023_consultation_decision"
down_revision: str | Sequence[str] | None = "0022_ai_conversations"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "consultation_requests",
        sa.Column("decided_by", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "consultation_requests",
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "consultation_requests",
        sa.Column("decision_note", sa.Text(), nullable=True),
    )
    # 트레이너 계정이 지워져도 요청 이력은 남아야 한다 — 처리자만 비운다.
    op.create_foreign_key(
        "fk_consultation_requests_decided_by",
        "consultation_requests",
        "users",
        ["decided_by"],
        ["id"],
        ondelete="SET NULL",
    )
    # 트레이너 인박스는 "내 앞으로 온 것"(trainer_id) 과 "내 헬스장으로 온 것"(gym_id)을
    # 각각 status 로 좁혀 읽는다. 두 경로 모두 인덱스 없이는 전건 스캔이 된다.
    op.create_index(
        "ix_consultation_requests_trainer_status",
        "consultation_requests",
        ["trainer_id", "status"],
    )
    op.create_index(
        "ix_consultation_requests_gym_status",
        "consultation_requests",
        ["gym_id", "status"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_consultation_requests_gym_status",
        table_name="consultation_requests",
    )
    op.drop_index(
        "ix_consultation_requests_trainer_status",
        table_name="consultation_requests",
    )
    op.drop_constraint(
        "fk_consultation_requests_decided_by",
        "consultation_requests",
        type_="foreignkey",
    )
    op.drop_column("consultation_requests", "decision_note")
    op.drop_column("consultation_requests", "decided_at")
    op.drop_column("consultation_requests", "decided_by")
