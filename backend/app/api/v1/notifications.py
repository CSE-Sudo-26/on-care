"""
알림 라우터 — 프론트 계약 정렬.

  GET  /notifications              -> 최신순 배열 (time_ago 포함)
  POST /notifications/{id}/read    -> 읽음 처리

회원 알림 수신 설정(GET/PUT /users/me/notification-settings)도 여기 둔다 — 알림을
만드는 일과 끄는 일은 같은 도메인이다. (#489)
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser, RequireMember
from app.db.session import get_db
from app.models.models import Notification
from app.schemas.misc_api import NotificationAction, NotificationOut
from app.schemas.user import (
    MemberNotificationSettings,
    MemberNotificationSettingsUpdate,
)
from app.services import notification_service

router = APIRouter(tags=["notifications"])

# 알림 카테고리 → 바로가기 액션(프론트 라우트 힌트). system 은 액션 없음.
_ACTION_BY_CATEGORY: dict[str, NotificationAction] = {
    "reminder": NotificationAction(label="기록하러 가기", target="dashboard"),
    "health_check": NotificationAction(label="일정 보기", target="schedule"),
    "achievement": NotificationAction(label="대시보드 보기", target="dashboard"),
}


def _action_for(category: str) -> NotificationAction | None:
    return _ACTION_BY_CATEGORY.get(category)


#: 회원·트레이너 알림함이 같은 문구를 써야 해서 서비스로 옮겼다. (#503)
_time_ago = notification_service.time_ago


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


@router.get(
    "/users/me/notification-settings",
    response_model=MemberNotificationSettings,
)
def get_notification_settings(
    user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> MemberNotificationSettings:
    """회원 알림 수신 설정. 저장한 적이 없으면 기본값을 준다. (#489)

    전에는 앱이 SharedPreferences 에만 저장해 기기를 바꾸면 초기화됐고, 서버가
    설정을 몰라 알림을 만들 때 끌 수도 없었다.
    """
    return MemberNotificationSettings(
        **_settings_payload(notification_service.get_settings(db, user.id))
    )


@router.put(
    "/users/me/notification-settings",
    response_model=MemberNotificationSettings,
)
def update_notification_settings(
    payload: MemberNotificationSettingsUpdate,
    user: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> MemberNotificationSettings:
    """보낸 항목만 반영한다."""
    fields = {
        f"notif_{name}": value
        for name, value in payload.model_dump(exclude_none=True).items()
    }
    updated = notification_service.update_settings(db, user.id, fields)
    return MemberNotificationSettings(**_settings_payload(updated))


def _settings_payload(settings: dict[str, bool]) -> dict[str, bool]:
    """서비스의 `notif_*` 키를 응답 필드 이름으로 옮긴다."""
    return {key.removeprefix("notif_"): value for key, value in settings.items()}


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
