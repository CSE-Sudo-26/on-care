from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import RequireMember
from app.db.session import get_db
from app.schemas.consultation_api import ConsultationCreate, ConsultationOut
from app.services import consultation_service

router = APIRouter(tags=["consultations"])


@router.post(
    "/consultations",
    response_model=ConsultationOut,
    status_code=status.HTTP_201_CREATED,
)
def create_consultation(
    payload: ConsultationCreate,
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> ConsultationOut:
    try:
        return consultation_service.create_consultation(db, member.id, payload)
    except consultation_service.InvalidConsultationRequest as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except consultation_service.ConsultationTargetNotFound as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except consultation_service.DuplicatePendingConsultation as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.get("/consultations/me", response_model=list[ConsultationOut])
def list_my_consultations(
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> list[ConsultationOut]:
    return consultation_service.list_my_consultations(db, member.id)


@router.get(
    "/consultations/{consultation_id}",
    response_model=ConsultationOut,
)
def get_my_consultation(
    consultation_id: str,
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> ConsultationOut:
    consultation = consultation_service.get_my_consultation(
        db, member.id, consultation_id
    )
    if consultation is None:
        raise HTTPException(status_code=404, detail="상담 요청을 찾을 수 없습니다.")
    return consultation
