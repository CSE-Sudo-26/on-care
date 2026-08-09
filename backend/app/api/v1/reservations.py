from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps import RequireMember, RequireTrainer
from app.db.session import get_db
from app.schemas.reservation_api import (
    MyReservationOut,
    ReservationCreate,
    ReservationOut,
    TrainerSlotCreate,
    TrainerSlotOut,
    TrainerSlotUpdate,
)
from app.services import reservation_service

router = APIRouter(tags=["reservations"])

ReservationError = (
    reservation_service.SlotNotFound,
    reservation_service.SlotUnavailable,
    reservation_service.DuplicateReservation,
    reservation_service.CapacityConflict,
)


def _slot_error(exc: Exception) -> HTTPException:
    if isinstance(exc, reservation_service.SlotNotFound):
        return HTTPException(status_code=404, detail=str(exc))
    if isinstance(
        exc,
        (
            reservation_service.SlotUnavailable,
            reservation_service.DuplicateReservation,
            reservation_service.CapacityConflict,
        ),
    ):
        return HTTPException(status_code=409, detail=str(exc))
    raise exc


@router.get("/trainers/{trainer_id}/slots", response_model=list[TrainerSlotOut])
def member_trainer_slots(
    trainer_id: str,
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> list[TrainerSlotOut]:
    return reservation_service.list_member_slots(db, trainer_id)


@router.post("/reservations", response_model=ReservationOut, status_code=201)
def create_reservation(
    payload: ReservationCreate,
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> ReservationOut:
    try:
        return reservation_service.reserve(db, member, payload.slot_id)
    except ReservationError as exc:
        raise _slot_error(exc) from exc


@router.get("/reservations/me", response_model=list[MyReservationOut])
def my_reservations(
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> list[MyReservationOut]:
    """회원의 예약 목록. 앱이 '내가 잡은 자리'를 표시하고 취소를 걸 자리다. (#502)

    `/reservations/{id}` 보다 먼저 선언해야 "me" 가 id 로 잡히지 않는다.
    """
    return reservation_service.list_member_reservations(db, member.id)


@router.delete("/reservations/{reservation_id}", status_code=200)
def cancel_reservation(
    reservation_id: str,
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """회원이 자기 예약을 취소한다. 좌석과 트레이너 일정이 함께 돌아간다. (#502)"""
    try:
        reservation_service.cancel(db, member.id, reservation_id)
    except reservation_service.ReservationNotFound as exc:
        # 남의 예약도 여기로 온다 — 존재조차 드러내지 않는다.
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except reservation_service.ReservationTooLate as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return {"status": "cancelled"}


@router.get("/trainer/reservation-slots", response_model=list[TrainerSlotOut])
def trainer_slots(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
    include_past: bool = Query(False),
) -> list[TrainerSlotOut]:
    return reservation_service.list_trainer_slots(
        db, trainer.id, include_past=include_past
    )


@router.post(
    "/trainer/reservation-slots", response_model=TrainerSlotOut, status_code=201
)
def create_trainer_slot(
    payload: TrainerSlotCreate,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerSlotOut:
    try:
        return reservation_service.create_slot(
            db, trainer.id, payload.starts_at, payload.capacity
        )
    except ReservationError as exc:
        raise _slot_error(exc) from exc


@router.put("/trainer/reservation-slots/{slot_id}", response_model=TrainerSlotOut)
def update_trainer_slot(
    slot_id: str,
    payload: TrainerSlotUpdate,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerSlotOut:
    try:
        return reservation_service.update_slot(
            db,
            trainer.id,
            slot_id,
            payload.model_dump(exclude_unset=True),
        )
    except ReservationError as exc:
        raise _slot_error(exc) from exc


@router.delete("/trainer/reservation-slots/{slot_id}", response_model=TrainerSlotOut)
def close_trainer_slot(
    slot_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerSlotOut:
    try:
        return reservation_service.close_slot(db, trainer.id, slot_id)
    except ReservationError as exc:
        raise _slot_error(exc) from exc
