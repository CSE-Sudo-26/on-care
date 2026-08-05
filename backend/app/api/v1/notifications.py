"""
알림 라우터 — 프론트 계약 정렬.

  GET  /notifications              -> 최신순 배열 (time_ago 포함)
  POST /notifications/{id}/read    -> 읽음 처리
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser
from app.db.session import get_db
from app.models.models import Notification
from app.schemas.misc_api import NotificationAction, NotificationOut

router = APIRouter(tags=["notifications"])

# 알림 카테고리 → 바로가기 액션(프론트 라우트 힌트). system 은 액션 없음.
_ACTION_BY_CATEGORY: dict[str, NotificationAction] = {
    "reminder": NotificationAction(label="기록하러 가기", target="dashboard"),
    "health_check": NotificationAction(label="일정 보기", target="schedule"),
    "achievement": NotificationAction(label="대시보드 보기", target="dashboard"),
}


def _action_for(category: str) -> NotificationAction | None:
    return _ACTION_BY_CATEGORY.get(category)


def _time_ago(dt: datetime) -> str:
    now = datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    sec = (now - dt).total_seconds()
    if sec < 60:
        return "방금 전"
    if sec < 3600:
        return f"{int(sec // 60)}분 전"
    if sec < 86400:
        return f"{int(sec // 3600)}시간 전"
    return f"{int(sec // 86400)}일 전"


@router.get("/notifications", response_model=list[NotificationOut])
def list_notifications(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> list[NotificationOut]:
    rows = db.scalars(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
    ).all()
    return [
        NotificationOut(
            id=r.id, title=r.title, body=r.body, category=r.category,
            read=r.read, created_at=r.created_at, time_ago=_time_ago(r.created_at),
            action=_action_for(r.category),
        )
        for r in rows
    ]


@router.get("/notifications/unread-count", response_model=dict)
def unread_count(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """미확인 알림 수(배지용)."""
    n = db.scalar(
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == current_user.id, Notification.read.is_(False))
    ) or 0
    return {"unread": n}


@router.post("/notifications/read-all")
def mark_all_read(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """내 미확인 알림을 모두 읽음 처리."""
    result = db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id, Notification.read.is_(False))
        .values(read=True)
    )
    db.commit()
    return {"marked_read": result.rowcount or 0}


@router.post("/notifications/{notification_id}/read", status_code=200)
def mark_read(
    notification_id: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    row = db.scalar(select(Notification).where(Notification.id == notification_id))
    if row is None or row.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="알림을 찾을 수 없습니다.")
    row.read = True
    db.commit()
    return {"id": notification_id, "read": True}


@router.delete("/notifications/{notification_id}")
def delete_notification(
    notification_id: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """알림 삭제(본인 소유만)."""
    row = db.scalar(select(Notification).where(Notification.id == notification_id))
    if row is None or row.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="알림을 찾을 수 없습니다.")
    db.delete(row)
    db.commit()
    return {"status": "deleted"}
