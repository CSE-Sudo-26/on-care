"""
트레이너 도메인 데모 시드.

트레이너 앱의 데모/데이터 공유 데모를 위해 트레이너 계정 1명(김트레이너)과
담당 회원 3명(김민수·이지수·박성호), 그리고 담당 링크를 시드한다.

핵심(진짜 데이터 공유): 여기서 만드는 회원은 실제 회원 User 다. 이후 이슈에서
이 회원들이 회원 앱으로 남긴 식단/운동/바이탈을 트레이너가 그대로 읽는다.
따라서 고객 식단 등을 여기서 복제하지 않는다.

멱등: 모든 삽입은 id·이메일 존재 검사 후 스킵한다. 같은 이메일을 가진 다른 id 의
사용자가 이미 있으면(users.email 유니크) 삽입을 건너뛰어 기동 실패를 막는다.
seed_demo_data 가 켜졌을 때만 호출된다. 데모 로그인 비밀번호는 설정값
(DEMO_LOGIN_PASSWORD)에서 읽는다 — 운영에서 데모 시드를 켜면 강한 값이 강제된다.
"""
from __future__ import annotations

import json
import logging

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import models

logger = logging.getLogger(__name__)

#: PostgreSQL unique_violation. 동시 기동이 같은 결정론적 id/이메일을 경쟁 삽입할 때만
#: 나는 코드로, 이때만 '이미 다른 인스턴스가 넣음'으로 보고 넘긴다.
_PG_UNIQUE_VIOLATION = "23505"


def _safe_commit(db: Session, context: str) -> None:
    """시드 커밋. 동시 기동 경쟁의 UNIQUE 충돌(23505)만 무시하고, FK(23503)·NOT NULL
    (23502)·CHECK 등 진짜 오류는 다시 발생시켜(데이터가 롤백된 채 조용히 기동 계속 방지)
    기동을 실패시킨다."""
    try:
        db.commit()
    except IntegrityError as e:
        db.rollback()
        sqlstate = getattr(getattr(e, "orig", None), "sqlstate", None)
        if sqlstate != _PG_UNIQUE_VIOLATION:
            raise
        logger.warning("%s — 동시 기동 경쟁으로 롤백 후 스킵.", context, exc_info=True)


# 트레이너 데모 계정
TRAINER_ID = "trainer-demo"
TRAINER_EMAIL = "trainer@oncare.com"
TRAINER_NAME = "김트레이너"

# 담당 회원: (user_id, email, name, goal, active, sort_order)
# 김민수는 회원 앱 데모 사용자(user-demo)와 동일 계정을 공유한다.
_MEMBERS: list[tuple[str, str, str, str, bool, int]] = [
    ("user-demo", "minsu@oncare.com", "김민수", "혈압 관리 · 체중 감량", True, 1),
    ("user-jisu", "jisu@oncare.com", "이지수", "체력 강화 · 다이어트", True, 2),
    ("user-sungho", "sungho@oncare.com", "박성호", "근력 향상", False, 3),
]

_CERTIFICATIONS = ["생활스포츠지도사 2급", "퍼스널트레이닝 CPT", "스포츠 영양사"]


def _demo_password_hash() -> str:
    return hash_password(get_settings().demo_login_password)


def _email_taken_by_other(db: Session, email: str, user_id: str) -> bool:
    """이 이메일을 가진 '다른 id' 의 사용자가 이미 있으면 True(유니크 충돌 예방)."""
    other = db.scalar(
        select(models.User.id).where(models.User.email == email, models.User.id != user_id)
    )
    return other is not None


def seed_trainer_domain() -> None:
    db: Session = SessionLocal()
    try:
        _seed_trainer_account(db)
        _seed_member_accounts(db)
        _seed_client_links(db)
    finally:
        db.close()


def _seed_trainer_account(db: Session) -> None:
    """트레이너 User + TrainerProfile(멱등, 이메일·역할 충돌 안전)."""
    trainer = db.scalar(select(models.User).where(models.User.id == TRAINER_ID))
    if trainer is not None:
        # 기존 ID 가 트레이너 데모와 역할/이메일이 다르면(예: 회원 계정이 선점) 프로필을
        # 붙이지 않는다 — 남의 계정을 트레이너로 오염시키지 않도록.
        if trainer.role != "trainer" or trainer.email != TRAINER_EMAIL:
            logger.warning(
                "기존 %s 계정이 트레이너 데모와 역할/이메일 불일치(role=%s) — 프로필 시드 스킵.",
                TRAINER_ID, trainer.role,
            )
            return
    else:
        if _email_taken_by_other(db, TRAINER_EMAIL, TRAINER_ID):
            logger.warning(
                "트레이너 데모 이메일 %s 가 다른 계정에 선점됨 — 트레이너 시드 스킵.",
                TRAINER_EMAIL,
            )
            return
        trainer = models.User(
            id=TRAINER_ID,
            email=TRAINER_EMAIL,
            name=TRAINER_NAME,
            hashed_password=_demo_password_hash(),
            role="trainer",
        )
        db.add(trainer)
        db.flush()

    profile = db.scalar(
        select(models.TrainerProfile).where(models.TrainerProfile.trainer_id == TRAINER_ID)
    )
    if profile is None:
        db.add(models.TrainerProfile(
            trainer_id=TRAINER_ID,
            phone="010-1234-5678",
            specialty="퍼스널 트레이너",
            # 추천 레일 노출 조건(#324). 비어 있으면 /trainers/recommended 에서 빠진다.
            recommend_reason="혈압 관리와 운동 병행 지도",
            career_years=7,
            intro=(
                "혈압 관리와 체중 감량 전문 트레이너입니다. 고객 맞춤형 AI 루틴으로 "
                "안전하고 효과적인 운동을 도와드려요."
            ),
            certifications_json=json.dumps(_CERTIFICATIONS, ensure_ascii=False),
            gym_name="온케어짐 신촌점",
            gym_address="서울 서대문구 신촌로 120",
            gym_hours="06:00 – 23:00",
            gym_phone="02-1234-5678",
        ))
    elif not profile.recommend_reason:
        # 프로필이 이미 있으면 위 블록을 건너뛰므로, 나중에 추가된 컬럼은 영영 빈 채로
        # 남는다. 추천 사유가 비면 /trainers/recommended 에서 빠지므로 백필한다(#324).
        profile.recommend_reason = "혈압 관리와 운동 병행 지도"
    _safe_commit(db, "트레이너 데모 계정 시드 충돌")


def _seed_member_accounts(db: Session) -> None:
    """담당 회원 User(멱등, 이메일 충돌 안전). user-demo 는 기존 데모 시드가 만든다."""
    for user_id, email, name, _goal, _active, _order in _MEMBERS:
        if db.scalar(select(models.User.id).where(models.User.id == user_id)) is not None:
            continue
        if _email_taken_by_other(db, email, user_id):
            logger.warning(
                "회원 데모 이메일 %s 가 다른 계정에 선점됨 — %s 시드 스킵.", email, user_id,
            )
            continue
        db.add(models.User(
            id=user_id,
            email=email,
            name=name,
            hashed_password=_demo_password_hash(),
            role="member",
        ))
    _safe_commit(db, "회원 데모 계정 시드 충돌")


def _seed_client_links(db: Session) -> None:
    """트레이너↔회원 담당 링크(멱등). 트레이너/회원 역할이 맞아야만 링크한다."""
    trainer = db.scalar(select(models.User).where(models.User.id == TRAINER_ID))
    if trainer is None or trainer.role != "trainer":
        # 트레이너 계정이 없거나(시드 스킵) 역할이 트레이너가 아니면 링크를 만들지 않는다.
        return
    for user_id, _email, _name, goal, active, order in _MEMBERS:
        link_id = f"tc-{TRAINER_ID}-{user_id}"
        if db.scalar(select(models.TrainerClient.id).where(models.TrainerClient.id == link_id)):
            continue
        member = db.scalar(select(models.User).where(models.User.id == user_id))
        if member is None:
            continue
        # 기존 ID 가 회원이 아니면(예: 트레이너 역할) 담당 링크를 만들지 않는다.
        if member.role != "member":
            logger.warning(
                "기존 %s 계정이 회원이 아님(role=%s) — 담당 링크 시드 스킵.",
                user_id, member.role,
            )
            continue
        db.add(models.TrainerClient(
            id=link_id,
            trainer_id=TRAINER_ID,
            member_id=user_id,
            goal=goal,
            active=active,
            sort_order=order,
        ))
    _safe_commit(db, "담당 링크 시드 충돌")
