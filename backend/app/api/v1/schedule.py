"""
일정 라우터 — 프론트 계약 정렬.

  GET  /schedule/events?date=YYYY-MM-DD  -> 해당 날짜 일정 배열 (date 생략 시 오늘)
  POST /schedule/events                  -> 일정 추가
"""
from __future__ import annotations

import uuid
from datetime import date as _date
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.db.session import get_db
from app.models.models import ScheduleEvent
from app.schemas.misc_api import ScheduleEventCreate, ScheduleEventOut, ScheduleEventUpdate

router = APIRouter(tags=["schedule"])


def _is_ymd(v: str) -> bool:
    try:
        _date.fromisoformat(v)  # 2026-99-99 등 달력상 불가능한 값 거부
        return True
    except ValueError:
        return False


def _is_ym(v: str) -> bool:
    # YYYY-MM 인지: 그 달 1일이 유효한 날짜인지로 검증(month=% 등 와일드카드 차단).
    return len(v) == 7 and v[4] == "-" and _is_ymd(f"{v}-01")


def _owned_event(db: Session, user_id: str, event_id: str) -> ScheduleEvent:
    """본인 소유 일정을 가져오거나 404."""
    row = db.scalar(select(ScheduleEvent).where(ScheduleEvent.id == event_id))
    if row is None or row.user_id != user_id:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다.")
    return row


@router.get("/schedule/events", response_model=list[ScheduleEventOut])
def list_events(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    date: str | None = Query(None, description="YYYY-MM-DD. 생략 시 오늘."),
    month: str | None = Query(None, description="YYYY-MM. 지정 시 그 달 전체(캘린더용)."),
) -> list[ScheduleEvent]:
    stmt = select(ScheduleEvent).where(ScheduleEvent.user_id == current_user.id)
    if month:
        # 형식 검증 필수 — 미검증 시 month=% 같은 값이 LIKE 와일드카드로 새어 전체 조회됨.
        if not _is_ym(month):
            raise HTTPException(status_code=422, detail="month 는 YYYY-MM 형식이어야 합니다.")
        stmt = stmt.where(ScheduleEvent.date.like(f"{month}-%"))
    else:
        target = date or datetime.now().strftime("%Y-%m-%d")
        if not _is_ymd(target):
            raise HTTPException(status_code=422, detail="date 는 YYYY-MM-DD 형식이어야 합니다.")
        stmt = stmt.where(ScheduleEvent.date == target)
    rows = db.scalars(
        stmt.order_by(ScheduleEvent.date.asc(), ScheduleEvent.time.asc())
    ).all()
    return list(rows)


@router.post("/schedule/events", response_model=ScheduleEventOut, status_code=201)
def create_event(
    payload: ScheduleEventCreate,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> ScheduleEvent:
    row = ScheduleEvent(
        id=f"evt-{uuid.uuid4().hex[:12]}",
        user_id=current_user.id,
        date=payload.date,
        time=payload.time,
        title=payload.title,
        category=payload.category,
        emoji=payload.emoji,
        color_hex=payload.color_hex,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.get("/schedule/events/{event_id}", response_model=ScheduleEventOut)
def get_event(
    event_id: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> ScheduleEvent:
    """일정 상세(본인 소유만)."""
    return _owned_event(db, current_user.id, event_id)


@router.put("/schedule/events/{event_id}", response_model=ScheduleEventOut)
def update_event(
    event_id: str,
    payload: ScheduleEventUpdate,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> ScheduleEvent:
    """일정 상세 수정(제공된 필드만)."""
    row = _owned_event(db, current_user.id, event_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(row, field, value)
    db.commit()
    db.refresh(row)
    return row


@router.delete("/schedule/events/{event_id}")
def delete_event(
    event_id: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """일정 삭제(본인 소유만)."""
    row = _owned_event(db, current_user.id, event_id)
    db.delete(row)
    db.commit()
    return {"status": "deleted"}
