"""트레이너 가입 — 헬스장 초대 코드. (#475)

트레이너 계정을 만들 방법이 시드 스크립트뿐이었다. 가입한 계정이 실제로
트레이너로 동작하는지(= `/trainer/me` 가 200 을 주고 소속이 붙는지)를 확인한다 —
`users.role` 만 보면 "가입은 됐는데 아무것도 못 하는" 상태를 놓친다.

DB 가 필요하므로 로컬에서는 skip 되고 CI(Postgres) 에서 실행된다.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.models.models import (
    Place,
    TrainerInviteCode,
    TrainerProfile,
    User,
)

EMAIL_PREFIX = "signup-test-"
PLACE_PREFIX = "signup-place-"
CODE_PREFIX = "SIGNUPTEST"
PASSWORD = "signup-pw-1234"


@pytest.fixture(autouse=True)
def _cleanup(db_session):
    yield
    db_session.rollback()
    user_ids = [
        row[0]
        for row in db_session.query(User.id)
        .filter(User.email.like(f"{EMAIL_PREFIX}%"))
        .all()
    ]
    db_session.query(TrainerInviteCode).filter(
        TrainerInviteCode.code.like(f"{CODE_PREFIX}%")
    ).delete(synchronize_session=False)
    if user_ids:
        db_session.query(TrainerProfile).filter(
            TrainerProfile.trainer_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db_session.query(User).filter(User.id.in_(user_ids)).delete(
            synchronize_session=False
        )
    db_session.query(Place).filter(Place.id.like(f"{PLACE_PREFIX}%")).delete(
        synchronize_session=False
    )
    db_session.commit()


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _gym(db_session) -> Place:
    place = Place(
        id=f"{PLACE_PREFIX}{uuid4().hex[:10]}",
        name="가입 테스트 헬스장",
        category="fitness",
        address="서울",
    )
    db_session.add(place)
    db_session.commit()
    return place


def _code(
    db_session,
    *,
    gym: Place | None = None,
    used_by: str | None = None,
    expires_at: datetime | None = None,
) -> TrainerInviteCode:
    code = TrainerInviteCode(
        code=f"{CODE_PREFIX}{uuid4().hex[:8].upper()}",
        gym_id=(gym or _gym(db_session)).id,
        used_by=used_by,
        expires_at=expires_at,
    )
    db_session.add(code)
    db_session.commit()
    return code


def _payload(code: str, *, email: str | None = None) -> dict:
    return {
        "email": email or f"{EMAIL_PREFIX}{uuid4().hex[:10]}@oncare.com",
        "password": PASSWORD,
        "name": "신규 트레이너",
        "invite_code": code,
    }


def _login(client, email: str) -> str:
    response = client.post(
        "/v1/auth/login", data={"username": email, "password": PASSWORD}
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def test_invite_code_creates_a_working_trainer(client, db_session):
    """가입한 계정이 실제로 트레이너로 동작하고 소속이 붙는다."""
    gym = _gym(db_session)
    code = _code(db_session, gym=gym)
    payload = _payload(code.code)

    response = client.post("/v1/auth/trainer/register", json=payload)

    assert response.status_code == 201, response.text
    assert response.json()["email"] == payload["email"]

    # role 만 보지 않는다 — 트레이너 앱이 처음 부르는 엔드포인트로 확인한다.
    me = client.get("/v1/trainer/me", headers=_auth(_login(client, payload["email"])))
    assert me.status_code == 200, me.text
    assert me.json()["gym"]["id"] == gym.id


def test_the_code_is_spent_after_use(client, db_session):
    """코드는 1회용이다 — 두 번째 가입은 거절된다."""
    code = _code(db_session)

    first = client.post("/v1/auth/trainer/register", json=_payload(code.code))
    second = client.post("/v1/auth/trainer/register", json=_payload(code.code))

    assert first.status_code == 201, first.text
    assert second.status_code == 422, second.text

    db_session.expire_all()
    spent = db_session.get(TrainerInviteCode, code.code)
    assert spent.used_by == first.json()["id"]
    assert spent.used_at is not None


def test_unknown_code_is_rejected(client):
    response = client.post(
        "/v1/auth/trainer/register", json=_payload(f"{CODE_PREFIX}NOPE")
    )
    assert response.status_code == 422, response.text


def test_expired_code_is_rejected(client, db_session):
    code = _code(
        db_session,
        expires_at=datetime.now(timezone.utc) - timedelta(days=1),
    )

    response = client.post("/v1/auth/trainer/register", json=_payload(code.code))

    assert response.status_code == 422, response.text


def test_code_is_matched_case_insensitively(client, db_session):
    """사람이 옮겨 적는 값이다 — 소문자·공백을 코드 오류로 만들지 않는다."""
    code = _code(db_session)
    payload = _payload(f"  {code.code.lower()}  ")

    response = client.post("/v1/auth/trainer/register", json=payload)

    assert response.status_code == 201, response.text


def test_duplicate_email_conflicts_and_keeps_the_code_usable(
    client, db_session
):
    """이메일이 겹쳐 실패하면 코드는 소진되지 않아야 한다.

    코드만 날아가면 트레이너는 오타 한 번에 헬스장에 코드를 다시 요청해야 한다.
    """
    code = _code(db_session)
    taken = f"{EMAIL_PREFIX}{uuid4().hex[:10]}@oncare.com"
    client.post("/v1/auth/register", json={
        "email": taken, "password": PASSWORD, "name": "회원",
    })

    response = client.post(
        "/v1/auth/trainer/register", json=_payload(code.code, email=taken)
    )

    assert response.status_code == 409, response.text
    db_session.expire_all()
    assert db_session.get(TrainerInviteCode, code.code).used_by is None


def test_failed_signup_leaves_no_half_built_account(client, db_session):
    """실패한 가입은 계정도 프로필도 남기지 않는다."""
    email = f"{EMAIL_PREFIX}{uuid4().hex[:10]}@oncare.com"

    response = client.post(
        "/v1/auth/trainer/register",
        json=_payload(f"{CODE_PREFIX}MISSING", email=email),
    )

    assert response.status_code == 422, response.text
    assert db_session.query(User).filter(User.email == email).count() == 0


def test_member_register_still_creates_a_member(client):
    """회원 가입 경로는 그대로다 — 트레이너가 되지 않는다."""
    email = f"{EMAIL_PREFIX}{uuid4().hex[:10]}@oncare.com"
    created = client.post(
        "/v1/auth/register",
        json={"email": email, "password": PASSWORD, "name": "회원"},
    )
    assert created.status_code == 201, created.text

    me = client.get("/v1/trainer/me", headers=_auth(_login(client, email)))

    # 회원 계정은 트레이너 엔드포인트에서 403 이어야 한다.
    assert me.status_code == 403, me.text


def test_signup_requires_an_invite_code(client):
    """코드 없이 트레이너로 가입할 수 있는 경로가 없어야 한다."""
    response = client.post(
        "/v1/auth/trainer/register",
        json={
            "email": f"{EMAIL_PREFIX}{uuid4().hex[:10]}@oncare.com",
            "password": PASSWORD,
            "name": "코드 없음",
        },
    )

    assert response.status_code == 422, response.text
