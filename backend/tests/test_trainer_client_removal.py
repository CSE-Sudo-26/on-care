"""트레이너 고객 삭제는 계정 삭제가 아닌 담당 관계 해제다."""

from uuid import uuid4

from sqlalchemy import select

from app.core.security import create_access_token
from app.models.models import TrainerClient, User


TRAINER_ID = "trainer-demo"
MEMBER_ID = "user-jisu"


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _login(client, email: str) -> str:
    response = client.post(
        "/v1/auth/login",
        data={"username": email, "password": "oncare123"},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def test_trainer_removes_assignment_but_keeps_member(client, db_session):
    token = _login(client, "trainer@oncare.com")
    link = db_session.scalar(
        select(TrainerClient).where(
            TrainerClient.trainer_id == TRAINER_ID,
            TrainerClient.member_id == MEMBER_ID,
        )
    )
    assert link is not None
    original = {
        "id": link.id,
        "goal": link.goal,
        "active": link.active,
        "dormant": link.dormant,
        "sort_order": link.sort_order,
        "data_consent_at": link.data_consent_at,
    }
    link.active = True
    db_session.commit()
    try:
        response = client.delete(
            f"/v1/trainer/clients/{MEMBER_ID}", headers=_headers(token)
        )
        assert response.status_code == 204, response.text

        db_session.expire_all()
        saved = db_session.get(User, MEMBER_ID)
        detached = db_session.scalar(
            select(TrainerClient).where(TrainerClient.id == original["id"])
        )
        assert saved is not None
        assert detached is None
        roster = client.get("/v1/trainer/clients", headers=_headers(token)).json()
        assert MEMBER_ID not in {row["id"] for row in roster}
        repeated = client.delete(
            f"/v1/trainer/clients/{MEMBER_ID}", headers=_headers(token)
        )
        assert repeated.status_code == 404
    finally:
        db_session.expire_all()
        link = db_session.scalar(
            select(TrainerClient).where(
                TrainerClient.trainer_id == TRAINER_ID,
                TrainerClient.member_id == MEMBER_ID,
            )
        )
        if link is None:
            db_session.add(
                TrainerClient(
                    id=original["id"],
                    trainer_id=TRAINER_ID,
                    member_id=MEMBER_ID,
                    goal=original["goal"],
                    active=original["active"],
                    dormant=original["dormant"],
                    sort_order=original["sort_order"],
                    data_consent_at=original["data_consent_at"],
                )
            )
        else:
            link.active = original["active"]
        db_session.commit()


def test_another_trainer_cannot_remove_client(client, db_session):
    other_id = f"trainer-{uuid4().hex[:10]}"
    other = User(
        id=other_id,
        email=f"{other_id}@oncare.com",
        name="다른 트레이너",
        hashed_password="unused",
        role="trainer",
    )
    db_session.add(other)
    db_session.commit()
    try:
        response = client.delete(
            f"/v1/trainer/clients/{MEMBER_ID}",
            headers=_headers(create_access_token(other_id)),
        )
        assert response.status_code == 404
    finally:
        db_session.delete(other)
        db_session.commit()
