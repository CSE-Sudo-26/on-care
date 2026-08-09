"""
운동 라우터 — 프론트 계약 정렬.

  GET  /exercise/weeks/current   -> 이번 주 운동 집계(요일별/타입별 + streak + 코칭)
  POST /exercise/sessions        -> 운동 기록 추가 (집계에 반영)
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.db.session import get_db
from app.models.models import ExerciseSession
from app.schemas.exercise_api import (
    ExerciseSessionCreate, ExerciseSessionOut, ExerciseWeekResponse,
)
from app.services.exercise_service import (
    WEEKDAY_LABELS, build_current_week, monday_of_this_week_str,
)

router = APIRouter(tags=["exercise"])

_ALLOWED_TYPES = {"cardio", "strength", "yoga", "walking", "stretching", "other"}
_ALLOWED_INTENSITIES = {"light", "moderate", "high"}


def _reject_if_derived(row: ExerciseSession) -> None:
    """트레이너 PT 완료로 파생된 기록은 회원이 고칠 수 없다. (#499)

    404 가 아니라 409 다 — 기록은 분명히 존재하고 회원 것이며, 화면에도 보인다.
    없는 척하면 앱이 목록에서 사라진 줄 알고 잘못 갱신한다. 삭제하려면 트레이너가
    그 세션을 지워야 하고, 그러면 이 기록도 함께 사라진다.
    """
    if row.source != "member":
        raise HTTPException(
            status_code=409,
            detail="트레이너가 완료 처리한 PT 기록은 수정하거나 삭제할 수 없습니다.",
        )


@router.get("/exercise/weeks/current", response_model=ExerciseWeekResponse)
def current_week(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> ExerciseWeekResponse:
    week_start = monday_of_this_week_str()
    rows = db.scalars(
        select(ExerciseSession)
        .where(ExerciseSession.user_id == current_user.id)
        .where(ExerciseSession.week_start == week_start)
    ).all()
    data = build_current_week(list(rows))
    return ExerciseWeekResponse(
        sessions=[ExerciseSessionOut(**s) for s in data.pop("sessions")],
        **data,
    )


@router.post("/exercise/sessions", response_model=ExerciseSessionOut, status_code=201)
def add_session(
    payload: ExerciseSessionCreate,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> ExerciseSessionOut:
    if payload.type not in _ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail=f"허용되지 않는 운동 타입: {payload.type}")
    if payload.intensity not in _ALLOWED_INTENSITIES:
        raise HTTPException(status_code=400, detail=f"허용되지 않는 운동 강도: {payload.intensity}")
    # minutes(>0)·calories(>=0) 는 ExerciseSessionCreate 의 Field 제약에서 422 로 검증됨

    day_label = payload.day_label or WEEKDAY_LABELS[datetime.now().weekday()]
    if day_label not in WEEKDAY_LABELS:
        raise HTTPException(status_code=400, detail=f"잘못된 요일 라벨: {day_label}")

    row = ExerciseSession(
        id=f"ex-{uuid.uuid4().hex[:12]}",
        user_id=current_user.id,
        week_start=monday_of_this_week_str(),
        day_label=day_label,
        type=payload.type,
        minutes=payload.minutes,
        calories=payload.calories,
        intensity=payload.intensity,
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    # 단건 응답도 프론트 표시 형식(date_label/time_label/items)을 채워 반환
    one = build_current_week([row])["sessions"][0]
    return ExerciseSessionOut(**one)


@router.put("/exercise/sessions/{session_id}", response_model=ExerciseSessionOut)
def update_session(
    session_id: str,
    payload: ExerciseSessionCreate,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> ExerciseSessionOut:
    """운동 기록 수정(본인 소유만, 아니면 404). 유형/시간/칼로리/강도/요일 갱신."""
    if payload.type not in _ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail=f"허용되지 않는 운동 타입: {payload.type}")
    if payload.intensity not in _ALLOWED_INTENSITIES:
        raise HTTPException(status_code=400, detail=f"허용되지 않는 운동 강도: {payload.intensity}")
    # minutes(>0)·calories(>=0) 는 ExerciseSessionCreate 의 Field 제약에서 422 로 검증됨

    row = db.scalar(
        select(ExerciseSession)
        .where(ExerciseSession.id == session_id)
        .where(ExerciseSession.user_id == current_user.id)
    )
    if row is None:
        raise HTTPException(status_code=404, detail="운동 기록을 찾을 수 없습니다.")
    _reject_if_derived(row)

    day_label = payload.day_label or row.day_label
    if day_label not in WEEKDAY_LABELS:
        raise HTTPException(status_code=400, detail=f"잘못된 요일 라벨: {day_label}")

    row.type = payload.type
    row.minutes = payload.minutes
    row.calories = payload.calories
    row.intensity = payload.intensity
    row.day_label = day_label
    db.commit()
    db.refresh(row)

    one = build_current_week([row])["sessions"][0]
    return ExerciseSessionOut(**one)


@router.delete("/exercise/sessions/{session_id}")
def delete_session(
    session_id: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """운동 기록 삭제. 본인 소유 세션만 삭제 가능(아니면 404)."""
    row = db.scalar(
        select(ExerciseSession)
        .where(ExerciseSession.id == session_id)
        .where(ExerciseSession.user_id == current_user.id)
    )
    if row is None:
        raise HTTPException(status_code=404, detail="운동 기록을 찾을 수 없습니다.")
    _reject_if_derived(row)
    db.delete(row)
    db.commit()
    return {"status": "deleted"}
