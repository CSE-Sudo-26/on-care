"""
운동 라우터 — 프론트 계약 정렬.

  GET  /exercise/weeks/current   -> 이번 주 운동 집계(요일별/타입별 + streak + 코칭)
  POST /exercise/sessions        -> 운동 기록 추가 (집계에 반영)
"""
from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.core import clock
from app.db.session import get_db
from app.models.models import ExerciseSession
from app.schemas.exercise_api import (
    ExerciseSessionCreate, ExerciseSessionOut, ExerciseWeekResponse,
)
from app.services.coach import personal_ingest
from app.services.exercise_service import (
    WEEKDAY_LABELS, build_current_week, monday_of_str, monday_of_this_week_str,
)

router = APIRouter(tags=["exercise"])


def _session_date(row: ExerciseSession) -> str:
    """세션의 실제 날짜 YYYY-MM-DD. 저장은 (주 시작 + 요일 라벨)로 쪼개져 있다.

    적재 문구에 날짜를 넣으려면 되돌려야 한다 — "월요일"만 적으면 몇 주 전 기록도
    똑같이 보여 코치가 최근 것과 구분하지 못한다.
    """
    from datetime import date as _d, timedelta

    try:
        monday = _d.fromisoformat(row.week_start)
        return (monday + timedelta(days=WEEKDAY_LABELS.index(row.day_label))).isoformat()
    except (ValueError, IndexError):
        return row.week_start

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

    # 요일 라벨과 주차를 같은 스냅샷에서 뽑는다 — 따로 읽으면 KST 자정 사이에
    # 저장된 한 세션의 요일과 주차가 서로 다른 날을 가리킬 수 있다.
    today = clock.today()
    day_label = payload.day_label or WEEKDAY_LABELS[today.weekday()]
    if day_label not in WEEKDAY_LABELS:
        raise HTTPException(status_code=400, detail=f"잘못된 요일 라벨: {day_label}")

    row = ExerciseSession(
        id=f"ex-{uuid.uuid4().hex[:12]}",
        user_id=current_user.id,
        week_start=monday_of_str(today.isoformat()),
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
    out = ExerciseSessionOut(**one)
    # 응답을 다 만든 뒤 적재한다(#586). 실패하면 personal_ingest 가 세션을 롤백하는데,
    # 그때 row 가 만료되면 적재 실패가 기록 저장 실패로 번진다. 커밋은 이미 끝났다.
    personal_ingest.record_exercise(
        db, current_user.id, date=_session_date(row), exercise_type=row.type,
        minutes=row.minutes, calories=row.calories, intensity=row.intensity,
        source_ref=row.id,
    )
    return out


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
    out = ExerciseSessionOut(**one)
    # 30분을 45분으로 고쳤으면 코치도 45분으로 알아야 한다(#603). 값을 넘기지 않고
    # id 만 넘기는 이유는 #614 — 갱신은 잠금 안에서 행을 다시 읽어야, 두 수정이
    # 역순으로 도착해도 최종 문서가 DB 최신값과 어긋나지 않는다.
    personal_ingest.refresh_exercise(db, current_user.id, session_id=row.id)
    return out


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
    personal_ingest.forget(db, current_user.id, session_id)
    return {"status": "deleted"}
