"""
트레이너 라우터 — 트레이너 앱 전용(role == 'trainer').

  GET /trainer/me   -> 로그인한 트레이너의 프로필(Figma MY / seedTrainerProfile)

이후 이슈에서 /trainer/clients, /trainer/clients/{id}/diet(회원 실데이터 공유),
채팅·루틴·스케줄이 이 라우터에 추가된다. 모든 엔드포인트는 RequireTrainer 로
보호되며 데모 폴백이 없다(회원 데모 사용자 유입 차단).
"""
from __future__ import annotations

import json
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import RequireTrainer
from app.db.session import get_db
from app.models.models import TrainerClient, TrainerProfile
from app.schemas.trainer_api import (
    ClientDietEntryOut, RoutineHistoryOut, TrainerClientOut, TrainerGymOut, TrainerMe,
)
from app.services import trainer_service

router = APIRouter(tags=["trainer"])


def _require_client(db: Session, trainer_id: str, member_id: str) -> TrainerClient:
    """(trainer, member) 담당 링크를 확인. 남의 고객/미담당이면 404(소유권 경계)."""
    link = db.scalar(
        select(TrainerClient).where(
            TrainerClient.trainer_id == trainer_id,
            TrainerClient.member_id == member_id,
        )
    )
    if link is None:
        raise HTTPException(status_code=404, detail="담당 고객을 찾을 수 없습니다.")
    return link


@router.get("/trainer/me", response_model=TrainerMe)
def trainer_me(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> TrainerMe:
    profile = db.scalar(
        select(TrainerProfile).where(TrainerProfile.trainer_id == trainer.id)
    )
    if profile is None:
        raise HTTPException(status_code=404, detail="트레이너 프로필이 없습니다.")

    try:
        certs = json.loads(profile.certifications_json) if profile.certifications_json else []
    except json.JSONDecodeError:
        certs = []

    return TrainerMe(
        id=trainer.id,
        name=trainer.name,
        email=trainer.email,
        phone=profile.phone,
        specialty=profile.specialty,
        career=f"{profile.career_years}년",
        intro=profile.intro,
        certifications=certs,
        gym=TrainerGymOut(
            name=profile.gym_name,
            address=profile.gym_address,
            hours=profile.gym_hours,
            phone=profile.gym_phone,
        ),
    )


@router.get("/trainer/clients", response_model=list[TrainerClientOut])
def trainer_clients(
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> list[TrainerClientOut]:
    """담당 고객 로스터. 각 카드의 오늘 칼로리/나트륨/당류와 나트륨 추세는
    회원의 실제 식단 기록(DietEntry)에서 집계한다 — 트레이너↔회원 실데이터 공유."""
    return trainer_service.build_roster(db, trainer.id)


@router.get("/trainer/clients/{member_id}/diet", response_model=list[ClientDietEntryOut])
def trainer_client_diet(
    member_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
    date: str | None = Query(None, description="YYYY-MM-DD (기본: 오늘)"),
) -> list[ClientDietEntryOut]:
    """담당 고객의 식단(회원이 회원 앱에서 기록한 실제 데이터)."""
    _require_client(db, trainer.id, member_id)
    day = date or trainer_service.today_iso()
    return trainer_service.build_client_diet(db, member_id, day)


@router.get("/trainer/clients/{member_id}/history", response_model=list[RoutineHistoryOut])
def trainer_client_history(
    member_id: str,
    trainer: RequireTrainer,
    db: Annotated[Session, Depends(get_db)],
) -> list[RoutineHistoryOut]:
    """담당 고객의 운동 완료 기록(최신순)."""
    _require_client(db, trainer.id, member_id)
    return trainer_service.build_client_history(db, member_id)
