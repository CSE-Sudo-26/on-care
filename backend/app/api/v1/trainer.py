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

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import RequireTrainer
from app.db.session import get_db
from app.models.models import TrainerProfile
from app.schemas.trainer_api import TrainerGymOut, TrainerMe

router = APIRouter(tags=["trainer"])


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
