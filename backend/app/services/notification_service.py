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
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.models import (
    MemberNotificationSetting,
    Notification,
    TrainerProfile,
)

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


def time_ago(dt: datetime) -> str:
    """알림 목록의 상대 시각 문구. 회원·트레이너 알림함이 함께 쓴다. (#503)"""
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
    # 바꿀 게 없으면 행을 만들지 않는다. 행 없음 == 기본값이므로 빈 요청에
    # 기본값 행을 새로 남기는 것은 의미 없는 쓰기다(리뷰).
    if not fields:
        return get_settings(db, member_id)

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

    조회를 **savepoint 안에서** 한다. 예외를 잡는 것만으로는 부족하다 — DB 오류가
    나면 세션이 실패 상태로 남아, 이어지는 `db.commit()`(메시지·루틴·일정을
    저장하는 그 커밋)까지 함께 죽는다. 설정을 못 읽었다는 이유로 메시지가 사라지면
    안 된다(리뷰). savepoint 를 되돌리면 바깥 트랜잭션은 멀쩡하다.
    """
    try:
        with db.begin_nested():
            return get_settings(db, member_id).get(kind, True)
    except Exception:  # noqa: BLE001 — 설정 조회 실패가 알림도 원래 요청도 막지 않는다
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


#: 트레이너 알림의 종류. `Notification.category` 에 그대로 저장되고, 트레이너 앱이
#: 이 값으로 어디로 이동할지 정한다. 회원 알림의 category 집합
#: (reminder|health_check|achievement|system)과 겹치지 않게 둔다 — 한 컬럼을
#: 공유하지만 읽는 화면이 다르다. (#503)
TRAINER_MESSAGE_KIND = "message"
TRAINER_CONSULTATION_KIND = "consultation"
TRAINER_RESERVATION_KIND = "reservation"

#: 종류별 트레이너 수신 설정 컬럼. 없으면 항상 보낸다 — 상담 요청·예약은 끄면
#: 트레이너가 놓쳐도 되는 종류가 아니고, 설정 화면에도 그 스위치가 없다.
_TRAINER_SETTING_COLUMN: dict[str, str] = {
    TRAINER_MESSAGE_KIND: "notify_new_message",
}


def trainer_wants(db: Session, trainer_id: str, kind: str) -> bool:
    """트레이너가 이 종류의 알림을 받기로 했는가.

    회원용 [wants] 와 갈라 두는 이유는 설정이 있는 자리가 다르기 때문이다.
    회원은 `member_notification_settings`, 트레이너는 `trainer_profiles.notify_*`.
    한쪽 함수로 둘 다 보면 트레이너에게 회원 기본값이 적용된다.
    """
    column = _TRAINER_SETTING_COLUMN.get(kind)
    if column is None:
        return True
    value = db.scalar(
        select(getattr(TrainerProfile, column)).where(
            TrainerProfile.trainer_id == trainer_id
        )
    )
    # 프로필이 없으면(아직 안 만든 계정) 기본값은 '받는다'. 알림이 조용히
    # 사라지는 쪽보다 오는 쪽이 낫다.
    return True if value is None else bool(value)


def queue_for_trainer(
    db: Session,
    *,
    trainer_id: str,
    kind: str,
    title: str,
    body: str = "",
) -> Notification | None:
    """트레이너에게 남기는 알림. 꺼져 있으면 None. **커밋하지 않는다**.

    커밋하지 않는 이유는 [queue] 와 같다 — 호출부의 트랜잭션에 얹는다.

    `Notification.user_id` 는 일반 사용자 FK 라 트레이너 계정에도 그대로 달린다.
    다만 읽는 경로는 회원용 `/notifications` 가 아니라 `/trainer/notifications` 다.
    회원용은 `get_current_user` 가 트레이너를 403 으로 막는 **회원 전용** 경로다.
    """
    if not trainer_wants(db, trainer_id, kind):
        return None
    notification = Notification(
        id=f"noti-{uuid.uuid4().hex[:12]}",
        user_id=trainer_id,
        title=title,
        body=body,
        category=kind,
        read=False,
    )
    db.add(notification)
    return notification
