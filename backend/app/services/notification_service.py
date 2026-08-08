"""회원 알림 생성과 수신 설정. (#489)

알림함이 사실상 비어 있었다. `Notification` 행을 만드는 코드가 데모 시드와 상담
승인·거절(#467) 두 곳뿐이어서, 트레이너가 메시지를 보내도 루틴을 배정해도 일정을
잡아도 회원은 해당 화면에 직접 들어가야 알 수 있었다.

**설정과 함께 다루는 이유**: 회원 알림 설정이 기기 로컬(SharedPreferences)에만
있어 서버가 몰랐다. 서버가 모르면 알림을 만들 때 끌 수가 없다. 알림을 만드는 일과
끄는 일은 같은 문제의 양면이다.
"""
from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.models import MemberNotificationSetting, Notification

#: 알림 종류 → 회원 설정 키. 키는 사용자 앱이 이미 쓰던 것 그대로다
#: (`my_flows.dart` 의 `_notifItems`) — 앱이 로컬에 저장하던 값을 서버로 옮기는
#: 것이므로 새 이름을 만들면 기존 화면과 어긋난다.
TRAINER_MESSAGE = "notif_trainer_message"
EXERCISE = "notif_exercise_reminder"
WEEKLY_REPORT = "notif_weekly_report"
DIET_LOG = "notif_diet_log"
AI_COACHING = "notif_ai_coaching"

#: 설정 키 → 기본값. 사용자 앱의 현재 기본값과 같다(주간 리포트만 꺼짐).
DEFAULTS: dict[str, bool] = {
    DIET_LOG: True,
    EXERCISE: True,
    TRAINER_MESSAGE: True,
    AI_COACHING: True,
    WEEKLY_REPORT: False,
}

#: 알림 종류 → 목록에 실릴 category. 앱은 이 값으로 이동 경로를 고른다
#: (`notifications._ACTION_BY_CATEGORY`).
_CATEGORY: dict[str, str] = {
    TRAINER_MESSAGE: "system",
    EXERCISE: "reminder",
    WEEKLY_REPORT: "achievement",
    DIET_LOG: "reminder",
    AI_COACHING: "system",
}


def get_settings(db: Session, member_id: str) -> dict[str, bool]:
    """회원의 알림 수신 설정. 저장된 적이 없으면 기본값."""
    row = db.get(MemberNotificationSetting, member_id)
    if row is None:
        return dict(DEFAULTS)
    return {
        DIET_LOG: row.diet_log,
        EXERCISE: row.exercise_reminder,
        TRAINER_MESSAGE: row.trainer_message,
        AI_COACHING: row.ai_coaching,
        WEEKLY_REPORT: row.weekly_report,
    }


def update_settings(
    db: Session, member_id: str, fields: dict[str, bool]
) -> dict[str, bool]:
    """보낸 항목만 반영한다. 없던 행은 기본값에서 시작해 만든다."""
    row = db.get(MemberNotificationSetting, member_id)
    if row is None:
        row = MemberNotificationSetting(
            member_id=member_id,
            diet_log=DEFAULTS[DIET_LOG],
            exercise_reminder=DEFAULTS[EXERCISE],
            trainer_message=DEFAULTS[TRAINER_MESSAGE],
            ai_coaching=DEFAULTS[AI_COACHING],
            weekly_report=DEFAULTS[WEEKLY_REPORT],
        )
        db.add(row)

    column_by_key = {
        DIET_LOG: "diet_log",
        EXERCISE: "exercise_reminder",
        TRAINER_MESSAGE: "trainer_message",
        AI_COACHING: "ai_coaching",
        WEEKLY_REPORT: "weekly_report",
    }
    for key, column in column_by_key.items():
        if key in fields:
            setattr(row, column, bool(fields[key]))

    db.commit()
    db.refresh(row)
    return get_settings(db, member_id)


def wants(db: Session, member_id: str, kind: str) -> bool:
    """이 회원이 [kind] 알림을 받기로 했는가.

    설정을 읽지 못하면 **받는 쪽으로** 둔다 — 알림이 하나 더 오는 것보다 놓치는
    쪽이 나쁘다.
    """
    try:
        return get_settings(db, member_id).get(kind, True)
    except Exception:  # noqa: BLE001 — 설정 조회 실패가 알림을 막지 않는다
        return True


def queue(
    db: Session,
    *,
    member_id: str,
    kind: str,
    title: str,
    body: str = "",
) -> Notification | None:
    """알림을 세션에 **추가만** 한다(커밋하지 않는다). 꺼져 있으면 None.

    커밋하지 않는 이유: 호출하는 쪽이 이미 자기 변경을 커밋하는 트랜잭션을 갖고
    있다. 여기서 따로 커밋하면 메시지는 저장됐는데 알림만 없는(또는 그 반대인)
    반쪽 상태가 생긴다. 같은 트랜잭션에 얹어 함께 성사시킨다.

    별도 실패 모드를 만들지 않는다는 뜻이기도 하다 — 여기서 하는 일은 `db.add`
    뿐이라 원래 요청을 새로 실패시킬 여지가 없다. 외부 발송(푸시)은 이 함수
    바깥의 일이다(#474).
    """
    if not wants(db, member_id, kind):
        return None
    notification = Notification(
        id=f"noti-{uuid.uuid4().hex[:12]}",
        user_id=member_id,
        title=title,
        body=body,
        category=_CATEGORY.get(kind, "system"),
        read=False,
    )
    db.add(notification)
    return notification


def unread_count(db: Session, member_id: str) -> int:
    """읽지 않은 알림 수. 테스트와 배지가 같은 계산을 쓰게 한다."""
    rows = db.scalars(
        select(Notification.id).where(
            Notification.user_id == member_id,
            Notification.read.is_(False),
        )
    ).all()
    return len(rows)
