"""
운동 라우터 — 프론트 계약 정렬.

  GET  /exercise/weeks/current   -> 이번 주 운동 집계(요일별/타입별 + streak + 코칭)
  POST /exercise/sessions        -> 운동 기록 추가 (집계에 반영)
"""
from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.core import clock
from app.db.session import get_db
from app.models.models import ExerciseSession, HealthProfile
from app.schemas.exercise_api import (
    ExerciseSessionCreate, ExerciseSessionOut, ExerciseWeekResponse,
)
from app.services import exercise_types
from app.services.coach import personal_ingest
from app.services.exercise_service import (
    weekly_goals,
    WEEKDAY_LABELS, build_current_week, monday_of_str, monday_of_this_week_str,
    session_date_of,
)

router = APIRouter(tags=["exercise"])


def _session_date(row: ExerciseSession) -> str:
    """세션의 실제 날짜 YYYY-MM-DD. 저장은 (주 시작 + 요일 라벨)로 쪼개져 있다.

    적재 문구에 날짜를 넣으려면 되돌려야 한다 — "월요일"만 적으면 몇 주 전 기록도
    똑같이 보여 코치가 최근 것과 구분하지 못한다.
    """
    resolved = session_date_of(row)
    return resolved.isoformat() if resolved else row.week_start

def _reject_if_derived(row: ExerciseSession) -> None:
    """트레이너 PT/배정 루틴에서 파생된 기록은 회원이 고칠 수 없다. (#499, #638)

    404 가 아니라 409 다 — 기록은 분명히 존재하고 회원 것이며, 화면에도 보인다.
    없는 척하면 앱이 목록에서 사라진 줄 알고 잘못 갱신한다. 삭제하려면 트레이너가
    그 세션을 지워야 하고, 그러면 이 기록도 함께 사라진다.
    """
    if row.source != "member":
        raise HTTPException(
            status_code=409,
            detail="코칭에서 생성된 운동 기록은 수정하거나 삭제할 수 없습니다.",
        )


@router.get("/exercise/weeks/current", response_model=ExerciseWeekResponse)
def current_week(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    week_start: Annotated[str | None, Query(description="조회할 주의 월요일 YYYY-MM-DD")] = None,
) -> ExerciseWeekResponse:
    """한 주의 운동 집계. `week_start` 없이 부르면 이번 주다.

    회원 앱이 지난 날짜를 고르면 그 주를 받아 하루치를 보여준다. 이 파라미터가
    없을 때는 조회 경로가 이번 주 하나뿐이라 지난 기록을 볼 방법이 없었다.
    월요일이 아닌 날짜를 줘도 그 날이 속한 주로 맞춘다.
    """
    if week_start is None:
        week_start = monday_of_this_week_str()
    else:
        # strptime 으로 엄격하게 본다. date.fromisoformat 은 3.11 부터
        # `20260810` 같은 기본 형식도 받아, 앱의 로컬 목업(엄격한 YYYY-MM-DD)과
        # 받아들이는 값의 집합이 갈린다.
        try:
            datetime.strptime(week_start, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(
                status_code=422, detail="week_start 는 YYYY-MM-DD 형식이어야 합니다."
            ) from None
        week_start = monday_of_str(week_start)
    rows = db.scalars(
        select(ExerciseSession)
        .where(ExerciseSession.user_id == current_user.id)
        .where(ExerciseSession.week_start == week_start)
    ).all()
    data = build_current_week(list(rows))
    profile = db.scalar(
        select(HealthProfile).where(HealthProfile.user_id == current_user.id)
    )
    goal_minutes, goal_calories = weekly_goals(profile)
    return ExerciseWeekResponse(
        sessions=[ExerciseSessionOut(**s) for s in data.pop("sessions")],
        weekly_goal_minutes=goal_minutes,
        weekly_goal_calories=goal_calories,
        **data,
    )


def _strength_only(normalized_type: str, value):
    """근력에서만 의미 있는 값(세트·중량). 다른 유형에서 온 값은 버린다. (#1262)

    유산소를 세트로 세는 화면은 없다 — 받아 두면 집계가 읽지 않는 값이 기록에만
    남아, 나중에 그 값을 믿는 화면이 생겼을 때 조용히 어긋난다.
    """
    if normalized_type != exercise_types.STRENGTH:
        return None
    return value


def _weight_for(normalized_type: str, weight: float | None) -> float | None:
    """저장할 중량. 근력만, 소수점 한 자리로 맞춘다. (#1276)"""
    value = _strength_only(normalized_type, weight)
    return None if value is None else round(value, 1)


def _placement(day: date | None) -> tuple[str, str]:
    """(주 시작 월요일, 요일 라벨). 날짜가 없으면 오늘이다.

    한 스냅샷에서 둘을 함께 뽑는다 — 따로 읽으면 KST 자정 사이에 저장된 한
    세션의 요일과 주차가 서로 다른 날을 가리킬 수 있다.
    """
    target = day or clock.today()
    return monday_of_str(target.isoformat()), WEEKDAY_LABELS[target.weekday()]


@router.post("/exercise/sessions", response_model=ExerciseSessionOut, status_code=201)
def add_session(
    payload: ExerciseSessionCreate,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> ExerciseSessionOut:
    # type·intensity·date·minutes·calories 는 모두 ExerciseSessionCreate 의
    # 타입·Field 제약에서 422 로 걸린다.
    week_start, day_label = _placement(payload.date)
    normalized = exercise_types.normalize(payload.type)
    row = ExerciseSession(
        id=f"ex-{uuid.uuid4().hex[:12]}",
        user_id=current_user.id,
        week_start=week_start,
        day_label=day_label,
        type=normalized,
        name=payload.name.strip(),
        minutes=payload.minutes,
        sets=_strength_only(normalized, payload.sets),
        weight=_weight_for(normalized, payload.weight),
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
    """운동 기록 수정(본인 소유만, 아니면 404). 유형/이름/시간/칼로리/강도/날짜 갱신."""
    row = db.scalar(
        select(ExerciseSession)
        .where(ExerciseSession.id == session_id)
        .where(ExerciseSession.user_id == current_user.id)
    )
    if row is None:
        raise HTTPException(status_code=404, detail="운동 기록을 찾을 수 없습니다.")
    _reject_if_derived(row)

    # 날짜를 주지 않은 수정은 원래 있던 자리를 그대로 둔다 — 오늘로 끌어오면
    # 지난 기록을 고치기만 해도 이번 주로 옮겨 간다.
    if payload.date is not None:
        row.week_start, row.day_label = _placement(payload.date)

    row.type = exercise_types.normalize(payload.type)
    row.name = payload.name.strip()
    row.minutes = payload.minutes
    row.sets = _strength_only(row.type, payload.sets)
    row.weight = _weight_for(row.type, payload.weight)
    row.calories = payload.calories
    row.intensity = payload.intensity
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
