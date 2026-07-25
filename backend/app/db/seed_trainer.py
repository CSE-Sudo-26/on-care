"""
트레이너 도메인 데모 시드.

트레이너 앱의 데모/데이터 공유 데모를 위해 트레이너 계정 1명(김트레이너)과
담당 회원 3명(김민수·이지수·박성호), 그리고 담당 링크를 시드한다.

핵심(진짜 데이터 공유): 여기서 만드는 회원은 실제 회원 User 다. 이후 이슈에서
이 회원들이 회원 앱으로 남긴 식단/운동/바이탈을 트레이너가 그대로 읽는다.
따라서 고객 식단 등을 여기서 복제하지 않는다.

멱등: 모든 삽입은 존재 검사 후 스킵. seed_demo_data 가 켜졌을 때만 호출된다.
데모 로그인 비밀번호는 아래 DEMO_PASSWORD(운영 시드에는 사용하지 않음).
"""
from __future__ import annotations

import json

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import models

# 트레이너 데모 계정
TRAINER_ID = "trainer-demo"
TRAINER_EMAIL = "trainer@oncare.com"
TRAINER_NAME = "김트레이너"

# 데모 계정 공통 비밀번호(트레이너 앱 실서버 로그인 데모용). 운영 시드엔 미사용.
DEMO_PASSWORD = "oncare123"

# 담당 회원: (user_id, email, name, goal, active, sort_order)
# 김민수는 회원 앱 데모 사용자(user-demo)와 동일 계정을 공유한다.
_MEMBERS: list[tuple[str, str, str, str, bool, int]] = [
    ("user-demo", "minsu@oncare.com", "김민수", "혈압 관리 · 체중 감량", True, 1),
    ("user-jisu", "jisu@oncare.com", "이지수", "체력 강화 · 다이어트", True, 2),
    ("user-sungho", "sungho@oncare.com", "박성호", "근력 향상", False, 3),
]

_CERTIFICATIONS = ["생활스포츠지도사 2급", "퍼스널트레이닝 CPT", "스포츠 영양사"]


def seed_trainer_domain() -> None:
    db: Session = SessionLocal()
    try:
        _seed_trainer_account(db)
        _seed_member_accounts(db)
        _seed_client_links(db)
    finally:
        db.close()


def _seed_trainer_account(db: Session) -> None:
    """트레이너 User + TrainerProfile(멱등)."""
    trainer = db.scalar(select(models.User).where(models.User.id == TRAINER_ID))
    if trainer is None:
        trainer = models.User(
            id=TRAINER_ID,
            email=TRAINER_EMAIL,
            name=TRAINER_NAME,
            hashed_password=hash_password(DEMO_PASSWORD),
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
    db.commit()


def _seed_member_accounts(db: Session) -> None:
    """담당 회원 User(멱등). user-demo 는 기존 데모 시드가 만들어 두므로 건너뛴다."""
    for user_id, email, name, _goal, _active, _order in _MEMBERS:
        existing = db.scalar(select(models.User).where(models.User.id == user_id))
        if existing is not None:
            continue
        db.add(models.User(
            id=user_id,
            email=email,
            name=name,
            hashed_password=hash_password(DEMO_PASSWORD),
            role="member",
        ))
    db.commit()


def _seed_client_links(db: Session) -> None:
    """트레이너↔회원 담당 링크(멱등)."""
    for user_id, _email, _name, goal, active, order in _MEMBERS:
        link_id = f"tc-{TRAINER_ID}-{user_id}"
        existing = db.scalar(
            select(models.TrainerClient).where(models.TrainerClient.id == link_id)
        )
        if existing is not None:
            continue
        db.add(models.TrainerClient(
            id=link_id,
            trainer_id=TRAINER_ID,
            member_id=user_id,
            goal=goal,
            active=active,
            sort_order=order,
        ))
    db.commit()
