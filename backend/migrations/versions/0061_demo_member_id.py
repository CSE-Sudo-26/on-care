"""데모 계정 김민수의 id 를 실 서비스 형태로 옮긴다.

회원 고유 ID 로 신규 고객을 찾아 연결하는 기능을 붙이면서, 회원 ID 가 실제로는
`user-<12자리 hex>` 형태의 추측하기 어려운 값이어야 한다는 게 분명해졌다. 그런데
대표 데모 계정의 id 는 `user-demo` 였다 — 실사용자 계정과 형태로 구분되고, 화면에
그 값을 그대로 보여 줄 수가 없어 두 화면이 임시로 다른 값을 대신 보여 주고 있었다.

시드는 새 id 로 행을 만든다. 이 마이그레이션이 없으면 이미 떠 있는 DB 에서 옛
`user-demo` 행이 그대로 남아, 같은 사람이 둘이 되고 그가 쌓아 둔 식단·운동·대화는
아무도 읽지 않는 옛 id 에 묶인다. 그래서 **지우지 않고 옮긴다.**

`users.id` 는 여러 테이블이 참조하는 기본키다. 부모를 먼저 바꾸면 그 순간 자식이
없는 부모를 가리키므로, 이 트랜잭션 동안만 외래키 검사를 커밋 시점으로 미룬 뒤
부모와 자식을 함께 옮긴다. 시드가 만든 행 중에는 id 자체에 회원 id 를 박아 둔
것들이 있어(`seed-routine-{회원}-0`) 그 문자열도 함께 고친다 — 그러지 않으면 다음
시드가 새 id 로 같은 행을 한 벌 더 만든다.

`user-demo` 행이 없는 DB(새로 만든 DB·이미 옮긴 DB)에서는 아무 일도 하지 않는다.

Revision ID: 0061_demo_member_id
Revises: 0060_strength_reps
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0061_demo_member_id"
down_revision: str | Sequence[str] | None = "0060_strength_reps"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

OLD_ID = "user-demo"
NEW_ID = "user-7d4e9a2c5f18"

#: `users.id` 를 가리키는 외래키를 찾는다. 손으로 적어 두면 나중에 생긴 테이블이
#: 조용히 빠진다 — 카탈로그에 물어보는 편이 낫다.
_FK_QUERY = sa.text(
    """
    SELECT tc.table_name, kcu.column_name, tc.constraint_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON kcu.constraint_name = tc.constraint_name
       AND kcu.constraint_schema = tc.constraint_schema
      JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
       AND ccu.constraint_schema = tc.constraint_schema
     WHERE tc.constraint_type = 'FOREIGN KEY'
       AND tc.table_schema = current_schema()
       AND ccu.table_name = 'users'
       AND ccu.column_name = 'id'
    """
)

#: id 문자열 안에 회원 id 를 박아 둔 시드 행들. (테이블, 컬럼)
_EMBEDDED_ID_COLUMNS = (
    ("diet_entries", "id"),
    ("exercise_sessions", "id"),
    ("chat_messages", "id"),
    ("trainer_routines", "id"),
    ("routine_history", "id"),
)


def _move(old: str, new: str) -> None:
    conn = op.get_bind()
    if conn.dialect.name != "postgresql":
        return
    exists = conn.execute(
        sa.text("SELECT 1 FROM users WHERE id = :old"), {"old": old}
    ).first()
    if exists is None:
        return
    if conn.execute(
        sa.text("SELECT 1 FROM users WHERE id = :new"), {"new": new}
    ).first():
        # 새 id 가 이미 있다면 옮길 자리가 없다. 옛 행을 남겨 두고 사람이 보게
        # 한다 — 두 계정을 말없이 합치는 것보다 낫다.
        return

    fks = conn.execute(_FK_QUERY).fetchall()
    for table, _column, constraint in fks:
        op.execute(
            f'ALTER TABLE "{table}" ALTER CONSTRAINT "{constraint}" DEFERRABLE'
        )
    op.execute("SET CONSTRAINTS ALL DEFERRED")

    conn.execute(
        sa.text("UPDATE users SET id = :new WHERE id = :old"),
        {"old": old, "new": new},
    )
    for table, column, _constraint in fks:
        conn.execute(
            sa.text(
                f'UPDATE "{table}" SET "{column}" = :new WHERE "{column}" = :old'
            ),
            {"old": old, "new": new},
        )

    for table, column in _EMBEDDED_ID_COLUMNS:
        if not conn.dialect.has_table(conn, table):
            continue
        conn.execute(
            sa.text(
                f'UPDATE "{table}" SET "{column}" = REPLACE("{column}", :old, :new) '
                f'WHERE "{column}" LIKE :pattern'
            ),
            {"old": old, "new": new, "pattern": f"%{old}%"},
        )

    # 미뤄 둔 검사를 여기서 끝낸다. 남겨 두면 곧바로 이어지는 ALTER 가
    # "pending trigger events" 로 막히고, 무엇보다 여기서 걸릴 문제라면 커밋
    # 순간이 아니라 이 자리에서 드러나는 편이 낫다.
    op.execute("SET CONSTRAINTS ALL IMMEDIATE")
    for table, _column, constraint in fks:
        op.execute(
            f'ALTER TABLE "{table}" ALTER CONSTRAINT "{constraint}" NOT DEFERRABLE'
        )


def upgrade() -> None:
    _move(OLD_ID, NEW_ID)


def downgrade() -> None:
    _move(NEW_ID, OLD_ID)
