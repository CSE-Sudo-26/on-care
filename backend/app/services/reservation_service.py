from __future__ import annotations

import uuid
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.models import (
    TrainerClient,
    TrainerReservation,
    TrainerReservationSlot,
    TrainerSchedule,
    User,
)
from app.schemas.reservation_api import ReservationOut, TrainerSlotOut

SEOUL = ZoneInfo("Asia/Seoul")


class SlotNotFound(Exception):
    pass


class SlotUnavailable(Exception):
    pass


class DuplicateReservation(Exception):
    pass


class CapacityConflict(Exception):
    pass


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)


def _slot_out(slot: TrainerReservationSlot) -> TrainerSlotOut:
    return TrainerSlotOut(
        id=slot.id,
        trainer_id=slot.trainer_id,
        starts_at=_aware(slot.starts_at),
        capacity=slot.capacity,
        remaining=0 if slot.is_closed else slot.remaining,
        is_closed=slot.is_closed,
    )


def list_member_slots(
    db: Session, trainer_id: str, *, now: datetime | None = None
) -> list[TrainerSlotOut]:
    current = now or datetime.now(timezone.utc)
    rows = db.scalars(
        select(TrainerReservationSlot)
        .where(
            TrainerReservationSlot.trainer_id == trainer_id,
            TrainerReservationSlot.starts_at > current,
        )
        .order_by(TrainerReservationSlot.starts_at)
    ).all()
    return [_slot_out(row) for row in rows]


def list_trainer_slots(
    db: Session, trainer_id: str, *, include_past: bool = False
) -> list[TrainerSlotOut]:
    query = select(TrainerReservationSlot).where(
        TrainerReservationSlot.trainer_id == trainer_id
    )
    if not include_past:
        query = query.where(
            TrainerReservationSlot.starts_at > datetime.now(timezone.utc)
        )
    rows = db.scalars(query.order_by(TrainerReservationSlot.starts_at)).all()
    return [_slot_out(row) for row in rows]


def create_slot(
    db: Session, trainer_id: str, starts_at: datetime, capacity: int
) -> TrainerSlotOut:
    if _aware(starts_at) <= datetime.now(timezone.utc):
        raise SlotUnavailable("지난 시간에는 예약 슬롯을 만들 수 없습니다.")
    slot = TrainerReservationSlot(
        id=f"slot-{uuid.uuid4().hex[:12]}",
        trainer_id=trainer_id,
        starts_at=starts_at,
        capacity=capacity,
        remaining=capacity,
    )
    db.add(slot)
    db.commit()
    db.refresh(slot)
    return _slot_out(slot)


def update_slot(
    db: Session,
    trainer_id: str,
    slot_id: str,
    fields: dict,
) -> TrainerSlotOut:
    slot = db.scalar(
        select(TrainerReservationSlot)
        .where(
            TrainerReservationSlot.id == slot_id,
            TrainerReservationSlot.trainer_id == trainer_id,
        )
        .with_for_update()
    )
    if slot is None:
        raise SlotNotFound("예약 슬롯을 찾을 수 없습니다.")

    booked = (
        db.scalar(
            select(func.count())
            .select_from(TrainerReservation)
            .where(
                TrainerReservation.slot_id == slot.id,
                TrainerReservation.status == "booked",
            )
        )
        or 0
    )
    if "capacity" in fields:
        capacity = fields["capacity"]
        if capacity < booked:
            raise CapacityConflict("이미 예약된 인원보다 정원을 줄일 수 없습니다.")
        slot.capacity = capacity
        slot.remaining = capacity - booked
    if "starts_at" in fields:
        starts_at = fields["starts_at"]
        if _aware(starts_at) <= datetime.now(timezone.utc):
            raise SlotUnavailable("지난 시간으로 슬롯을 변경할 수 없습니다.")
        slot.starts_at = starts_at
        local = _aware(starts_at).astimezone(SEOUL)
        schedules = db.scalars(
            select(TrainerSchedule)
            .join(
                TrainerReservation, TrainerReservation.schedule_id == TrainerSchedule.id
            )
            .where(
                TrainerReservation.slot_id == slot.id,
                TrainerReservation.status == "booked",
            )
        ).all()
        for schedule in schedules:
            schedule.date = local.date().isoformat()
            schedule.time = local.strftime("%H:%M")
    if "is_closed" in fields:
        slot.is_closed = fields["is_closed"]
    db.commit()
    db.refresh(slot)
    return _slot_out(slot)


def close_slot(db: Session, trainer_id: str, slot_id: str) -> TrainerSlotOut:
    return update_slot(db, trainer_id, slot_id, {"is_closed": True})


def reserve(
    db: Session, member: User, slot_id: str, *, now: datetime | None = None
) -> ReservationOut:
    current = now or datetime.now(timezone.utc)
    slot = db.scalar(
        select(TrainerReservationSlot)
        .where(TrainerReservationSlot.id == slot_id)
        .with_for_update()
    )
    if slot is None:
        raise SlotNotFound("예약 슬롯을 찾을 수 없습니다.")
    if slot.is_closed or slot.remaining <= 0 or _aware(slot.starts_at) <= current:
        raise SlotUnavailable("예약할 수 없는 슬롯입니다.")

    assigned = db.scalar(
        select(TrainerClient.id).where(
            TrainerClient.trainer_id == slot.trainer_id,
            TrainerClient.member_id == member.id,
            TrainerClient.active.is_(True),
        )
    )
    if assigned is None:
        raise SlotUnavailable("담당 트레이너의 슬롯만 예약할 수 있습니다.")
    duplicate = db.scalar(
        select(TrainerReservation.id).where(
            TrainerReservation.member_id == member.id,
            TrainerReservation.slot_id == slot.id,
        )
    )
    if duplicate is not None:
        raise DuplicateReservation("이미 예약한 슬롯입니다.")

    reservation_id = f"res-{uuid.uuid4().hex[:12]}"
    schedule_id = f"sched-{uuid.uuid4().hex[:12]}"
    local = _aware(slot.starts_at).astimezone(SEOUL)
    schedule = TrainerSchedule(
        id=schedule_id,
        trainer_id=slot.trainer_id,
        member_id=member.id,
        date=local.date().isoformat(),
        time=local.strftime("%H:%M"),
        client_name=member.name,
        type="1:1 PT",
        duration_minutes=60,
        status="예정",
        note="회원 앱 예약",
        program_json="[]",
        sort_order=0,
    )
    reservation = TrainerReservation(
        id=reservation_id,
        member_id=member.id,
        slot_id=slot.id,
        schedule_id=schedule_id,
        status="booked",
    )
    slot.remaining -= 1
    # There is intentionally no ORM relationship between these persistence
    # models. Without an explicit flush SQLAlchemy is free to INSERT the
    # reservation before the schedule, which violates the schedule_id FK on
    # PostgreSQL even though both objects were added before commit (#492).
    db.add(schedule)
    try:
        db.flush()
        db.add(reservation)
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        constraint = getattr(getattr(exc.orig, "diag", None), "constraint_name", None)
        if constraint == "uq_reservation_member_slot":
            raise DuplicateReservation("이미 예약한 슬롯입니다.") from exc
        # Do not turn an unexpected schema/programming error into a misleading
        # 409. Let the global error handler report it as a server failure.
        raise
    db.refresh(reservation)
    return ReservationOut(
        id=reservation.id,
        slot_id=reservation.slot_id,
        schedule_id=reservation.schedule_id,
        status=reservation.status,
        created_at=_aware(reservation.created_at),
    )
