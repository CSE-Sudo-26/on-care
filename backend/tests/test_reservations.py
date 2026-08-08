from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import Mock, call
from uuid import uuid4

import pytest
from sqlalchemy.orm import Session

from app.models.models import (
    TrainerReservation,
    TrainerReservationSlot,
    TrainerSchedule,
    User,
)
from app.services import reservation_service, trainer_service


def test_reserve_flushes_schedule_before_reservation() -> None:
    """The schedule FK target must exist before PostgreSQL inserts a booking."""
    now = datetime.now(timezone.utc)
    slot = TrainerReservationSlot(
        id="slot-order-test",
        trainer_id="trainer-demo",
        starts_at=now + timedelta(days=1),
        capacity=1,
        remaining=1,
    )
    member = User(
        id="member-order-test",
        email="member-order-test@oncare.com",
        name="예약 순서 회원",
        role="member",
    )
    db = Mock(spec=Session)
    db.scalar.side_effect = [slot, "trainer-client-id", None]

    def set_database_defaults(instance) -> None:
        if isinstance(instance, TrainerReservation):
            instance.created_at = now

    db.refresh.side_effect = set_database_defaults

    result = reservation_service.reserve(db, member, slot.id, now=now)

    call_names = [entry[0] for entry in db.mock_calls]
    first_add = call_names.index("add")
    flush = call_names.index("flush")
    second_add = call_names.index("add", first_add + 1)
    commit = call_names.index("commit")
    assert first_add < flush < second_add < commit
    assert result.schedule_id.startswith("sched-")
    assert slot.remaining == 0


def test_reserved_schedule_is_blocked_from_regular_update_and_delete() -> None:
    schedule = TrainerSchedule(
        id="reserved-schedule-test",
        trainer_id="trainer-demo",
    )
    db = Mock(spec=Session)
    db.get.return_value = schedule
    db.scalar.return_value = "reservation-test"

    with pytest.raises(trainer_service.ScheduleConflict):
        trainer_service.update_session(
            db,
            "trainer-demo",
            schedule.id,
            {"time": "09:00"},
        )
    with pytest.raises(trainer_service.ScheduleConflict):
        trainer_service.delete_session(db, "trainer-demo", schedule.id)

    db.commit.assert_not_called()
    db.delete.assert_not_called()


def test_account_deletion_restores_seat_before_removing_booking() -> None:
    slot = TrainerReservationSlot(
        id="account-delete-slot",
        trainer_id="trainer-demo",
        capacity=2,
        remaining=1,
        starts_at=datetime.now(timezone.utc) + timedelta(days=1),
    )
    reservation = TrainerReservation(
        id="account-delete-reservation",
        member_id="account-delete-member",
        slot_id=slot.id,
        schedule_id="account-delete-schedule",
        status="booked",
    )
    schedule = TrainerSchedule(
        id=reservation.schedule_id,
        trainer_id="trainer-demo",
    )
    reservation_rows = Mock()
    reservation_rows.all.return_value = [reservation]
    slot_rows = Mock()
    slot_rows.all.return_value = [slot]
    db = Mock(spec=Session)
    db.scalars.side_effect = [reservation_rows, slot_rows]
    db.get.return_value = schedule

    reservation_service.cancel_member_reservations_for_account_deletion(
        db, reservation.member_id
    )

    assert slot.remaining == 2
    assert db.mock_calls.index(call.delete(reservation)) < db.mock_calls.index(
        call.flush()
    )
    assert db.mock_calls.index(call.flush()) < db.mock_calls.index(
        call.delete(schedule)
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


def test_reserved_schedule_cannot_be_updated_or_deleted_as_regular_schedule(
    client, db_session, created_slots
):
    trainer_token = _login(client, "trainer@oncare.com")
    member_token = _login(client, "jisu@oncare.com")
    slot = _create_slot(client, trainer_token, created_slots, capacity=1)
    booked = client.post(
        "/v1/reservations",
        headers=_headers(member_token),
        json={"slot_id": slot["id"]},
    )
    assert booked.status_code == 201, booked.text

    reservation_id = booked.json()["id"]
    schedule_id = booked.json()["schedule_id"]
    updated = client.put(
        f"/v1/trainer/schedule/{schedule_id}",
        headers=_headers(trainer_token),
        json={"time": "09:00"},
    )
    deleted = client.delete(
        f"/v1/trainer/schedule/{schedule_id}",
        headers=_headers(trainer_token),
    )

    assert updated.status_code == 409, updated.text
    assert deleted.status_code == 409, deleted.text
    db_session.expire_all()
    assert db_session.get(TrainerReservation, reservation_id) is not None
    assert db_session.get(TrainerSchedule, schedule_id) is not None
    persisted_slot = db_session.get(TrainerReservationSlot, slot["id"])
    assert persisted_slot is not None
    assert persisted_slot.remaining == 0


def test_member_account_deletion_restores_slot_and_removes_schedule(
    client, db_session
):
    suffix = uuid4().hex[:10]
    email = f"reservation-delete-{suffix}@oncare.com"
    password = "oncare123"
    registered = client.post(
        "/v1/auth/register",
        json={"email": email, "password": password, "name": "탈퇴 예약 회원"},
    )
    assert registered.status_code == 201, registered.text
    member_id = registered.json()["id"]
    member_token = _login(client, email)

    slot = TrainerReservationSlot(
        id=f"slot-delete-{suffix}",
        trainer_id="trainer-demo",
        starts_at=datetime.now(timezone.utc) + timedelta(days=2),
        capacity=1,
        remaining=0,
    )
    schedule = TrainerSchedule(
        id=f"sched-delete-{suffix}",
        trainer_id="trainer-demo",
        member_id=member_id,
        date=(datetime.now(timezone.utc) + timedelta(days=2)).date().isoformat(),
        time="10:00",
        client_name="탈퇴 예약 회원",
        type="1:1 PT",
        duration_minutes=60,
        status="예정",
        note="회원 직접 예약",
        program_json="[]",
        sort_order=0,
    )
    reservation = TrainerReservation(
        id=f"res-delete-{suffix}",
        member_id=member_id,
        slot_id=slot.id,
        schedule_id=schedule.id,
        status="booked",
    )
    db_session.add_all([slot, schedule])
    db_session.flush()
    db_session.add(reservation)
    db_session.commit()
    reservation_id = reservation.id
    schedule_id = schedule.id
    slot_id = slot.id

    deleted = client.delete("/v1/users/me", headers=_headers(member_token))

    assert deleted.status_code == 200, deleted.text
    db_session.expire_all()
    assert db_session.get(TrainerReservation, reservation_id) is None
    assert db_session.get(TrainerSchedule, schedule_id) is None
    persisted_slot = db_session.get(TrainerReservationSlot, slot_id)
    assert persisted_slot is not None
    assert persisted_slot.remaining == 1
    db_session.delete(persisted_slot)
    db_session.commit()


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
