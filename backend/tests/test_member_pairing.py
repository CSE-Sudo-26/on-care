"""회원이 띄우고 트레이너가 입력하는 6자리 동기화 코드. (#1634)

담당 관계가 생기는 **세 번째 경로**다. 앞의 둘(회원의 상담 요청 → 트레이너
수락, 트레이너의 담당 요청 → 회원 수락)과 다른 점은 동의가 먼저 온다는 것이다 —
코드를 발급해 불러 준 것이 회원 본인이라, 트레이너가 코드를 쓰는 순간 담당이
바로 성립한다.

여기서 가장 중요하게 보는 것 둘.

  * 코드는 **1회용**이고, 만료되거나 취소되면 통하지 않는다.
  * 연결이 실패하면 **코드가 살아남는다.** 코드만 사라지고 담당은 안 생긴
    상태가 되면 회원은 다시 띄워야 하는데 트레이너 화면에는 성공으로 보인다.

DB 가 필요하므로 로컬에서는 skip 되고 CI(Postgres) 에서 실행된다.
"""
from __future__ import annotations

from datetime import timedelta
from uuid import uuid4

import pytest

from app.core import clock
from app.core.security import hash_password
from app.models.models import (
    MemberGym,
    MemberPairingCode,
    Notification,
    Place,
    TrainerClient,
    TrainerClientInvite,
    TrainerProfile,
    User,
)

EMAIL_PREFIX = "pairing-test-"
PLACE_PREFIX = "pairing-place-"
PASSWORD = "pairing-pw-1234"


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
    if user_ids:
        db_session.query(MemberPairingCode).filter(
            MemberPairingCode.member_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db_session.query(TrainerClientInvite).filter(
            (TrainerClientInvite.trainer_id.in_(user_ids))
            | (TrainerClientInvite.member_id.in_(user_ids))
        ).delete(synchronize_session=False)
        db_session.query(TrainerClient).filter(
            (TrainerClient.trainer_id.in_(user_ids))
            | (TrainerClient.member_id.in_(user_ids))
        ).delete(synchronize_session=False)
        db_session.query(Notification).filter(
            Notification.user_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db_session.query(MemberGym).filter(
            MemberGym.member_id.in_(user_ids)
        ).delete(synchronize_session=False)
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


def _login(client, email: str) -> str:
    response = client.post(
        "/v1/auth/login", data={"username": email, "password": PASSWORD}
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def _member(client, name: str = "동기화 회원") -> tuple[str, str]:
    """회원 하나. (id, token)"""
    email = f"{EMAIL_PREFIX}member-{uuid4().hex[:10]}@oncare.com"
    response = client.post(
        "/v1/auth/register",
        json={
            "email": email,
            "password": PASSWORD,
            "name": name,
            "phone": "010-1234-5678",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()["id"], _login(client, email)


def _trainer(client, db_session) -> tuple[str, str]:
    """트레이너 하나. (id, token)"""
    suffix = uuid4().hex[:10]
    email = f"{EMAIL_PREFIX}trainer-{suffix}@oncare.com"
    place = Place(
        id=f"{PLACE_PREFIX}{suffix}",
        name="동기화 테스트 헬스장",
        category="fitness",
        address="서울",
    )
    db_session.add(place)
    trainer = User(
        id=f"pairing-trainer-{suffix}",
        email=email,
        name="동기화 테스트 트레이너",
        hashed_password=hash_password(PASSWORD),
        role="trainer",
        is_active=True,
    )
    db_session.add(trainer)
    db_session.flush()
    db_session.add(TrainerProfile(trainer_id=trainer.id, gym_id=place.id))
    db_session.commit()
    return trainer.id, _login(client, email)


def _issue(client, member_token: str) -> str:
    response = client.post(
        "/v1/users/me/pairing-code", headers=_auth(member_token)
    )
    assert response.status_code == 200, response.text
    return response.json()["code"]


def _redeem(client, trainer_token: str, code: str):
    return client.post(
        "/v1/trainer/pairing-code",
        json={"code": code},
        headers=_auth(trainer_token),
    )


def _roster_ids(client, trainer_token: str) -> list[str]:
    response = client.get("/v1/trainer/clients", headers=_auth(trainer_token))
    assert response.status_code == 200, response.text
    return [row["id"] for row in response.json()]


# ---------------------------------------------------------------------------
# 발급
# ---------------------------------------------------------------------------


def test_issuing_gives_six_digits_and_a_countdown(client):
    _, token = _member(client)

    response = client.post("/v1/users/me/pairing-code", headers=_auth(token))

    assert response.status_code == 200, response.text
    body = response.json()
    assert len(body["code"]) == 6
    assert body["code"].isdigit()
    # 화면이 기기 시계에 기대지 않도록 남은 초를 서버가 센다.
    assert 0 < body["expires_in_seconds"] <= 5 * 60


def test_issuing_twice_returns_the_same_code(client):
    """화면을 다시 열 때마다 새로 뽑으면 트레이너가 이미 받아 적은 값이 말없이
    무효가 된다."""
    _, token = _member(client)

    assert _issue(client, token) == _issue(client, token)


def test_revoking_throws_the_code_away(client, db_session):
    """발급이 동의였으니 취소도 즉시 반영돼야 한다."""
    _, member_token = _member(client)
    _, trainer_token = _trainer(client, db_session)
    code = _issue(client, member_token)

    response = client.delete(
        "/v1/users/me/pairing-code", headers=_auth(member_token)
    )
    assert response.status_code == 204, response.text

    assert _redeem(client, trainer_token, code).status_code == 404


# ---------------------------------------------------------------------------
# 사용
# ---------------------------------------------------------------------------


def test_redeeming_links_the_member_right_away(client, db_session):
    """코드를 불러 준 것이 회원 본인이라 한 번 더 수락받지 않는다."""
    member_id, member_token = _member(client, name="바로연결")
    trainer_id, trainer_token = _trainer(client, db_session)
    code = _issue(client, member_token)

    response = _redeem(client, trainer_token, code)

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["member_id"] == member_id
    assert body["name"] == "바로연결"
    assert member_id in _roster_ids(client, trainer_token)

    # 회원 쪽에서도 담당이 보인다 — 링크가 진짜로 생겼다는 뜻.
    coach = client.get("/v1/me/coach", headers=_auth(member_token))
    assert coach.status_code == 200, coach.text


def test_redeeming_records_the_consent_given_when_the_code_was_issued(
    client, db_session
):
    """담당은 상대의 식단·건강 기록을 여는 권한이라 동의 없이 열 수 없다 (#1022).

    코드를 띄운 화면이 공유 범위를 말하므로, 그 발급 시각이 동의 시각이다.
    """
    member_id, member_token = _member(client)
    trainer_id, trainer_token = _trainer(client, db_session)
    code = _issue(client, member_token)
    issued_at = db_session.query(MemberPairingCode.created_at).filter(
        MemberPairingCode.member_id == member_id
    ).scalar()

    assert _redeem(client, trainer_token, code).status_code == 200

    link = (
        db_session.query(TrainerClient)
        .filter(
            TrainerClient.trainer_id == trainer_id,
            TrainerClient.member_id == member_id,
        )
        .one()
    )
    assert link.data_consent_at == issued_at


def test_redeeming_leaves_an_accepted_invite_for_the_trail(client, db_session):
    """어느 경로로 담당이 생겼는지 남지 않으면 나중에 되짚을 수 없다."""
    member_id, member_token = _member(client)
    trainer_id, trainer_token = _trainer(client, db_session)

    assert _redeem(client, trainer_token, _issue(client, member_token)).status_code == 200

    row = (
        db_session.query(TrainerClientInvite)
        .filter(
            TrainerClientInvite.trainer_id == trainer_id,
            TrainerClientInvite.member_id == member_id,
        )
        .one()
    )
    assert row.status == "accepted"
    assert row.decided_at is not None


def test_redeeming_tells_the_member_their_records_are_now_shared(
    client, db_session
):
    """회원은 트레이너가 언제 코드를 입력했는지 화면으로 알 수 없다."""
    member_id, member_token = _member(client)
    _, trainer_token = _trainer(client, db_session)

    assert _redeem(client, trainer_token, _issue(client, member_token)).status_code == 200

    assert (
        db_session.query(Notification)
        .filter(Notification.user_id == member_id)
        .count()
        >= 1
    )


def test_a_code_works_only_once(client, db_session):
    member_id, member_token = _member(client)
    _, first_token = _trainer(client, db_session)
    _, second_token = _trainer(client, db_session)
    code = _issue(client, member_token)

    assert _redeem(client, first_token, code).status_code == 200
    assert _redeem(client, second_token, code).status_code == 404


def test_an_expired_code_does_not_work(client, db_session):
    member_id, member_token = _member(client)
    _, trainer_token = _trainer(client, db_session)
    code = _issue(client, member_token)

    row = db_session.query(MemberPairingCode).filter(
        MemberPairingCode.member_id == member_id
    ).one()
    row.expires_at = clock.now() - timedelta(seconds=1)
    db_session.commit()

    assert _redeem(client, trainer_token, code).status_code == 404


def test_a_wrong_code_does_not_say_why(client, db_session):
    """틀렸는지·만료됐는지·이미 쓰였는지를 갈라 주면 어떤 코드가 존재하기는
    했는지를 알려 주는 셈이다."""
    _, trainer_token = _trainer(client, db_session)

    assert _redeem(client, trainer_token, "000000").status_code == 404
    assert _redeem(client, trainer_token, "12").status_code == 404


def test_hyphens_and_spaces_are_not_an_error(client, db_session):
    """사람이 받아 적는 값이라 표기 차이를 오류로 돌려주면 안 된다."""
    member_id, member_token = _member(client)
    _, trainer_token = _trainer(client, db_session)
    code = _issue(client, member_token)

    response = _redeem(client, trainer_token, f" {code[:3]}-{code[3:]} ")

    assert response.status_code == 200, response.text
    assert response.json()["member_id"] == member_id


def test_a_failed_redeem_keeps_the_code_alive(client, db_session):
    """이것이 이 기능에서 가장 조용히 깨질 수 있는 자리다.

    코드만 사라지고 담당은 안 생기면, 회원은 코드를 다시 띄워야 하는데
    트레이너 화면에는 아무 일도 없었던 것처럼 보인다.
    """
    member_id, member_token = _member(client)
    _, first_token = _trainer(client, db_session)
    _, second_token = _trainer(client, db_session)

    # 먼저 다른 트레이너가 담당이 된다.
    assert _redeem(client, first_token, _issue(client, member_token)).status_code == 200
    code = _issue(client, member_token)

    # 회원당 활성 담당은 1명이라 두 번째 트레이너는 거절된다.
    assert _redeem(client, second_token, code).status_code == 409

    # 그런데 코드는 살아 있어야 한다.
    assert (
        db_session.query(MemberPairingCode)
        .filter(MemberPairingCode.code == code)
        .count()
        == 1
    )


def test_a_member_cannot_redeem_a_code(client):
    """이 문은 트레이너만 연다."""
    _, member_token = _member(client)
    code = _issue(client, member_token)

    response = client.post(
        "/v1/trainer/pairing-code",
        json={"code": code},
        headers=_auth(member_token),
    )

    assert response.status_code in (401, 403), response.text
