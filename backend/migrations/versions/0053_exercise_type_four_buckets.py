"""운동 유형을 네 가지로 좁힌다 — 유산소 / 근력 / 유연성 / 기타.

회원 기록(`exercise_sessions.type`)은 `cardio|strength|yoga|walking`, 트레이너
루틴(`trainer_routines.type`)은 `걷기|유산소|근력|요가|스트레칭|기타` 로 서로 다른
어휘를 썼다. 같은 운동을 두 화면이 다르게 부르니 집계·리포트가 화면마다 버킷을
다시 만들어야 했고, 주간 운동 이행률을 유형별로 보여 주려면 어느 쪽 어휘를 기준으로
할지부터 정해야 했다(#996).

걷기는 유산소로, 요가·스트레칭은 유연성으로 접는다. 셋 다 없어지는 정보가 아니라
**운동 이름**에 남는다 — "저강도 걷기"는 이름이 걷기이고 유형이 유산소다.

되돌리기는 유산소·유연성을 옛 이름 하나로 되돌릴 수 없다(걷기였는지 러닝이었는지
유형만으로는 알 수 없다). downgrade 는 표를 그대로 둔다 — 값이 표준 어휘로 남아도
옛 코드가 읽지 못하는 자리는 없다.

Revision ID: 0053_exercise_type_four_buckets
Revises: 0052_refresh_token_revocation
"""
from __future__ import annotations

from collections.abc import Sequence

from alembic import op

revision: str = "0053_exercise_type_four_buckets"
down_revision: str | Sequence[str] | None = "0052_refresh_token_revocation"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

#: 회원 기록 — 영문 코드.
_SESSION_MAP = {
    "walking": "cardio",
    "yoga": "flexibility",
    "stretching": "flexibility",
}

#: 트레이너 루틴 — 한글 라벨.
_ROUTINE_MAP = {
    "걷기": "유산소",
    "요가": "유연성",
    "스트레칭": "유연성",
}


def upgrade() -> None:
    for old, new in _SESSION_MAP.items():
        op.execute(
            f"UPDATE exercise_sessions SET type = '{new}' WHERE type = '{old}'"
        )
    for old, new in _ROUTINE_MAP.items():
        op.execute(
            f"UPDATE trainer_routines SET type = '{new}' WHERE type = '{old}'"
        )

    # 표준 어휘 밖의 값은 기타로 모은다. 손으로 넣은 값이나 옛 실험이 남아 있으면
    # 집계에서 조용히 유산소로 세어지는 것보다 기타로 드러나는 편이 낫다.
    op.execute(
        "UPDATE exercise_sessions SET type = 'other' "
        "WHERE type NOT IN ('cardio', 'strength', 'flexibility', 'other')"
    )
    op.execute(
        "UPDATE trainer_routines SET type = '기타' "
        "WHERE type NOT IN ('유산소', '근력', '유연성', '기타')"
    )


def downgrade() -> None:
    """되돌리지 않는다 — 접힌 유형은 옛 이름을 복원할 수 없다."""
