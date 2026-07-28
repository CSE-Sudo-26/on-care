"""
DB 초기화 + 데모 데이터 시드.

프론트 계약상 사용자 id 는 문자열. 데모 사용자 'user-demo' 를 시드합니다
(프론트 mock 의 _usersMe 가 'user-demo' / '김민수' / 'minsu@oncare.com' 를 쓰므로 호환).
이후 STEP 들에서 이 사용자에 식단/운동/건강 데이터를 붙입니다.
"""
from __future__ import annotations

import logging

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import Base, SessionLocal, engine
from app.models import models  # noqa: F401

logger = logging.getLogger(__name__)

DEMO_USER_ID = "user-demo"


def init_db() -> None:
    settings = get_settings()

    with engine.connect() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
        conn.commit()

    # 개발 편의: create_all(멱등). 운영은 Alembic(`alembic upgrade head`)을 정답으로 삼고
    # AUTO_CREATE_TABLES=false 로 꺼둔다.
    if settings.auto_create_tables:
        Base.metadata.create_all(bind=engine)

    # 참조 데이터: 공공 식품영양성분 DB(데모/운영 무관, 멱등)
    _seed_food_nutrients()
    # 참조 데이터: 공공 코칭 가이드라인(RAG 공공 문서, 멱등·best-effort)
    _seed_public_coach_docs()

    if settings.seed_demo_data:
        _seed_demo_user()
        _seed_demo_places()
        _seed_demo_notifications()
        # 트레이너 데모(계정·프로필·담당 회원·링크). 데모 사용자 시드 뒤에 호출해야
        # 김민수(user-demo) 링크가 성립한다.
        from app.db.seed_trainer import seed_trainer_domain
        seed_trainer_domain()
        # 담당 회원 실데이터(식단·운동기록) — 트레이너 로스터/식단/기록을 실데이터로 채운다.
        # 회원 계정 시드(seed_trainer_domain) 뒤에 호출.
        from app.db.seed_member_data import seed_member_health_data
        seed_member_health_data()

    _promote_admins()  # ADMIN_EMAILS 사용자를 관리자로 승격(멱등)


def _seed_demo_user() -> None:
    db: Session = SessionLocal()
    try:
        existing = db.scalar(select(models.User).where(models.User.id == DEMO_USER_ID))
        if existing is None:
            user = models.User(
                id=DEMO_USER_ID,
                email="minsu@oncare.com",
                name="김민수",
                hashed_password="",  # 데모용. 로그인은 Stage 4.
            )
            db.add(user)
            db.commit()
    finally:
        db.close()


def _promote_admins() -> None:
    """ADMIN_EMAILS(콤마구분)에 있는 사용자를 관리자로 승격(멱등)."""
    from sqlalchemy import func

    emails = get_settings().admin_email_set
    if not emails:
        return
    db: Session = SessionLocal()
    try:
        users = db.scalars(
            select(models.User).where(func.lower(models.User.email).in_(emails))
        ).all()
        changed = False
        for u in users:
            if not u.is_admin:
                u.is_admin = True
                changed = True
        if changed:
            db.commit()
    finally:
        db.close()


def _seed_food_nutrients() -> None:
    """공공 식품영양성분 DB 큐레이션 시드(멱등). name_norm 은 매칭기와 동일 규칙으로 생성."""
    from app.data.food_nutrients_seed import FOOD_NUTRIENTS
    from app.services.nutrition.matcher import normalize

    db: Session = SessionLocal()
    try:
        if db.scalar(select(models.FoodNutrient).limit(1)):
            return
        for item in FOOD_NUTRIENTS:
            db.add(models.FoodNutrient(
                name=item["name"],
                name_norm=normalize(item["name"]),
                category=item.get("category", ""),
                serving_size_g=item.get("serving_size_g"),
                calories=item.get("calories", 0),
                sodium_mg=item.get("sodium_mg", 0),
                sugar_g=item.get("sugar_g", 0),
                carbs_g=item.get("carbs_g"),
                protein_g=item.get("protein_g"),
                fat_g=item.get("fat_g"),
            ))
        db.commit()
    finally:
        db.close()


def _seed_public_coach_docs() -> None:
    """공공 코칭 가이드라인을 RAG 공공 문서로 적재(멱등). 임베딩 불가 시 경고 로그 후 스킵."""
    from app.data.coach_public_docs import PUBLIC_DOCS
    from app.services.coach.rag import ingest_document

    db: Session = SessionLocal()
    try:
        exists = db.scalar(
            select(models.CoachDocument).where(models.CoachDocument.user_id.is_(None)).limit(1)
        )
        if exists:
            return
        for doc in PUBLIC_DOCS:
            try:
                ingest_document(
                    db, doc["content"], user_id=None,
                    domain=doc["domain"], source="public", title=doc["title"],
                )
            except Exception:  # noqa: BLE001 — 적재 실패가 기동을 막지 않도록
                # 조용히 삼키면 RAG 가 빈 채로 코치가 규칙 폴백에 갇혀 원인 파악이 어렵다.
                logger.warning(
                    "공공 코칭 문서 적재 실패 — 임베딩 제공자(EMBEDDER) 설정 확인 필요: %s",
                    doc.get("title"),
                    exc_info=True,
                )
                db.rollback()
    finally:
        db.close()


def _seed_demo_places() -> None:
    """서울시청 인근 데모 장소 (카카오맵 실연동 전까지 사용)."""
    db: Session = SessionLocal()
    try:
        if db.scalar(select(models.Place).limit(1)):
            return
        demo = [
            ("place-1", "온케어 내과의원", "medical", "서울 중구 세종대로 110", 37.5660, 126.9785),
            ("place-2", "헬스플러스 피트니스", "fitness", "서울 중구 을지로 50", 37.5663, 126.9820),
            ("place-3", "그린샐러드 키친", "healthy_food", "서울 중구 명동길 20", 37.5638, 126.9850),
            ("place-4", "건강약국", "pharmacy", "서울 중구 태평로 30", 37.5650, 126.9770),
            ("place-5", "한강공원 러닝트랙", "fitness", "서울 영등포구 여의동로 330", 37.5283, 126.9325),
        ]
        for pid, name, cat, addr, lat, lng in demo:
            db.add(models.Place(id=pid, name=name, category=cat, address=addr, lat=lat, lng=lng))
        db.commit()
    finally:
        db.close()


def _seed_demo_notifications() -> None:
    db: Session = SessionLocal()
    try:
        if db.scalar(select(models.Notification).where(models.Notification.user_id == DEMO_USER_ID).limit(1)):
            return
        demo = [
            ("noti-1", "오늘의 혈압을 기록해 주세요", "정기 측정 시간이에요.", "reminder"),
            ("noti-2", "이번 주 운동 목표 80% 달성!", "조금만 더 힘내세요!", "achievement"),
            ("noti-3", "건강검진 예약 안내", "다음 주 화요일 검진 일정이 있어요.", "health_check"),
        ]
        for nid, title, body, cat in demo:
            db.add(models.Notification(
                id=nid, user_id=DEMO_USER_ID, title=title, body=body, category=cat, read=False,
            ))
        db.commit()
    finally:
        db.close()
