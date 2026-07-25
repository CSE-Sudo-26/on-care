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
