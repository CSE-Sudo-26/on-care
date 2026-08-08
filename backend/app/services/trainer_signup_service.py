"""트레이너 가입 — 헬스장 초대 코드로만. (#475)

트레이너 계정을 만들 방법이 시드 스크립트뿐이었다. `/auth/register` 는 회원
전용이라 트레이너 앱에서 가입해도 `role='member'` 계정이 생기고 `/trainer/me` 가
403 을 돌려줬다 — 그래서 가입 진입점이 데모에서만 열려 있었다.

**왜 초대 코드인가.** 상담 대상 트레이너에게는 소속 헬스장이 요구된다(#443·#451).
소속을 가입 시점에 확정하지 않으면 가입 직후 상담을 받을 수 없는 상태가 되고,
공개 가입은 아무나 트레이너로 등록해 회원 상담을 받는 길을 열어 준다. 코드가
소속을 결정하면 두 문제가 함께 사라진다.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.models import Place, TrainerInviteCode, TrainerProfile, User
from app.schemas.user import TrainerRegister


class InviteCodeInvalid(Exception):
    """없는 코드, 이미 쓰인 코드, 만료된 코드 — 모두 422.

    셋을 나누지 않는 이유: 코드를 훑는 쪽에 "이 코드는 존재하지만 이미 쓰였다"를
    알려 주면 유효한 코드 공간을 좁혀 준다. 사용자에게는 어느 경우든 다시 받아야
    한다는 결론이 같다.
    """


class TrainerEmailTaken(Exception):
    """이미 가입된 이메일 — 409."""


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _claim_code(db: Session, code: str) -> TrainerInviteCode:
    """쓸 수 있는 코드를 잠근 채로 가져온다.

    `with_for_update()` 로 잠그는 이유: 같은 코드를 두 사람이 동시에 넣으면 둘 다
    '미사용' 검사를 통과해 트레이너가 두 명 생긴다. 코드는 1회용이라는 규칙이
    조용히 깨진다.
    """
    row = db.scalar(
        select(TrainerInviteCode)
        .where(TrainerInviteCode.code == code)
        .with_for_update()
    )
    if row is None or row.used_by is not None:
        raise InviteCodeInvalid("사용할 수 없는 초대 코드입니다.")
    if row.expires_at is not None and row.expires_at <= _now():
        raise InviteCodeInvalid("사용할 수 없는 초대 코드입니다.")
    # 코드가 가리키는 헬스장이 사라졌다면 소속을 만들 수 없다. FK 가 CASCADE 라
    # 정상 경로에서는 코드도 함께 지워지지만, 방어적으로 확인한다.
    if db.scalar(select(Place.id).where(Place.id == row.gym_id)) is None:
        raise InviteCodeInvalid("사용할 수 없는 초대 코드입니다.")
    return row


def register_trainer(db: Session, payload: TrainerRegister) -> User:
    """초대 코드를 확인하고 트레이너 계정과 프로필을 만든다.

    계정 생성·프로필 생성·코드 소진을 **한 트랜잭션**으로 커밋한다. 나눠 커밋하면
    계정만 만들어지고 소속이 없는 트레이너가 남거나, 코드만 소진되고 계정은 없는
    상태가 생긴다.
    """
    code = _claim_code(db, payload.invite_code)

    if db.scalar(select(User.id).where(User.email == payload.email)) is not None:
        raise TrainerEmailTaken("이미 가입된 이메일입니다.")

    trainer = User(
        id=f"trainer-{uuid.uuid4().hex[:12]}",
        email=payload.email,
        name=payload.name or payload.email.split("@")[0],
        hashed_password=hash_password(payload.password),
        role="trainer",
    )
    db.add(trainer)
    db.flush()

    db.add(TrainerProfile(trainer_id=trainer.id, gym_id=code.gym_id))
    code.used_by = trainer.id
    code.used_at = _now()

    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        # 이메일 유니크 제약만이 여기서 경합으로 터질 수 있다 — 코드는 위에서
        # 잠갔고 트레이너 id 는 새로 만든 UUID 다.
        raise TrainerEmailTaken("이미 가입된 이메일입니다.") from exc

    db.refresh(trainer)
    return trainer
