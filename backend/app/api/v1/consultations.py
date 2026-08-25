from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import RequireMember
from app.core.pagination import DEFAULT_PAGE, MAX_PAGE, parse_before
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
    limit: int = Query(
        DEFAULT_PAGE, ge=1, le=MAX_PAGE, description="한 번에 가져올 요청 수"
    ),
    before: str | None = Query(
        None, description="ISO datetime 커서(다음 쪽) — 받은 마지막 요청의 created_at"
    ),
    before_id: str | None = Query(
        None, description="복합 커서 tie-break — 받은 마지막 요청의 id"
    ),
) -> list[ConsultationOut]:
    """내가 보낸 상담 요청 한 쪽(최신순, 기본 50건). (#980)

    필터가 없어 승인·거절된 지난 요청까지 함께 자란다. 파라미터 없이 부르면 최신
    50건이고, 그보다 오래된 요청은 커서로 이어 받는다.
    """
    return consultation_service.list_my_consultations(
        db,
        member.id,
        limit=limit,
        before=parse_before(before),
        before_id=before_id,
    )


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


@router.delete(
    "/consultations/{consultation_id}",
    response_model=ConsultationOut,
)
def cancel_my_consultation(
    consultation_id: str,
    member: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> ConsultationOut:
    try:
        return consultation_service.cancel_my_consultation(
            db, member.id, consultation_id
        )
    except consultation_service.ConsultationNotFound as exc:
        raise HTTPException(status_code=404, detail="상담 요청을 찾을 수 없습니다.") from exc
    except consultation_service.ConsultationNotCancellable as exc:
        raise HTTPException(
            status_code=409, detail="대기 중인 상담 요청만 취소할 수 있습니다."
        ) from exc
