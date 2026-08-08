from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps import RequireMember, RequireTrainer
from app.db.session import get_db
from app.schemas.reservation_api import (
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
