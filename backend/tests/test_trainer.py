"""트레이너 도메인 — 역할 인증 + /trainer/me.

- role 파싱/기본값은 순수(로컬 실행).
- 엔드포인트 보호(200/403/401)는 DB 필요(로컬 skip, CI 실행).
"""
from __future__ import annotations

from uuid import uuid4


def test_user_role_defaults_to_member():
    from app.models.models import User

    u = User(id="u1", email="a@b.com", name="a")
    # SQLAlchemy 컬럼 default 는 flush 시 적용되므로, 여기선 모델 기본 문자열만 확인.
    assert User.__table__.c.role.default.arg == "member"


def _trainer_token(client) -> str:
    """시드된 데모 트레이너로 로그인."""
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _member_token(client) -> str:
    email = f"member-{uuid4().hex[:8]}@oncare.com"
    client.post("/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"})
    return client.post(
        "/v1/auth/login", data={"username": email, "password": "pw!"}
    ).json()["access_token"]


def test_trainer_me_returns_profile(client):
    token = _trainer_token(client)
    r = client.get("/v1/trainer/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["name"] == "김트레이너"
    assert body["email"] == "trainer@oncare.com"
    assert body["career"] == "7년"
    assert body["gym"]["name"] == "온케어짐 신촌점"
    assert "생활스포츠지도사 2급" in body["certifications"]


def test_member_cannot_access_trainer_endpoint(client):
    token = _member_token(client)
    r = client.get("/v1/trainer/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 403


def test_unauthenticated_trainer_is_rejected(client):
    # require_trainer 는 데모 폴백을 쓰지 않으므로 토큰 없으면 401
    r = client.get("/v1/trainer/me")
    assert r.status_code == 401


def test_demo_trainer_client_links_seeded(client, db_session):
    from sqlalchemy import select

    from app.db.seed_trainer import TRAINER_ID
    from app.models.models import TrainerClient

    links = db_session.scalars(
        select(TrainerClient).where(TrainerClient.trainer_id == TRAINER_ID)
    ).all()
    assert len(links) == 3
    member_ids = {l.member_id for l in links}
    assert {"user-demo", "user-jisu", "user-sungho"} <= member_ids


# ---- 리뷰 반영: prod 데모 시드 안전장치(순수, DB 불필요) ----

def test_prod_demo_seed_requires_strong_password():
    import pytest

    from app.core.config import Settings

    common = dict(
        _env_file=None, env="prod",
        jwt_secret="a-strong-enough-production-secret-value-01234567",
        cors_allow_origins="https://app.example.com",
    )
    # 기본값 + 데모 시드 → 기동 거부
    with pytest.raises(ValueError):
        Settings(**common, seed_demo_data=True)
    # 빈 문자열·짧은 문자열·기본값 모두 거부(강도 검증)
    for weak in ("", "short", "oncare123", "abc12345678"):  # 마지막은 11자(<12)
        with pytest.raises(ValueError):
            Settings(**common, seed_demo_data=True, demo_login_password=weak)
    # 기본값이 아니고 12자 이상이면 데이터 든 데모 계정을 운영에도 둘 수 있음
    ok = Settings(**common, seed_demo_data=True, demo_login_password="Str0ng!Demo#Pass")
    assert ok.demo_login_password == "Str0ng!Demo#Pass"
    # 데모 시드를 끄면(운영 기본 권장) 당연히 통과
    off = Settings(**common, seed_demo_data=False)
    assert off.seed_demo_data is False


# ---- 리뷰 반영: 역할 분리(트레이너 토큰의 회원 API 접근 차단) ----

def test_trainer_token_rejected_by_member_api(client):
    token = _trainer_token(client)
    h = {"Authorization": f"Bearer {token}"}
    # 회원 읽기(CurrentUser)와 회원 쓰기(RequireMember) 모두 403
    assert client.get("/v1/users/me", headers=h).status_code == 403
    assert client.get("/v1/diet/days/today", headers=h).status_code == 403


def test_member_api_still_works_without_token(client):
    # 데모 폴백(회원)은 그대로 동작 — 미인증 읽기는 회원 데모로 200
    assert client.get("/v1/users/me").status_code == 200


# ---- 리뷰 반영: 시드 멱등성(이메일 충돌·재실행) ----

def test_trainer_seed_is_idempotent(client, db_session):
    from sqlalchemy import func, select

    from app.db.seed_trainer import TRAINER_ID, seed_trainer_domain
    from app.models.models import TrainerClient, User

    # 여러 번 재실행해도 계정/링크 수가 늘지 않는다
    seed_trainer_domain()
    seed_trainer_domain()
    links = db_session.scalar(
        select(func.count()).select_from(TrainerClient)
        .where(TrainerClient.trainer_id == TRAINER_ID)
    )
    assert links == 3
    trainers = db_session.scalar(
        select(func.count()).select_from(User).where(User.role == "trainer")
    )
    assert trainers >= 1


def test_email_conflict_is_detected(client, db_session):
    """이메일 충돌 감지 로직(시드가 이걸로 안전 스킵). 비파괴 — 임시행만 쓰고 정리."""
    from app.db.seed_trainer import _email_taken_by_other
    from app.models.models import User

    db_session.add(User(
        id="tmp-squatter", email="conflict-test@oncare.com", name="x", role="member",
    ))
    db_session.commit()
    try:
        # 다른 id 가 같은 이메일을 쓰려 하면 충돌로 감지 → 시드는 스킵한다
        assert _email_taken_by_other(db_session, "conflict-test@oncare.com", "other-id") is True
        # 본인 id 는 충돌 아님
        assert _email_taken_by_other(db_session, "conflict-test@oncare.com", "tmp-squatter") is False
    finally:
        db_session.query(User).filter(User.id == "tmp-squatter").delete()
        db_session.commit()
