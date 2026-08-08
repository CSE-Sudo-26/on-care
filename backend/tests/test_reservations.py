from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.models.models import (
    TrainerReservation,
    TrainerReservationSlot,
    TrainerSchedule,
)


def _login(client, email: str) -> str:
    response = client.post(
        "/v1/auth/login",
        data={"username": email, "password": "oncare123"},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def created_slots(db_session):
    ids: list[str] = []
    yield ids
    db_session.rollback()
    if not ids:
        return
    reservations = (
        db_session.query(TrainerReservation)
        .filter(TrainerReservation.slot_id.in_(ids))
        .all()
    )
    schedule_ids = [row.schedule_id for row in reservations]
    db_session.query(TrainerReservation).filter(
        TrainerReservation.slot_id.in_(ids)
    ).delete(synchronize_session=False)
    if schedule_ids:
        db_session.query(TrainerSchedule).filter(
            TrainerSchedule.id.in_(schedule_ids)
        ).delete(synchronize_session=False)
    db_session.query(TrainerReservationSlot).filter(
        TrainerReservationSlot.id.in_(ids)
    ).delete(synchronize_session=False)
    db_session.commit()


def _create_slot(client, trainer_token: str, created_slots, *, capacity: int = 2):
    starts_at = datetime.now(timezone.utc) + timedelta(days=2)
    response = client.post(
        "/v1/trainer/reservation-slots",
        headers=_headers(trainer_token),
        json={"starts_at": starts_at.isoformat(), "capacity": capacity},
    )
    assert response.status_code == 201, response.text
    created_slots.append(response.json()["id"])
    return response.json()


def test_trainer_creates_and_member_lists_slots(client, created_slots):
    trainer_token = _login(client, "trainer@oncare.com")
    member_token = _login(client, "jisu@oncare.com")
    slot = _create_slot(client, trainer_token, created_slots)

    response = client.get(
        "/v1/trainers/trainer-demo/slots", headers=_headers(member_token)
    )

    assert response.status_code == 200, response.text
    selected = next(row for row in response.json() if row["id"] == slot["id"])
    assert selected["capacity"] == 2
    assert selected["remaining"] == 2


def test_reservation_persists_and_appears_in_trainer_schedule(
    client, db_session, created_slots
):
    trainer_token = _login(client, "trainer@oncare.com")
    member_token = _login(client, "jisu@oncare.com")
    slot = _create_slot(client, trainer_token, created_slots)

    booked = client.post(
        "/v1/reservations",
        headers=_headers(member_token),
        json={"slot_id": slot["id"]},
    )

    assert booked.status_code == 201, booked.text
    db_session.expire_all()
    reservation = db_session.get(TrainerReservation, booked.json()["id"])
    assert reservation is not None
    assert reservation.member_id == "user-jisu"
    persisted_slot = db_session.get(TrainerReservationSlot, slot["id"])
    assert persisted_slot.remaining == 1
    schedule = db_session.get(TrainerSchedule, booked.json()["schedule_id"])
    assert schedule is not None
    assert schedule.trainer_id == "trainer-demo"
    assert schedule.member_id == "user-jisu"
    assert schedule.client_name == "이지수"

    timeline = client.get(
        "/v1/trainer/schedule",
        headers=_headers(trainer_token),
        params={"date": schedule.date},
    )
    assert timeline.status_code == 200
    assert any(row["id"] == schedule.id for row in timeline.json())


def test_duplicate_and_full_slot_return_409(client, created_slots):
    trainer_token = _login(client, "trainer@oncare.com")
    member_token = _login(client, "jisu@oncare.com")
    slot = _create_slot(client, trainer_token, created_slots, capacity=1)

    first = client.post(
        "/v1/reservations",
        headers=_headers(member_token),
        json={"slot_id": slot["id"]},
    )
    second = client.post(
        "/v1/reservations",
        headers=_headers(member_token),
        json={"slot_id": slot["id"]},
    )

    assert first.status_code == 201
    assert second.status_code == 409


def test_trainer_can_change_capacity_and_close_slot(client, created_slots):
    trainer_token = _login(client, "trainer@oncare.com")
    member_token = _login(client, "jisu@oncare.com")
    slot = _create_slot(client, trainer_token, created_slots, capacity=3)

    updated = client.put(
        f"/v1/trainer/reservation-slots/{slot['id']}",
        headers=_headers(trainer_token),
        json={"capacity": 4},
    )
    assert updated.status_code == 200
    assert updated.json()["remaining"] == 4

    closed = client.delete(
        f"/v1/trainer/reservation-slots/{slot['id']}",
        headers=_headers(trainer_token),
    )
    assert closed.status_code == 200
    assert closed.json()["is_closed"] is True
    assert closed.json()["remaining"] == 0

    refused = client.post(
        "/v1/reservations",
        headers=_headers(member_token),
        json={"slot_id": slot["id"]},
    )
    assert refused.status_code == 409


def test_past_slots_are_not_returned(client, db_session, created_slots):
    slot = TrainerReservationSlot(
        id="slot-past-test",
        trainer_id="trainer-demo",
        starts_at=datetime.now(timezone.utc) - timedelta(hours=1),
        capacity=1,
        remaining=1,
    )
    db_session.add(slot)
    db_session.commit()
    created_slots.append(slot.id)
    member_token = _login(client, "jisu@oncare.com")

    response = client.get(
        "/v1/trainers/trainer-demo/slots", headers=_headers(member_token)
    )

    assert response.status_code == 200
    assert slot.id not in {row["id"] for row in response.json()}


def test_member_cannot_book_an_unassigned_trainer_slot(
    client, db_session, created_slots
):
    from app.core.security import hash_password
    from app.models.models import TrainerProfile, User

    trainer = User(
        id="reservation-other-trainer",
        email="reservation-other@oncare.com",
        name="다른 트레이너",
        hashed_password=hash_password("oncare123"),
        role="trainer",
        is_active=True,
    )
    db_session.add(trainer)
    db_session.flush()
    db_session.add(TrainerProfile(trainer_id=trainer.id))
    db_session.commit()
    try:
        token = _login(client, trainer.email)
        member_token = _login(client, "jisu@oncare.com")
        slot = _create_slot(client, token, created_slots)

        response = client.post(
            "/v1/reservations",
            headers=_headers(member_token),
            json={"slot_id": slot["id"]},
        )

        assert response.status_code == 409
    finally:
        db_session.rollback()
        db_session.query(TrainerProfile).filter(
            TrainerProfile.trainer_id == trainer.id
        ).delete(synchronize_session=False)
        db_session.query(User).filter(User.id == trainer.id).delete(
            synchronize_session=False
        )
        db_session.commit()
