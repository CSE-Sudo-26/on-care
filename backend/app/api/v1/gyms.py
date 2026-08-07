"""헬스장·트레이너 디렉터리 라우터 — 회원앱 헬스장 찾기/상세. (#324)

`/trainer/*` 는 트레이너 앱 전용(자기 회원·일정)이라 회원앱이 쓸 수 없어 여기 둔다.
"""
from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.db.session import get_db
from app.schemas.gym_api import GymOut, TrainerOut
from app.services import gym_service

router = APIRouter(tags=["gyms"])


@router.get("/gyms", response_model=list[GymOut])
def list_gyms(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    lat: float | None = Query(None, ge=-90, le=90, description="기준 위도(거리 계산용)"),
    lng: float | None = Query(None, ge=-180, le=180),
    partner_only: bool = Query(False, description="제휴 헬스장만"),
) -> list[GymOut]:
    """헬스장 목록. 좌표를 주면 거리순, 없으면 이름순."""
    return gym_service.list_gyms(db, lat=lat, lng=lng, partner_only=partner_only)


@router.get("/gyms/{gym_id}", response_model=GymOut)
def get_gym(
    gym_id: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    lat: float | None = Query(None, ge=-90, le=90),
    lng: float | None = Query(None, ge=-180, le=180),
) -> GymOut:
    gym = gym_service.get_gym(db, gym_id, lat=lat, lng=lng)
    if gym is None:
        raise HTTPException(status_code=404, detail="헬스장을 찾을 수 없습니다.")
    return gym


@router.get("/gyms/{gym_id}/trainers", response_model=list[TrainerOut])
def list_gym_trainers(
    gym_id: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> list[TrainerOut]:
    """이 헬스장 소속 트레이너 전원. 헬스장이 없으면 404, 있고 소속이 없으면 빈 배열."""
    if gym_service.get_gym(db, gym_id) is None:
        raise HTTPException(status_code=404, detail="헬스장을 찾을 수 없습니다.")
    return gym_service.list_trainers(db, gym_id=gym_id)
