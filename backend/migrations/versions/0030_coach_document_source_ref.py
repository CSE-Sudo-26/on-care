"""개인 문서가 원본 기록을 가리키게 한다

개인 RAG 적재는 생성 시에만 일어나, 기록을 수정해도 옛 수치 문서가 그대로 남았다
(#603). 그렇다고 수정할 때마다 다시 적재하면 더 나쁘다 — 옛 문서가 남은 채 새
문서가 추가돼 코치가 "30분" 과 "45분" 을 **동시에** 근거로 삼는다.

교체하려면 지울 대상을 특정할 수 있어야 하는데 지금은 그 키가 없다. `source_ref`
에 원본 행 id(diet-…, ex-…, chat-…)를 남겨 (user_id, source_ref) 로 찾는다.

기존 문서는 참조가 없으므로 NULL 이다. 백필하지 않는다 — 어느 문서가 어느 기록에서
나왔는지 사후에 복원할 방법이 없고, 참조 없는 문서는 지금처럼 그냥 남아 검색될 뿐
동작을 깨지 않는다.

Revision ID: 0030_doc_source_ref
Revises: 0029_aiconv_trainer
Create Date: 2026-08-11
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0030_doc_source_ref"
down_revision: str | Sequence[str] | None = "0029_aiconv_trainer"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "coach_documents",
        sa.Column("source_ref", sa.String(length=64), nullable=True),
    )
    # 교체·삭제는 항상 (user_id, source_ref) 로 좁힌다. source_ref 단독 인덱스는
    # 공공 문서(user_id NULL)까지 훑게 되어 쓸모가 적다.
    op.create_index(
        "ix_coach_documents_user_source_ref",
        "coach_documents",
        ["user_id", "source_ref"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_coach_documents_user_source_ref", table_name="coach_documents"
    )
    op.drop_column("coach_documents", "source_ref")
