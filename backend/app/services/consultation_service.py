from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.models import ConsultationRequest, Place, TrainerProfile, User
from app.schemas.consultation_api import ConsultationCreate


class InvalidConsultationRequest(Exception):
    pass


class ConsultationTargetNotFound(Exception):
    pass


class DuplicatePendingConsultation(Exception):
    pass


def _pending_query(member_id: str, payload: ConsultationCreate):
    query = select(ConsultationRequest).where(
        ConsultationRequest.member_id == member_id,
        ConsultationRequest.target_type == payload.target_type,
        ConsultationRequest.status == "pending",
    )
    if payload.target_type == "gym":
        return query.where(ConsultationRequest.gym_id == payload.gym_id)
    return query.where(ConsultationRequest.trainer_id == payload.trainer_id)


def _validate_target(db: Session, payload: ConsultationCreate) -> None:
    if payload.target_type == "gym":
        gym = db.scalar(
            select(Place).where(
                Place.id == payload.gym_id,
                Place.category == "fitness",
            )
        )
        if gym is None:
            raise ConsultationTargetNotFound(
                "상담 가능한 헬스장을 찾을 수 없습니다."
            )
        return

    trainer = db.scalar(
        select(User)
        .join(TrainerProfile, TrainerProfile.trainer_id == User.id)
        .where(
            User.id == payload.trainer_id,
            User.role == "trainer",
            User.is_active.is_(True),
        )
    )
    if trainer is None:
        raise ConsultationTargetNotFound(
            "상담 가능한 트레이너를 찾을 수 없습니다."
        )


def create_consultation(
    db: Session, member_id: str, payload: ConsultationCreate
) -> ConsultationRequest:
    if payload.preferred_date < date.today():
        raise InvalidConsultationRequest("상담 희망일은 오늘 이후여야 합니다.")

    _validate_target(db, payload)
    if db.scalar(_pending_query(member_id, payload)) is not None:
        raise DuplicatePendingConsultation("이미 대기 중인 상담 요청이 있습니다.")

    consultation = ConsultationRequest(
        id=f"consult-{uuid.uuid4().hex[:12]}",
        member_id=member_id,
        target_type=payload.target_type,
        gym_id=payload.gym_id,
        trainer_id=payload.trainer_id,
        exercise_goal=payload.exercise_goal,
        health_purpose_type=payload.health_purpose_type,
        health_purpose_detail=payload.health_purpose_detail,
        preferred_date=payload.preferred_date.isoformat(),
        preferred_time_slot=payload.preferred_time_slot,
        message=payload.message,
        status="pending",
    )
    db.add(consultation)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        if db.scalar(_pending_query(member_id, payload)) is not None:
            raise DuplicatePendingConsultation(
                "이미 대기 중인 상담 요청이 있습니다."
            ) from None
        raise
    db.refresh(consultation)
    return consultation


def list_my_consultations(db: Session, member_id: str) -> list[ConsultationRequest]:
    return list(
        db.scalars(
            select(ConsultationRequest)
            .where(ConsultationRequest.member_id == member_id)
            .order_by(
                ConsultationRequest.created_at.desc(),
                ConsultationRequest.id.desc(),
            )
        ).all()
    )


def get_my_consultation(
    db: Session, member_id: str, consultation_id: str
) -> ConsultationRequest | None:
    return db.scalar(
        select(ConsultationRequest).where(
            ConsultationRequest.id == consultation_id,
            ConsultationRequest.member_id == member_id,
        )
    )
