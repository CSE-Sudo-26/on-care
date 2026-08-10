from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.core import clock
from app.models.models import ConsultationRequest, Place, TrainerProfile, User
from app.schemas.consultation_api import ConsultationOut

TEST_EMAIL_PREFIX = "consult-test-"
TEST_PLACE_PREFIX = "consult-place-"


@pytest.fixture(autouse=True)
def _cleanup_consultation_data(db_session):
    yield
    db_session.rollback()
    user_ids = [
        row[0]
        for row in db_session.query(User.id)
        .filter(User.email.like(f"{TEST_EMAIL_PREFIX}%"))
        .all()
    ]
    if user_ids:
        db_session.query(ConsultationRequest).filter(
            (ConsultationRequest.member_id.in_(user_ids))
            | (ConsultationRequest.trainer_id.in_(user_ids))
        ).delete(synchronize_session=False)
        db_session.query(TrainerProfile).filter(
            TrainerProfile.trainer_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db_session.query(User).filter(User.id.in_(user_ids)).delete(
            synchronize_session=False
        )
    db_session.query(ConsultationRequest).filter(
        ConsultationRequest.gym_id.like(f"{TEST_PLACE_PREFIX}%")
    ).delete(synchronize_session=False)
    db_session.query(Place).filter(
        Place.id.like(f"{TEST_PLACE_PREFIX}%")
    ).delete(synchronize_session=False)
    db_session.commit()


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _register_member(client) -> tuple[str, str]:
    suffix = uuid4().hex[:10]
    email = f"{TEST_EMAIL_PREFIX}{suffix}@oncare.com"
    response = client.post(
        "/v1/auth/register",
        json={"email": email, "password": "pw!", "name": "상담 테스트 회원"},
    )
    assert response.status_code == 201, response.text
    token_response = client.post(
        "/v1/auth/login",
        data={"username": email, "password": "pw!"},
    )
    assert token_response.status_code == 200, token_response.text
    return response.json()["id"], token_response.json()["access_token"]


def _create_place(db_session, *, category: str = "fitness") -> Place:
    suffix = uuid4().hex[:10]
    place = Place(
        id=f"{TEST_PLACE_PREFIX}{suffix}",
        name="상담 테스트 헬스장",
        category=category,
        address="서울",
    )
    db_session.add(place)
    db_session.commit()
    return place


def _create_trainer(
    db_session,
    *,
    role: str = "trainer",
    active: bool = True,
    with_profile: bool = True,
    with_gym: bool = True,
    gym_category: str = "fitness",
) -> User:
    suffix = uuid4().hex[:10]
    gym = (
        _create_place(db_session, category=gym_category)
        if with_profile and with_gym
        else None
    )
    trainer = User(
        id=f"consult-trainer-{suffix}",
        email=f"{TEST_EMAIL_PREFIX}trainer-{suffix}@oncare.com",
        name="상담 테스트 트레이너",
        role=role,
        is_active=active,
    )
    db_session.add(trainer)
    db_session.flush()
    if with_profile:
        db_session.add(
            TrainerProfile(
                trainer_id=trainer.id,
                gym_id=gym.id if gym is not None else None,
            )
        )
    db_session.commit()
    return trainer


def _payload(
    *,
    target_type: str = "gym",
    gym_id: str | None = None,
    trainer_id: str | None = None,
) -> dict:
    return {
        "target_type": target_type,
        "gym_id": gym_id,
        "trainer_id": trainer_id,
        "exercise_goal": "health",
        "health_purpose_type": "general",
        "health_purpose_detail": "  건강 습관 개선  ",
        "preferred_date": (clock.today() + timedelta(days=1)).isoformat(),
        "preferred_time_slot": "afternoon",
        "message": "  상담을 받고 싶습니다.  ",
    }


def test_create_gym_consultation_sets_server_fields(client, db_session):
    member_id, token = _register_member(client)
    gym = _create_place(db_session)
    payload = _payload(gym_id=gym.id)
    payload["preferred_date"] = clock.today().isoformat()

    response = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=payload,
    )

    assert response.status_code == 201, response.text
    body = response.json()
    assert body["id"].startswith("consult-")
    assert body["member_id"] == member_id
    assert body["target_type"] == "gym"
    assert body["gym_id"] == gym.id
    assert body["trainer_id"] is None
    assert body["status"] == "pending"
    assert body["health_purpose_detail"] == "건강 습관 개선"
    assert body["message"] == "상담을 받고 싶습니다."
    assert body["created_at"]
    assert body["updated_at"]


def test_create_trainer_consultation(client, db_session):
    _, token = _register_member(client)
    trainer = _create_trainer(db_session)

    response = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=_payload(target_type="trainer", trainer_id=trainer.id),
    )

    assert response.status_code == 201, response.text
    assert response.json()["trainer_id"] == trainer.id
    assert response.json()["gym_id"] is None


@pytest.mark.parametrize("status", ["pending", "accepted", "rejected"])
def test_client_cannot_set_consultation_status(client, db_session, status):
    _, token = _register_member(client)
    gym = _create_place(db_session)
    payload = _payload(gym_id=gym.id)
    payload["status"] = status

    response = client.post(
        "/v1/consultations", headers=_auth(token), json=payload
    )

    assert response.status_code == 422


def test_consultation_out_validates_orm_instance():
    now = datetime.now(timezone.utc)
    consultation = ConsultationRequest(
        id="consult-orm-validation",
        member_id="user-orm-validation",
        target_type="gym",
        gym_id="place-orm-validation",
        trainer_id=None,
        exercise_goal="health",
        health_purpose_type="general",
        health_purpose_detail=None,
        preferred_date=clock.today().isoformat(),
        preferred_time_slot="flexible",
        message=None,
        status="pending",
        created_at=now,
        updated_at=now,
    )

    response = ConsultationOut.model_validate(consultation)

    assert response.id == consultation.id
    assert response.preferred_date == clock.today()


def test_past_preferred_date_is_rejected(client, db_session):
    _, token = _register_member(client)
    gym = _create_place(db_session)
    payload = _payload(gym_id=gym.id)
    payload["preferred_date"] = (clock.today() - timedelta(days=1)).isoformat()

    response = client.post(
        "/v1/consultations", headers=_auth(token), json=payload
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("target_type", "hospital"),
        ("exercise_goal", "bulk"),
        ("health_purpose_type", "sleep"),
        ("preferred_time_slot", "night"),
    ],
)
def test_invalid_limited_value_is_rejected(
    client, db_session, field: str, value: str
):
    _, token = _register_member(client)
    gym = _create_place(db_session)
    payload = _payload(gym_id=gym.id)
    payload[field] = value

    response = client.post(
        "/v1/consultations", headers=_auth(token), json=payload
    )

    assert response.status_code == 422


@pytest.mark.parametrize("detail", [None, "", "   "])
def test_other_health_purpose_requires_detail(client, db_session, detail):
    _, token = _register_member(client)
    gym = _create_place(db_session)
    payload = _payload(gym_id=gym.id)
    payload["health_purpose_type"] = "other"
    payload["health_purpose_detail"] = detail

    response = client.post(
        "/v1/consultations", headers=_auth(token), json=payload
    )

    assert response.status_code == 422


def test_blank_optional_text_is_normalized_to_null(client, db_session):
    _, token = _register_member(client)
    gym = _create_place(db_session)
    payload = _payload(gym_id=gym.id)
    payload["health_purpose_detail"] = " "
    payload["message"] = " "

    response = client.post(
        "/v1/consultations", headers=_auth(token), json=payload
    )

    assert response.status_code == 201, response.text
    assert response.json()["health_purpose_detail"] is None
    assert response.json()["message"] is None


def test_message_length_is_limited(client, db_session):
    _, token = _register_member(client)
    gym = _create_place(db_session)
    payload = _payload(gym_id=gym.id)
    payload["message"] = "a" * 2001

    response = client.post(
        "/v1/consultations", headers=_auth(token), json=payload
    )

    assert response.status_code == 422


@pytest.mark.parametrize("category", [None, "medical"])
def test_missing_or_non_fitness_gym_is_rejected(client, db_session, category):
    _, token = _register_member(client)
    gym_id = "consult-place-missing"
    if category is not None:
        gym_id = _create_place(db_session, category=category).id

    response = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=_payload(gym_id=gym_id),
    )

    assert response.status_code == 404


@pytest.mark.parametrize(
    "trainer_options",
    [
        None,
        {"role": "member"},
        {"active": False},
        {"with_profile": False},
    ],
)
def test_invalid_trainer_target_is_rejected(
    client, db_session, trainer_options
):
    _, token = _register_member(client)
    trainer_id = "consult-trainer-missing"
    if trainer_options is not None:
        trainer_id = _create_trainer(db_session, **trainer_options).id

    response = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=_payload(target_type="trainer", trainer_id=trainer_id),
    )

    assert response.status_code == 404


def test_trainer_without_gym_is_rejected(client, db_session):
    _, token = _register_member(client)
    trainer = _create_trainer(db_session, with_gym=False)

    response = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=_payload(target_type="trainer", trainer_id=trainer.id),
    )

    assert response.status_code == 404


def test_trainer_at_non_fitness_place_is_rejected(client, db_session):
    _, token = _register_member(client)
    trainer = _create_trainer(db_session, gym_category="medical")

    response = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=_payload(target_type="trainer", trainer_id=trainer.id),
    )

    assert response.status_code == 404


@pytest.mark.parametrize(
    "payload_changes",
    [
        {"target_type": "trainer", "gym_id": None, "trainer_id": None},
        {"target_type": "gym", "trainer_id": "trainer-any"},
        {"target_type": "gym", "gym_id": None},
    ],
)
def test_target_id_contract_is_validated(
    client, db_session, payload_changes
):
    _, token = _register_member(client)
    gym = _create_place(db_session)
    payload = _payload(gym_id=gym.id)
    payload.update(payload_changes)

    response = client.post(
        "/v1/consultations", headers=_auth(token), json=payload
    )

    assert response.status_code == 422


@pytest.mark.parametrize("target_type", ["gym", "trainer"])
def test_duplicate_pending_consultation_is_rejected(
    client, db_session, target_type
):
    _, token = _register_member(client)
    if target_type == "gym":
        target = _create_place(db_session)
        payload = _payload(gym_id=target.id)
    else:
        target = _create_trainer(db_session)
        payload = _payload(target_type="trainer", trainer_id=target.id)

    first = client.post(
        "/v1/consultations", headers=_auth(token), json=payload
    )
    second = client.post(
        "/v1/consultations", headers=_auth(token), json=payload
    )

    assert first.status_code == 201
    assert second.status_code == 409


@pytest.mark.parametrize("target_type", ["gym", "trainer"])
def test_partial_unique_index_allows_completed_but_rejects_second_pending(
    client, db_session, target_type
):
    from sqlalchemy.exc import IntegrityError

    member_id, _ = _register_member(client)
    gym_id = trainer_id = None
    if target_type == "gym":
        gym_id = _create_place(db_session).id
    else:
        trainer_id = _create_trainer(db_session).id
    common = {
        "member_id": member_id,
        "target_type": target_type,
        "gym_id": gym_id,
        "trainer_id": trainer_id,
        "exercise_goal": "health",
        "health_purpose_type": "general",
        "preferred_date": clock.today().isoformat(),
        "preferred_time_slot": "flexible",
    }

    db_session.add(
        ConsultationRequest(
            id=f"consult-{uuid4().hex[:12]}",
            status="accepted",
            **common,
        )
    )
    db_session.commit()
    db_session.add(
        ConsultationRequest(
            id=f"consult-{uuid4().hex[:12]}",
            status="pending",
            **common,
        )
    )
    db_session.commit()

    db_session.add(
        ConsultationRequest(
            id=f"consult-{uuid4().hex[:12]}",
            status="pending",
            **common,
        )
    )
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_gym_and_trainer_pending_requests_are_independent(client, db_session):
    _, token = _register_member(client)
    gym = _create_place(db_session)
    trainer = _create_trainer(db_session)

    gym_response = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=_payload(gym_id=gym.id),
    )
    trainer_response = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=_payload(target_type="trainer", trainer_id=trainer.id),
    )

    assert gym_response.status_code == 201
    assert trainer_response.status_code == 201


def test_list_returns_only_current_member_in_latest_order(client, db_session):
    first_member_id, first_token = _register_member(client)
    _, second_token = _register_member(client)
    first_gym = _create_place(db_session)
    second_gym = _create_place(db_session)

    first = client.post(
        "/v1/consultations",
        headers=_auth(first_token),
        json=_payload(gym_id=first_gym.id),
    )
    assert first.status_code == 201
    first_row = db_session.get(ConsultationRequest, first.json()["id"])
    first_row.created_at = datetime.now(timezone.utc) - timedelta(days=1)
    db_session.commit()

    second = client.post(
        "/v1/consultations",
        headers=_auth(first_token),
        json=_payload(gym_id=second_gym.id),
    )
    assert second.status_code == 201
    other = client.post(
        "/v1/consultations",
        headers=_auth(second_token),
        json=_payload(gym_id=first_gym.id),
    )
    assert other.status_code == 201

    response = client.get(
        "/v1/consultations/me", headers=_auth(first_token)
    )

    assert response.status_code == 200
    body = response.json()
    assert [row["id"] for row in body] == [
        second.json()["id"],
        first.json()["id"],
    ]
    assert {row["member_id"] for row in body} == {first_member_id}


def test_get_returns_own_consultation(client, db_session):
    _, token = _register_member(client)
    gym = _create_place(db_session)
    created = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=_payload(gym_id=gym.id),
    )

    response = client.get(
        f"/v1/consultations/{created.json()['id']}",
        headers=_auth(token),
    )

    assert response.status_code == 200
    assert response.json()["id"] == created.json()["id"]


def test_other_members_consultation_is_hidden(client, db_session):
    _, owner_token = _register_member(client)
    _, other_token = _register_member(client)
    gym = _create_place(db_session)
    created = client.post(
        "/v1/consultations",
        headers=_auth(owner_token),
        json=_payload(gym_id=gym.id),
    )

    response = client.get(
        f"/v1/consultations/{created.json()['id']}",
        headers=_auth(other_token),
    )

    assert response.status_code == 404


def test_missing_consultation_returns_404(client):
    _, token = _register_member(client)

    response = client.get(
        "/v1/consultations/consult-missing",
        headers=_auth(token),
    )

    assert response.status_code == 404


@pytest.mark.parametrize(
    ("method", "path"),
    [
        ("post", "/v1/consultations"),
        ("get", "/v1/consultations/me"),
        ("get", "/v1/consultations/consult-any"),
    ],
)
def test_consultation_endpoints_require_authentication(
    client, method: str, path: str
):
    kwargs = {"json": _payload(gym_id="consult-place-any")} if method == "post" else {}

    response = getattr(client, method)(path, **kwargs)

    assert response.status_code == 401


def test_trainer_cannot_access_consultation_endpoints(client):
    token_response = client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    )
    assert token_response.status_code == 200
    headers = _auth(token_response.json()["access_token"])

    assert client.get("/v1/consultations/me", headers=headers).status_code == 403


def test_consultation_out_carries_target_names(client, db_session):
    """목록 카드가 이름을 렌더한다 — id 만 주면 앱이 대상마다 상세를 다시 조회해야
    하고, 대상이 지워지면 이름을 영영 못 만든다(#327)."""
    token = _register_member(client)[1]
    created = client.post(
        "/v1/consultations",
        headers=_auth(token),
        json=_payload(gym_id="gym-oncare-sinchon"),
    )
    assert created.status_code == 201, created.text
    assert created.json()["gym_name"] == "온케어짐 신촌점"

    listed = client.get("/v1/consultations/me", headers=_auth(token)).json()
    assert listed[0]["gym_name"] == "온케어짐 신촌점"
    # 헬스장 상담이므로 트레이너 이름은 없다.
    assert listed[0]["trainer_name"] is None

    detail = client.get(
        f"/v1/consultations/{created.json()['id']}", headers=_auth(token)
    ).json()
    assert detail["gym_name"] == "온케어짐 신촌점"
