"""
트레이너 도메인 서비스 — 로스터/식단/기록 집계.

핵심(진짜 데이터 공유): 고객의 영양소·나트륨 추세는 별도 복제본이 아니라
회원이 회원 앱에서 남긴 실제 DietEntry 를 집계한 값이다. 라우터는 얇게 두고 도메인
로직(집계·라벨링·계약 매핑)은 여기에 모은다.
"""
from __future__ import annotations

import json
import uuid
from collections.abc import Callable, Mapping, Sequence
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, or_, select, tuple_, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from pydantic import ValidationError

from app.core import clock
from app.models.models import (
    ChatMessage, DietEntry, ExerciseSession, GymProfile, Place, RoutineHistory,
    TrainerClient, TrainerClientMemo, TrainerProfile, TrainerProgramDraft,
    TrainerReservation, TrainerReservationSlot, TrainerRoutine, TrainerSchedule,
    User,
)
from app.schemas.trainer_api import (
    ChatMessageOut, ClientDietEntryOut, MemberCoachOut, ProgramDraftExercise,
    ProgramDraftSession,
    ProgramItem, RoutineHistoryOut,
    RoutineOut, ScheduleSessionOut, TrainerClientOut, TrainerClientStatusOut,
    TrainerGymOut, TrainerMe, TrainerMemoOut, TrainerNotificationSettings,
    TrainerProgramDraftOut, TrainerProgramDraftSummary, WeeklyReportDayOut,
    WeeklyReportOut,
)
from app.services import (
    auto_routine_service,
    diet_photo_service,
    exercise_service,
    notification_service,
    routine_suggestion_service,
)
from app.services.coach import personal_ingest

# 일일 나트륨 목표(mg). 프론트 `sodiumTargetMg` 와 같은 값 — 리포트의
# '초과 N일'이 앱 화면의 경고와 어긋나면 안 된다.
SODIUM_TARGET_MG = 2000


class IdempotencyConflict(Exception):
    """같은 멱등키가 이미 다른 payload 에 사용됐다."""


def _today() -> date:
    return clock.today()


def today_iso() -> str:
    """오늘 날짜 YYYY-MM-DD (라우터 기본 날짜용)."""
    return _today().isoformat()


def _meal_kr(meal_type: str) -> str:
    return {"breakfast": "아침", "lunch": "점심", "dinner": "저녁", "snack": "간식"}.get(
        meal_type, meal_type
    )


def relative_day_label(day: str) -> str:
    """YYYY-MM-DD → 오늘/어제/N일 전 (마지막 루틴 전송 라벨용)."""
    try:
        then = date.fromisoformat(day)
    except ValueError:
        return day
    delta = (_today() - then).days
    if delta <= 0:
        return "오늘"
    if delta == 1:
        return "어제"
    return f"{delta}일 전"


def history_date_label(day: str) -> str:
    """YYYY-MM-DD → 'M/D' (+ ' (오늘)'/' (어제)') 운동기록 라벨."""
    try:
        then = date.fromisoformat(day)
    except ValueError:
        return day
    label = f"{then.month}/{then.day}"
    delta = (_today() - then).days
    if delta == 0:
        label += " (오늘)"
    elif delta == 1:
        label += " (어제)"
    return label


def relative_time_label(ts: datetime) -> str:
    """채팅 최근시각 → 방금/N분 전/N시간 전/N일 전."""
    now = datetime.now(timezone.utc)
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    secs = (now - ts).total_seconds()
    if secs < 60:
        return "방금"
    if secs < 3600:
        return f"{int(secs // 60)}분 전"
    if secs < 86400:
        return f"{int(secs // 3600)}시간 전"
    return f"{int(secs // 86400)}일 전"


def _local_date_iso(ts: datetime) -> str:
    """tz-aware(또는 naive=UTC 가정) 시각 → KST 날짜 YYYY-MM-DD.

    created_at 은 UTC 로 저장되므로, '오늘/어제' 판정과 맞추려면 KST 날짜로 변환해야
    한다(안 그러면 KST 새벽엔 UTC 가 전날이라 '어제'로 어긋난다)."""
    return clock.to_seoul(ts).date().isoformat()


def _today_totals(
    diet_rows: list[DietEntry], today_str: str
) -> tuple[int, int, float, float, float, float]:
    calories = sodium_mg = 0
    sugar_g = carbs_g = protein_g = fat_g = 0.0
    for e in diet_rows:
        if e.date == today_str:
            calories += e.total_calories
            sodium_mg += e.sodium_mg
            sugar_g += e.sugar_g
            carbs_g += e.carbs_g
            protein_g += e.protein_g
            fat_g += e.fat_g
    return calories, sodium_mg, sugar_g, carbs_g, protein_g, fat_g


def _sodium_week(diet_rows: list[DietEntry], monday: date) -> list[int]:
    """이번 주(월→일) 일별 나트륨 합. 기록 없는 날은 0."""
    return [
        round(v) for v in _daily_week(diet_rows, monday, lambda e: e.sodium_mg)
    ]


def _calories_week(diet_rows: list[DietEntry], monday: date) -> list[int]:
    """이번 주(월→일) 일별 칼로리 합. 나트륨과 같은 창·같은 규칙이다. (#746)"""
    return [
        round(v)
        for v in _daily_week(diet_rows, monday, lambda e: e.total_calories)
    ]


def _sugar_week(diet_rows: list[DietEntry], monday: date) -> list[float]:
    """이번 주(월→일) 일별 당류 합.

    나트륨·칼로리와 달리 소수를 유지한다 — 당류는 6.3+8.5 처럼 소수로 쌓이고,
    반올림하면 같은 회원의 식단 탭 수치와 어긋난다(`sugar_g` 가 Float 인 이유와
    같다).
    """
    return [round(v, 1) for v in _daily_week(diet_rows, monday, lambda e: e.sugar_g)]


def _daily_week(
    diet_rows: list[DietEntry], monday: date, value: Callable[[DietEntry], float]
) -> list[float]:
    """이번 주(월→일) 일별 합. 기록 없는 날과 아직 오지 않은 날은 0.

    `week_completion` 과 **같은 창**이다. 오늘 기준 롤링 7일이 아니라 요일에
    고정한다 — 화면이 이 값을 요일 라벨과 함께 그리므로, 창이 굴러가면 금요일
    수치가 일요일 자리에 놓인다(#746).
    """
    by_date: dict[str, float] = {}
    for e in diet_rows:
        by_date[e.date] = by_date.get(e.date, 0) + value(e)
    return [
        by_date.get((monday + timedelta(days=off)).isoformat(), 0)
        for off in range(7)
    ]


def _week_completion(hist_rows: list[RoutineHistory], monday: date) -> list[int]:
    """이번 주(월→일) 일별 완료율. 같은 날 여러 기록이면 최댓값, 없으면 0."""
    by_date: dict[str, list[int]] = {}
    for h in hist_rows:
        by_date.setdefault(h.date, []).append(h.completion_rate)
    out: list[int] = []
    for i in range(7):
        vals = by_date.get((monday + timedelta(days=i)).isoformat())
        out.append(max(vals) if vals else 0)
    return out


def _week_days(
    hist_rows: list[RoutineHistory], monday: date, week: list[int]
) -> list[WeeklyReportDayOut]:
    """요일별 이행률 + 그날 배정된 운동(월→일).

    같은 날 기록이 여럿이면 이행률과 **같은 기록**의 운동을 쓴다 — 완료율은
    최댓값을 택하므로, 다른 기록의 운동 목록을 붙이면 화면에서 67% 옆에 3/3
    이 놓이는 어긋남이 생긴다.
    """
    best: dict[str, RoutineHistory] = {}
    for h in hist_rows:
        current = best.get(h.date)
        if current is None or h.completion_rate > current.completion_rate:
            best[h.date] = h
    out: list[WeeklyReportDayOut] = []
    for i in range(7):
        row = best.get((monday + timedelta(days=i)).isoformat())
        out.append(
            WeeklyReportDayOut(
                completion=week[i] if i < len(week) else 0,
                exercises=_exercise_names(row),
            )
        )
    return out


def _exercise_names(row: RoutineHistory | None) -> list[str]:
    """저장된 운동 목록을 방어적으로 디코드. 깨진 값은 빈 목록으로."""
    if row is None or not row.exercises_json:
        return []
    try:
        names = json.loads(row.exercises_json)
    except json.JSONDecodeError:
        return []
    if not isinstance(names, list):
        return []
    return [n for n in names if isinstance(n, str)]


def _latest_by_member(db: Session, model, trainer_id: str, member_ids: list[str]):
    """(trainer, member) 스레드별 최신 1건을 member_id → row 로.

    Postgres DISTINCT ON 으로 회원당 1행만 DB 에서 반환한다 — 오래된 메시지/루틴이
    아무리 많아도 반환 행 수는 회원 수 이하다(전체 로드 후 Python 선별 금지, 리뷰 PR 250-#2).
    """
    rows = db.scalars(
        select(model)
        .where(model.trainer_id == trainer_id, model.member_id.in_(member_ids))
        # DISTINCT ON (member_id) + 최신순 → 회원별 최신 1건. ORDER BY 선두는
        # distinct 컬럼(member_id)이어야 한다.
        .order_by(model.member_id, model.created_at.desc())
        .distinct(model.member_id)
    ).all()
    return {r.member_id: r for r in rows}


def _roster_active(link: TrainerClient) -> bool:
    """로스터 카드의 활성/휴면. (#707)

    두 조건을 모두 만족해야 활성이다 — 담당 관계가 살아 있고(`active`), 트레이너가
    휴면으로 내리지 않았을 것(`not dormant`). 담당이 해제된 과거 회원은 로스터에
    이력으로 남는데, 그 카드는 예나 지금이나 휴면으로 보여야 한다.
    """
    return link.active and not link.dormant


def build_roster(db: Session, trainer_id: str) -> list[TrainerClientOut]:
    """트레이너의 담당 고객 로스터. 각 카드의 영양 지표는 회원 실데이터에서 집계.

    쿼리는 고객 수와 무관하게 상수개(배치)로 유지하고, 식단/기록은 필요한 창(최근 7일 /
    이번 주)만 로드한다(N+1·무제한 이력 로드 방지, 리뷰 PR 250-#3).
    """
    links = db.scalars(
        select(TrainerClient)
        .where(TrainerClient.trainer_id == trainer_id)
        .order_by(TrainerClient.sort_order, TrainerClient.created_at)
    ).all()
    if not links:
        return []
    member_ids = [l.member_id for l in links]

    today = _today()
    today_str = today.isoformat()
    monday = today - timedelta(days=today.weekday())
    week_ago_str = (today - timedelta(days=6)).isoformat()
    monday_str = monday.isoformat()

    # 식단(오늘 합계 + 이번 주 추이) — 전 고객 배치, 날짜 한정. 월요일은 항상
    # `today - 6` 이후라 이 창 하나로 이번 주 월→일을 모두 덮는다.
    diet_by_member: dict[str, list[DietEntry]] = defaultdict(list)
    for e in db.scalars(
        select(DietEntry).where(
            DietEntry.user_id.in_(member_ids), DietEntry.date >= week_ago_str
        )
    ).all():
        diet_by_member[e.user_id].append(e)

    # 이번 주 운동기록(완료율용) — 트레이너 소유(PT) or 자율(NULL)만, 날짜 한정.
    # 타 트레이너의 기록은 제외한다(메모 노출 방지, 리뷰 PR 250-#1).
    hist_by_member: dict[str, list[RoutineHistory]] = defaultdict(list)
    for h in db.scalars(
        select(RoutineHistory).where(
            RoutineHistory.member_id.in_(member_ids),
            RoutineHistory.date >= monday_str,
            or_(RoutineHistory.trainer_id.is_(None), RoutineHistory.trainer_id == trainer_id),
        )
    ).all():
        hist_by_member[h.member_id].append(h)

    last_msg_by = _latest_by_member(db, ChatMessage, trainer_id, member_ids)
    last_rt_by = _latest_by_member(db, TrainerRoutine, trainer_id, member_ids)
    members = {
        m.id: m for m in db.scalars(select(User).where(User.id.in_(member_ids))).all()
    }

    out: list[TrainerClientOut] = []
    for link in links:
        member = members.get(link.member_id)
        if member is None:
            continue
        diet_rows = diet_by_member.get(link.member_id, [])
        calories, sodium_mg, sugar_g, carbs_g, protein_g, fat_g = _today_totals(
            diet_rows, today_str
        )
        last_msg = last_msg_by.get(link.member_id)
        last_rt = last_rt_by.get(link.member_id)

        out.append(TrainerClientOut(
            id=link.member_id,
            name=member.name,
            avatar=member.name[:1] if member.name else "?",
            goal=link.goal,
            last_message=last_msg.body if last_msg else "",
            last_time=relative_time_label(last_msg.created_at) if last_msg else "-",
            active=_roster_active(link),
            calories=calories,
            sodium_mg=sodium_mg,
            sugar_g=sugar_g,
            carbs_g=carbs_g,
            protein_g=protein_g,
            fat_g=fat_g,
            last_routine=(
                relative_day_label(_local_date_iso(last_rt.created_at))
                if last_rt else "-"
            ),
            week_completion=_week_completion(hist_by_member.get(link.member_id, []), monday),
            sodium_week=_sodium_week(diet_rows, monday),
            calories_week=_calories_week(diet_rows, monday),
            sugar_week=_sugar_week(diet_rows, monday),
        ))
    return out


def _food_names(foods_json: str | None) -> list[str]:
    """저장된 `foods_json` → 표시용 음식 이름 목록.

    항목이 딕셔너리라는 보장이 없다. 실제로 `["김치찌개", 42, null]` 처럼 문자열·숫자가
    섞여 저장된 기록이 있고, 예전에는 `f.get("name")` 이 그 자리에서 AttributeError 를
    내 **그 날짜 식단 조회 전체가 500** 이 됐다(#724). 회원 앱 경로
    (`diet_service.load_foods`)는 같은 값을 받아도 죽지 않아, 한 기록인데 트레이너 쪽만
    터졌다.

    문자열은 이름으로 살린다 — 버리면 트레이너 화면에서 끼니 내용이 통째로 빈다.
    이름을 만들 수 없는 나머지(숫자·null 등)는 건너뛴다.
    """
    try:
        foods = json.loads(foods_json) if foods_json else []
    except json.JSONDecodeError:
        return []
    if not isinstance(foods, list):
        return []

    names: list[str] = []
    for food in foods:
        if isinstance(food, dict):
            name = food.get("name")
        elif isinstance(food, str):
            name = food
        else:
            continue
        if isinstance(name, str) and name.strip():
            names.append(name.strip())
    return names


def build_client_diet(db: Session, member_id: str, day: str) -> list[ClientDietEntryOut]:
    """회원의 특정 날짜 식단(회원 실데이터)을 고객 식단 서브탭 형태로."""
    rows = db.scalars(
        select(DietEntry)
        .where(DietEntry.user_id == member_id, DietEntry.date == day)
        .order_by(DietEntry.created_at, DietEntry.id)
    ).all()

    # 사진은 id 만 한 번에 읽는다(바이트는 사진 라우트에서만 흐른다). (#699)
    photo_ids = diet_photo_service.photo_ids_for_entries(db, [r.id for r in rows])

    out: list[ClientDietEntryOut] = []
    for r in rows:
        items = ", ".join(_food_names(r.foods_json))
        photo_id = photo_ids.get(r.id)
        out.append(ClientDietEntryOut(
            meal=_meal_kr(r.meal_type),
            items=items,
            calories=r.total_calories,
            sodium_mg=r.sodium_mg,
            carbs_g=r.carbs_g,
            protein_g=r.protein_g,
            fat_g=r.fat_g,
            photo_url=client_photo_url(member_id, photo_id) if photo_id else None,
        ))
    return out


def client_photo_url(member_id: str, photo_id: str) -> str:
    """담당 트레이너가 보는 고객 끼니 사진 경로(API base 기준 상대 경로).

    회원 경로(`/diet/photos/{id}`)와 다른 이유는 접근 판정이 다르기 때문이다.
    이 경로는 `member_id` 를 지나가므로 라우터가 담당 링크를 먼저 확인하고,
    사진이 그 회원의 것인지까지 본다.
    """
    return f"/trainer/clients/{member_id}/diet/photos/{photo_id}"


def build_client_history(
    db: Session, member_id: str, trainer_id: str, limit: int = 60
) -> list[RoutineHistoryOut]:
    """회원의 운동 완료 기록(최신순).

    이 트레이너에게 보이는 기록만 반환한다: 자율 운동(trainer_id NULL) + 이 트레이너가
    지도한 세션(trainer_id == 본인). 타 트레이너가 작성한 메모(trainer_note)는 노출하지
    않는다(리뷰 PR 250-#1). 오래된 이력 무제한 로드를 막기 위해 limit 로 제한.
    """
    rows = db.scalars(
        select(RoutineHistory)
        .where(
            RoutineHistory.member_id == member_id,
            or_(RoutineHistory.trainer_id.is_(None), RoutineHistory.trainer_id == trainer_id),
        )
        .order_by(RoutineHistory.date.desc(), RoutineHistory.created_at.desc())
        .limit(limit)
    ).all()

    assigned_rows = db.scalars(
        select(ExerciseSession).where(
            ExerciseSession.user_id == member_id,
            ExerciseSession.source == "assigned_routine",
            ExerciseSession.assigned_trainer_id == trainer_id,
        )
        .order_by(ExerciseSession.completed_at.desc(), ExerciseSession.created_at.desc())
        .limit(limit)
    ).all()

    dated: list[tuple[str, float, RoutineHistoryOut]] = []
    for r in rows:
        try:
            exercises = json.loads(r.exercises_json) if r.exercises_json else []
        except json.JSONDecodeError:
            exercises = []
        dated.append((r.date, clock.to_seoul(r.created_at).timestamp(), RoutineHistoryOut(
            id=r.id,
            date_label=history_date_label(r.date),
            label=r.kind_label,
            completion_rate=r.completion_rate,
            exercises=exercises,
            client_feedback=r.client_feedback,
            trainer_note=r.trainer_note,
        )))
    for r in assigned_rows:
        completed_at = r.completed_at or r.created_at
        day = clock.to_seoul(completed_at).date().isoformat()
        dated.append(
            (
                day,
                clock.to_seoul(completed_at).timestamp(),
                _assigned_history_out(r),
            )
        )
    dated.sort(key=lambda item: (item[0], item[1]), reverse=True)
    return [item[2] for item in dated[:limit]]


# ---- 채팅 (트레이너↔회원, 양방향 공유 스레드) ----

def _hhmm(ts: datetime) -> str:
    """created_at → KST HH:MM."""
    return clock.to_seoul(ts).strftime("%H:%M")


def _sender_out(sender: str, viewer: str = "trainer") -> str:
    """저장값(trainer|member) → 뷰어 관점 라벨.

    트레이너 앱: 상대(member)는 'client'. 회원 앱: 자신(member)은 'me', 트레이너는 'trainer'.
    """
    if viewer == "member":
        return "me" if sender == "member" else "trainer"
    return "client" if sender == "member" else "trainer"


def _iso(ts: datetime) -> str:
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    return ts.astimezone(timezone.utc).isoformat()


def build_chat_thread(
    db: Session, trainer_id: str, member_id: str,
    limit: int = 50, before: datetime | None = None, before_id: str | None = None,
    viewer: str = "trainer",
) -> list[ChatMessageOut]:
    """(trainer, member) 스레드 메시지(오래된→최신).

    무제한 로드를 막기 위해 기본 최신 `limit`건만 가져온다(리뷰 PR 251-#3). 이전 페이지는
    가장 오래된 메시지의 (created_at, id)를 (before, before_id) 커서로 넘겨 요청한다.
    같은 created_at 이 여러 건이어도 누락되지 않도록 (created_at, id) 복합 커서를 쓴다
    (리뷰 재-#1). 응답의 created_at 으로 클라이언트가 다음 커서를 만든다.
    """
    q = select(ChatMessage).where(
        ChatMessage.trainer_id == trainer_id, ChatMessage.member_id == member_id
    )
    if before is not None:
        if before_id is not None:
            # (created_at, id) < (before, before_id) — 동일 created_at 경계도 안전하게 통과
            q = q.where(
                tuple_(ChatMessage.created_at, ChatMessage.id) < (before, before_id)
            )
        else:
            q = q.where(ChatMessage.created_at < before)
    rows = list(db.scalars(
        q.order_by(ChatMessage.created_at.desc(), ChatMessage.id.desc()).limit(limit)
    ).all())
    rows.reverse()  # 최신 limit건을 오래된→최신 순으로
    return [
        ChatMessageOut(
            id=r.id, sender=_sender_out(r.sender, viewer), body=r.body,
            time_label=_hhmm(r.created_at), created_at=_iso(r.created_at),
        )
        for r in rows
    ]


def _chat_out(msg: ChatMessage, viewer: str) -> ChatMessageOut:
    return ChatMessageOut(
        id=msg.id,
        sender=_sender_out(msg.sender, viewer),
        body=msg.body,
        time_label=_hhmm(msg.created_at),
        created_at=_iso(msg.created_at),
    )


def find_message_by_client_request(
    db: Session,
    trainer_id: str,
    member_id: str,
    sender: str,
    client_request_id: str,
) -> ChatMessage | None:
    return db.scalar(
        select(ChatMessage).where(
            ChatMessage.trainer_id == trainer_id,
            ChatMessage.member_id == member_id,
            ChatMessage.sender == sender,
            ChatMessage.client_request_id == client_request_id,
        )
    )


def _existing_message_out(
    message: ChatMessage, *, text: str, viewer: str
) -> ChatMessageOut:
    if message.body != text:
        raise IdempotencyConflict(
            "같은 client_request_id에 다른 메시지를 보낼 수 없습니다."
        )
    return _chat_out(message, viewer)


def send_message(
    db: Session, trainer_id: str, member_id: str, sender: str, text: str,
    viewer: str = "trainer", notify: str | None = None,
    client_request_id: str | None = None,
) -> ChatMessageOut:
    """스레드에 메시지 추가(sender: 'trainer'|'member'). 로스터 last_message 는
    build_roster 가 최신 메시지를 읽어 자동 반영하므로 별도 비정규화가 없다.

    [notify] 가 주어지면 그 종류로 회원 알림을 **같은 트랜잭션에** 얹는다(#489).
    종류를 호출자가 정하는 이유: 주간 리포트도 이 함수로 나가므로, 여기서 판단하면
    일반 메시지와 구분할 수 없다.

    회원이 보낸 메시지에는 **트레이너 알림**을 남긴다(#503). 사이드바 미읽음 배지는
    지금 보고 있을 때만 눈에 들어오고, 지나가면 다시 볼 자리가 없었다.
    """
    if client_request_id:
        existing = find_message_by_client_request(
            db, trainer_id, member_id, sender, client_request_id
        )
        if existing is not None:
            return _existing_message_out(existing, text=text, viewer=viewer)

    msg = ChatMessage(
        id=f"chat-{uuid.uuid4().hex[:12]}",
        trainer_id=trainer_id,
        member_id=member_id,
        sender=sender,
        body=text,
        client_request_id=client_request_id,
        created_at=datetime.now(timezone.utc),
    )
    db.add(msg)
    # 알림을 넣기 전에 DB 유니크 제약을 확인한다. 동시 재시도 중 진 요청이 여기서
    # 막혀야 회원·트레이너 알림도 한 번만 생성된다.
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        if client_request_id:
            existing = find_message_by_client_request(
                db, trainer_id, member_id, sender, client_request_id
            )
            if existing is not None:
                return _existing_message_out(existing, text=text, viewer=viewer)
        raise

    if sender == "member":
        member_name = db.scalar(select(User.name).where(User.id == member_id))
        notification_service.queue_for_trainer(
            db,
            trainer_id=trainer_id,
            kind=notification_service.TRAINER_MESSAGE_KIND,
            title=f"{member_name or '회원'} 회원의 메시지",
            body=text,
        )
    if notify is not None and sender == "trainer":
        trainer_name = db.scalar(select(User.name).where(User.id == trainer_id))
        notification_service.queue(
            db,
            member_id=member_id,
            kind=notify,
            title=(
                "주간 리포트가 도착했어요"
                if notify == notification_service.WEEKLY_REPORT
                else f"{trainer_name or '트레이너'} 트레이너의 메시지"
            ),
            body=text,
            # 리포트도 대화 스레드로 도착한다 — 별도 리포트 함이 없다.
            category=notification_service.MEMBER_COACH_CHAT,
        )
    db.commit()
    db.refresh(msg)
    out = _chat_out(msg, viewer)
    # 적재는 응답을 다 만든 뒤에 한다(#580). 실패하면 personal_ingest 가 세션을
    # 롤백하는데, 그때 msg 가 만료돼 응답을 못 만들게 되면 적재 실패가 메시지
    # 발신 실패로 번진다. 커밋은 이미 끝났으니 롤백해도 메시지 자체는 남는다.
    personal_ingest.record_chat(
        db, member_id, sender=sender, text=text,
        date=clock.to_seoul(msg.created_at).date().isoformat(),
        source_ref=msg.id,
    )
    return out


def mark_thread_read(db: Session, trainer_id: str, member_id: str, reader: str) -> int:
    """reader 가 상대방이 보낸 미확인 메시지를 읽음 처리. 반환: 읽음 처리된 건수.

    reader='trainer' → 상대(member)가 보낸 미확인 메시지에 read_at 을 채운다.
    reader='member'  → 상대(trainer)가 보낸 미확인 메시지에 read_at 을 채운다.
    """
    other = "member" if reader == "trainer" else "trainer"
    result = db.execute(
        update(ChatMessage)
        .where(
            ChatMessage.trainer_id == trainer_id,
            ChatMessage.member_id == member_id,
            ChatMessage.sender == other,
            ChatMessage.read_at.is_(None),
        )
        .values(read_at=datetime.now(timezone.utc))
    )
    db.commit()
    return result.rowcount or 0


def unread_counts_for_trainer(db: Session, trainer_id: str) -> dict[str, int]:
    """트레이너 기준 회원별 미확인(회원이 보낸 read_at NULL) 메시지 수."""
    rows = db.execute(
        select(ChatMessage.member_id, func.count())
        .where(
            ChatMessage.trainer_id == trainer_id,
            ChatMessage.sender == "member",
            ChatMessage.read_at.is_(None),
        )
        .group_by(ChatMessage.member_id)
    ).all()
    return {member_id: count for member_id, count in rows}


# ---- 회원 활성/휴면 관리 상태 (#707) ----

class ClientLinkDetached(Exception):
    """담당 관계가 이미 해제된 회원이다(라우터가 409 로 변환)."""


def set_client_active(
    db: Session, link: TrainerClient, active: bool
) -> TrainerClientStatusOut:
    """담당 회원을 활성/휴면으로 전환한다.

    `dormant` 만 건드린다 — 담당 링크(`active`)·루틴·기록·식단·채팅은 그대로다.
    휴면 회원도 조회·채팅·루틴 배정이 전부 그대로 되고, 회원 앱에서 코치가
    사라지지도 않는다. 트레이너의 관리 표시일 뿐이다.

    이미 같은 상태면 아무것도 쓰지 않고 그 상태를 돌려준다 — 연타나 재시도가
    상태를 흔들지 않는다(멱등).

    담당이 이미 해제된 링크는 [ClientLinkDetached] 다. 여기서 `dormant` 를
    내려 봐야 로스터는 계속 휴면으로 보이므로(`_roster_active`), 성공으로
    응답하면 화면이 "저장했는데 그대로"가 된다. 담당 재배정은 이 기능의 범위가
    아니다.
    """
    if not link.active:
        raise ClientLinkDetached("담당 관계가 해제된 회원입니다.")
    if link.dormant is not (not active):
        link.dormant = not active
        db.commit()
        db.refresh(link)
    return TrainerClientStatusOut(
        member_id=link.member_id, active=_roster_active(link)
    )


# ---- 루틴 배정 (트레이너/AI → 회원, 양쪽에서 보이는 공유 데이터) ----

def delete_trainer_account(db: Session, trainer: User) -> None:
    """트레이너 탈퇴. 담당 회원에게 알린 뒤 계정을 지운다. (#505)

    **담당 회원이 남아 있어도 막지 않는다.** 막으면 담당이 있는 트레이너는 계정을
    영영 지울 수 없고, 그만두는 사람에게 "회원을 먼저 다 정리하라" 고 요구하는 것은
    현실적이지 않다. 대신 회원이 모르게 사라지지 않도록 알림을 남긴다 — 회원 앱의
    '내 담당 코치'가 어느 날 조용히 비어 있으면 앱이 고장 난 것으로 읽힌다.

    삭제 순서가 중요하다. `trainer_reservations` 는 회원·슬롯·일정을 모두
    **RESTRICT** 로 참조한다. 슬롯과 일정은 트레이너 삭제 시 CASCADE 로 지워지므로,
    예약 행을 먼저 치우지 않으면 그 CASCADE 가 FK 에서 막힌다.

    나머지(프로필·채팅·루틴·일정·슬롯·이력·알림)는 `users.id` CASCADE 가 처리한다.
    상담 요청의 `trainer_id`·`decided_by` 는 SET NULL 이라 요청 이력은 남는다.
    """
    member_ids = list(
        db.scalars(
            select(TrainerClient.member_id).where(
                TrainerClient.trainer_id == trainer.id
            )
        ).all()
    )

    # 이 트레이너의 슬롯에 걸린 예약을 먼저 치운다. 좌석을 되돌릴 필요는 없다 —
    # 슬롯 자체가 함께 사라진다.
    reservations = db.scalars(
        select(TrainerReservation)
        .join(
            TrainerReservationSlot,
            TrainerReservationSlot.id == TrainerReservation.slot_id,
        )
        .where(TrainerReservationSlot.trainer_id == trainer.id)
        .order_by(TrainerReservation.id)
        .with_for_update()
    ).all()
    booked_member_ids = {row.member_id for row in reservations}
    for reservation in reservations:
        db.delete(reservation)
    # RESTRICT 자식을 먼저 비운 뒤에야 트레이너 삭제의 CASCADE 가 성립한다.
    db.flush()

    trainer_name = trainer.name or "트레이너"
    for member_id in member_ids:
        notification_service.queue(
            db,
            member_id=member_id,
            kind=notification_service.TRAINER_MESSAGE,
            # 새 트레이너를 찾는 화면으로 보낸다.
            category=notification_service.MEMBER_CONSULTATION,
            title="담당 트레이너 연결이 해제되었어요",
            body=f"{trainer_name} 트레이너가 서비스를 떠났습니다. 새 트레이너를 찾아보세요.",
        )
    # 예약만 있고 담당은 아닌 회원에게도 알린다 — 잡아 둔 수업이 사라진다.
    for member_id in booked_member_ids - set(member_ids):
        notification_service.queue(
            db,
            member_id=member_id,
            kind=notification_service.TRAINER_MESSAGE,
            category=notification_service.MEMBER_SCHEDULE,
            title="예약한 수업이 취소되었어요",
            body=f"{trainer_name} 트레이너가 서비스를 떠나 예약이 취소되었습니다.",
        )

    db.delete(trainer)
    db.commit()


#: 배정 행의 검토 상태. AI 후보는 pending 으로 들어와 트레이너 판단을 기다린다.
#:
#: 기본이 approved 인 이유는 하위 호환이다 — 이 값이 생기기 전의 배정은 모두
#: 트레이너가 보낸 것이므로 그대로 회원에게 보여야 한다.
ROUTINE_APPROVED = "approved"
ROUTINE_PENDING = "pending"
ROUTINE_DISMISSED = "dismissed"
ROUTINE_STATUSES = frozenset({ROUTINE_APPROVED, ROUTINE_PENDING, ROUTINE_DISMISSED})


def build_routines(
    db: Session,
    member_id: str,
    trainer_id: str | None,
    *,
    for_member: bool = False,
) -> list[RoutineOut]:
    """이 트레이너가 회원에게 배정한 루틴(정렬순).

    [trainer_id] 가 None 이면 트레이너 없이 만들어진 자동 추천을 읽는다 —
    SQLAlchemy 가 `== None` 을 `IS NULL` 로 옮기므로 조건은 그대로 쓴다.

    [for_member] 는 이 목록이 회원에게 가는지를 말한다. 회원용이면 제안의 근거를
    싣지 않는다 — 트레이너의 판단 재료이기 때문이다(#790).

    한 프로그램의 세션들은 `sort_order` 를 연속으로 받으므로 이 정렬만으로
    세션 순서가 지켜진다 — 별도 그룹핑 없이 배열 순서가 곧 프로그램 순서다.
    """
    rows = db.scalars(
        select(TrainerRoutine)
        .where(
            TrainerRoutine.trainer_id == trainer_id,
            TrainerRoutine.member_id == member_id,
            # 검토를 기다리는 후보와 거절된 후보는 '배정된 루틴'이 아니다.
            # 회원 화면은 물론 트레이너의 배정 목록에도 섞이면 안 된다 —
            # 검토는 전용 목록(list_routine_suggestions)에서 한다(#790).
            TrainerRoutine.status == ROUTINE_APPROVED,
        )
        .order_by(TrainerRoutine.sort_order, TrainerRoutine.created_at)
    ).all()
    routine_ids = [row.id for row in rows]
    completed = {}
    if routine_ids:
        completed = {
            row.assigned_routine_id: row
            for row in db.scalars(
                select(ExerciseSession).where(
                    ExerciseSession.assigned_routine_id.in_(routine_ids)
                )
            ).all()
        }
    return [
        _routine_out(
            row, completed.get(row.id), include_evidence=not for_member
        )
        for row in rows
    ]


class RoutineNotFound(Exception):
    """루틴이 없거나 이 트레이너·회원의 것이 아니다."""


def _owned_routine(
    db: Session, trainer_id: str | None, member_id: str, routine_id: str
) -> TrainerRoutine:
    """이 트레이너가 이 회원에게 배정한 루틴. 아니면 [RoutineNotFound]. (#504)

    trainer_id 까지 조건에 넣는 이유: 한 회원이 여러 트레이너를 거쳐 왔을 수 있고,
    그때 남의 배정을 고칠 수 있으면 안 된다. 없는 것과 남의 것을 구분하지 않는
    것도 의도다 — 라우터가 둘 다 404 로 돌려 존재 여부를 드러내지 않는다.
    """
    routine = db.scalar(
        select(TrainerRoutine).where(
            TrainerRoutine.id == routine_id,
            TrainerRoutine.trainer_id == trainer_id,
            TrainerRoutine.member_id == member_id,
        )
    )
    if routine is None:
        raise RoutineNotFound("루틴을 찾을 수 없습니다.")
    return routine


def update_routine(
    db: Session, trainer_id: str, member_id: str, routine_id: str,
    fields: dict,
) -> RoutineOut:
    """배정한 루틴을 고친다. 보낸 필드만 반영한다. (#504)

    **알림을 보내지 않는다.** 배정 알림이 오간 뒤 정정 알림까지 겹치면 회원
    알림함이 같은 루틴으로 채워진다. 회원 앱은 목록을 다시 읽을 때 고쳐진 값을
    본다.

    `sort_order` 는 건드리지 않는다 — 순서 변경은 별도 기능이고(범위 밖),
    수정하다 순서가 밀리면 회원이 보는 목록이 이유 없이 흔들린다.
    """
    routine = _owned_routine(db, trainer_id, member_id, routine_id)
    for field in ("name", "minutes", "type", "reason"):
        if field in fields:
            setattr(routine, field, fields[field])
    db.commit()
    db.refresh(routine)
    completion = db.scalar(
        select(ExerciseSession).where(
            ExerciseSession.assigned_routine_id == routine.id
        )
    )
    return _routine_out(routine, completion)


def delete_routine(
    db: Session, trainer_id: str, member_id: str, routine_id: str
) -> None:
    """배정한 루틴을 철회한다. 회원 앱에서도 사라진다. (#504)

    남은 루틴의 `sort_order` 는 다시 매기지 않는다. 정렬은 값의 크기 순서만
    쓰므로 중간이 비어도 순서가 유지되고, 다시 매기면 그 회원의 모든 루틴 행을
    건드려 동시에 배정 중인 요청과 부딪힌다.

    지난 기록(`routine_history`)은 건드리지 않는다 — 이미 수행한 운동의 이력이지
    배정의 일부가 아니다.
    """
    routine = _owned_routine(db, trainer_id, member_id, routine_id)
    db.delete(routine)
    db.commit()


def _routine_out(
    rt: TrainerRoutine,
    completion: ExerciseSession | None = None,
    *,
    include_evidence: bool = True,
) -> RoutineOut:
    """루틴 한 건의 응답.

    [include_evidence] 를 끄면 근거를 싣지 않는다 — 회원에게 가는 응답이다.
    근거(`최근 근력운동 비중 높음`)는 트레이너가 승인 여부를 판단하는 재료이지
    회원이 읽을 문구가 아니다. 화면이 감추는 것과 응답에 담지 않는 것은 다르다
    (#790).
    """
    return RoutineOut(
        id=rt.id, name=rt.name, minutes=rt.minutes, type=rt.type,
        reason=rt.reason, source=rt.source,
        program_name=rt.program_name,
        session_name=rt.session_name,
        session_order=rt.session_order,
        exercises=draft_exercises(rt.exercises_json),
        evidence=(
            suggestion_evidence(rt.evidence_json) if include_evidence else []
        ),
        completed=completion is not None,
        completed_at=completion.completed_at if completion is not None else None,
        completed_minutes=completion.minutes if completion is not None else None,
        completed_intensity=completion.intensity if completion is not None else None,
        member_note=completion.member_note if completion is not None else "",
        trainer_feedback=(
            completion.trainer_feedback if completion is not None else ""
        ),
    )


_ROUTINE_EXERCISE_TYPES = {
    "걷기": "walking",
    "유산소": "cardio",
    "근력": "strength",
    "요가": "yoga",
    "스트레칭": "stretching",
    "기타": "other",
}



# ─────────────────────────────────── AI 개인운동 제안 검토 ───────────────────

class RoutineAlreadyReviewed(Exception):
    """이미 승인/거절된 제안을 다시 검토하려 했다."""


def create_routine_suggestion(
    db: Session,
    trainer_id: str,
    member_id: str,
    *,
    name: str,
    minutes: int,
    type_: str,
    reason: str,
    evidence: Sequence[str] | None = None,
    client_request_id: str | None = None,
) -> RoutineOut:
    """AI 개인운동 후보를 검토 대기(pending) 로 만든다.

    [assign_routine] 과 나눠 둔 이유: 배정은 회원에게 곧바로 닿는 행동이고 알림도
    나가지만, 후보는 아직 아무에게도 닿지 않는다. 알림은 승인 시점에 나간다 —
    트레이너가 보지도 않은 운동으로 회원이 먼저 알림을 받으면 안 된다(#790).
    """
    if client_request_id:
        existing = find_routine_by_client_request(
            db, trainer_id, member_id, client_request_id
        )
        if existing is not None:
            return _routine_out(existing)

    max_order = db.scalar(
        select(func.max(TrainerRoutine.sort_order)).where(
            TrainerRoutine.trainer_id == trainer_id,
            TrainerRoutine.member_id == member_id,
        )
    )
    rt = TrainerRoutine(
        id=f"rt-{uuid.uuid4().hex[:12]}",
        trainer_id=trainer_id,
        member_id=member_id,
        name=name,
        minutes=minutes,
        type=type_,
        reason=reason,
        source="ai",
        status=ROUTINE_PENDING,
        sort_order=(max_order or 0) + 1,
        evidence_json=json.dumps(list(evidence or []), ensure_ascii=False),
        client_request_id=client_request_id,
        created_at=clock.now(),
    )
    db.add(rt)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        if client_request_id:
            existing = find_routine_by_client_request(
                db, trainer_id, member_id, client_request_id
            )
            if existing is not None:
                return _routine_out(existing)
        raise
    db.commit()
    db.refresh(rt)
    return _routine_out(rt)


def list_routine_suggestions(
    db: Session, trainer_id: str, member_id: str
) -> list[RoutineOut]:
    """검토를 기다리는 AI 개인운동 제안. 승인·거절한 것은 빠진다.

    조회 자리에서 그날 후보를 준비한다(`routine_suggestion_service`). 트레이너가
    회원을 골라 생성을 요청해야만 후보가 생기면 관리 부담이 줄지 않는다 — AI 가
    먼저 준비하고 트레이너는 판단만 하는 것이 이 기능의 요구다(#790). 회원 조회가
    자동 추천을 준비하는 것(`build_member_routines`)과 같은 방식이다.
    """
    routine_suggestion_service.ensure_suggestions(db, trainer_id, member_id)
    rows = db.scalars(
        select(TrainerRoutine)
        .where(
            TrainerRoutine.trainer_id == trainer_id,
            TrainerRoutine.member_id == member_id,
            TrainerRoutine.status == ROUTINE_PENDING,
        )
        .order_by(TrainerRoutine.sort_order, TrainerRoutine.created_at)
    ).all()
    return [_routine_out(row) for row in rows]


def _pending_suggestion(
    db: Session, trainer_id: str, suggestion_id: str
) -> TrainerRoutine:
    """검토할 수 있는 제안 하나. 남의 것·없는 것은 [RoutineNotFound].

    이미 처리된 제안은 [RoutineAlreadyReviewed] 로 나눈다 — 없는 것과 같은 답을
    주면, 두 번 눌렀을 때 트레이너가 "사라졌다" 로 읽는다. 실제로는 이미 반영됐다.
    """
    row = db.scalar(
        select(TrainerRoutine).where(
            TrainerRoutine.id == suggestion_id,
            TrainerRoutine.trainer_id == trainer_id,
        )
    )
    if row is None:
        raise RoutineNotFound("제안을 찾을 수 없습니다.")
    if row.status != ROUTINE_PENDING:
        raise RoutineAlreadyReviewed("이미 검토한 제안입니다.")
    return row


def approve_routine_suggestion(
    db: Session,
    trainer_id: str,
    suggestion_id: str,
    *,
    name: str | None = None,
    minutes: int | None = None,
    type_: str | None = None,
    reason: str | None = None,
) -> RoutineOut:
    """제안을 승인해 회원에게 배정한다. 준 값이 있으면 그것으로 고쳐서 승인한다.

    새 행을 만들지 않고 이 행의 상태를 바꾼다. 후보와 배정이 같은 행이라
    회원 조회·완료 처리·프로그램 묶음이 지금 쓰는 경로를 그대로 지난다.
    """
    row = _pending_suggestion(db, trainer_id, suggestion_id)
    if name is not None:
        row.name = name
    if minutes is not None:
        row.minutes = minutes
    if type_ is not None:
        row.type = type_
    if reason is not None:
        row.reason = reason
    row.status = ROUTINE_APPROVED
    row.reviewed_at = clock.now()
    row.reviewed_by = trainer_id

    # 알림은 여기서 나간다 — 회원이 볼 수 있게 된 시점이 곧 알릴 시점이다.
    notification_service.queue(
        db,
        member_id=row.member_id,
        kind=notification_service.EXERCISE,
        category=notification_service.MEMBER_ROUTINE,
        title="새 운동 루틴이 배정되었어요",
        body=f"{row.name} · {row.minutes}분",
    )
    db.commit()
    db.refresh(row)
    return _routine_out(row)


def dismiss_routine_suggestion(
    db: Session, trainer_id: str, suggestion_id: str
) -> RoutineOut:
    """제안을 추천하지 않기로 한다. 회원 배정도 알림도 만들지 않는다."""
    row = _pending_suggestion(db, trainer_id, suggestion_id)
    row.status = ROUTINE_DISMISSED
    row.reviewed_at = clock.now()
    row.reviewed_by = trainer_id
    db.commit()
    db.refresh(row)
    return _routine_out(row)


def complete_assigned_routine(
    db: Session,
    trainer_id: str | None,
    member_id: str,
    routine_id: str,
    *,
    minutes: int,
    intensity: str,
    member_note: str,
) -> RoutineOut:
    """배정 하나를 회원 운동 기록 한 건으로 완료한다.

    `assigned_routine_id` unique 제약이 더블 탭·재전송을 같은 기록으로
    모은다. 이름은 스냅샷이라 이후 배정 수정·철회에 흔들리지 않는다.
    """
    routine = _owned_routine(db, trainer_id, member_id, routine_id)
    # 승인되지 않은 후보는 회원에게 보이지도 않는다. id 를 알아내 직접 호출해도
    # 완료로 넘어가지 않게 여기서 막는다 — 조회만 거르면 경로가 하나 남는다(#790).
    if routine.status != ROUTINE_APPROVED:
        raise RoutineNotFound("루틴을 찾을 수 없습니다.")
    existing = db.scalar(
        select(ExerciseSession).where(
            ExerciseSession.assigned_routine_id == routine_id
        )
    )
    if existing is not None:
        return _routine_out(routine, existing)

    completed_at = clock.now()
    exercise_type = _ROUTINE_EXERCISE_TYPES.get(routine.type, "other")
    row = ExerciseSession(
        id=f"assigned-ex-{uuid.uuid4().hex[:12]}",
        user_id=member_id,
        week_start=exercise_service.monday_of_str(completed_at.date().isoformat()),
        day_label=exercise_service.weekday_label_of(completed_at.date().isoformat()),
        type=exercise_type,
        minutes=minutes,
        calories=exercise_service.estimate_calories(
            exercise_type, minutes, intensity
        ),
        intensity=intensity,
        source="assigned_routine",
        assigned_routine_id=routine.id,
        assigned_trainer_id=trainer_id,
        assigned_routine_name=routine.name,
        member_note=member_note.strip(),
        completed_at=completed_at,
    )
    db.add(row)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = db.scalar(
            select(ExerciseSession).where(
                ExerciseSession.assigned_routine_id == routine_id
            )
        )
        if existing is None:
            raise
        return _routine_out(routine, existing)
    db.refresh(row)
    personal_ingest.refresh_exercise(db, member_id, session_id=row.id)
    return _routine_out(routine, row)


def update_assigned_routine_feedback(
    db: Session,
    trainer_id: str,
    member_id: str,
    history_id: str,
    feedback: str,
) -> RoutineHistoryOut:
    """활성 담당 관계가 확인된 트레이너가 자신이 배정한 기록에 피드백한다.

    API 계층은 현재 활성 담당 관계를 먼저 확인하고, 여기서는 수행 스냅샷의
    배정 트레이너까지 일치하는지 추가로 검증한다(#638).
    """
    row = db.scalar(
        select(ExerciseSession).where(
            ExerciseSession.id == history_id,
            ExerciseSession.user_id == member_id,
            ExerciseSession.source == "assigned_routine",
            ExerciseSession.assigned_trainer_id == trainer_id,
        )
    )
    if row is None:
        raise RoutineNotFound("배정 루틴 수행 기록을 찾을 수 없습니다.")
    row.trainer_feedback = feedback.strip()
    db.commit()
    db.refresh(row)
    return _assigned_history_out(row)


def _assigned_history_out(row: ExerciseSession) -> RoutineHistoryOut:
    """배정 루틴 수행을 조회·수정 응답에서 공유하는 이력 계약으로 변환한다."""
    completed_at = row.completed_at or row.created_at
    day = clock.to_seoul(completed_at).date().isoformat()
    return RoutineHistoryOut(
        id=row.id,
        date_label=history_date_label(day),
        label=row.assigned_routine_name or "배정 루틴 수행",
        completion_rate=100,
        exercises=[
            f"{row.assigned_routine_name or row.type} · {row.minutes}분 · {row.intensity}"
        ],
        client_feedback=row.member_note,
        trainer_note=row.trainer_feedback,
        assigned_routine_id=row.assigned_routine_id,
        completed_at=completed_at,
    )


def find_routine_by_client_request(
    db: Session, trainer_id: str, member_id: str, client_request_id: str
) -> TrainerRoutine | None:
    return db.scalar(
        select(TrainerRoutine).where(
            TrainerRoutine.trainer_id == trainer_id,
            TrainerRoutine.member_id == member_id,
            TrainerRoutine.client_request_id == client_request_id,
        )
    )


def assign_routine(
    db: Session, trainer_id: str, member_id: str,
    name: str, minutes: int, type_: str, reason: str, source: str,
    client_request_id: str | None = None,
) -> RoutineOut:
    """회원에게 루틴 배정. 로스터 last_routine 은 build_roster 가 최신 루틴을 읽어 반영.

    [client_request_id] 가 오면 그 전송 시도에 대해 멱등하다. 같은 키로 다시
    호출하면 새로 만들지 않고 먼저 저장된 배정을 그대로 돌려준다 — 전송 도중
    끊겨 클라이언트가 재시도해도 회원에게 루틴이 두 번 배정되지 않는다(#581).
    """
    if client_request_id:
        existing = find_routine_by_client_request(
            db, trainer_id, member_id, client_request_id
        )
        if existing is not None:
            return _routine_out(existing)

    # 이 회원 루틴들의 현재 최대 sort_order + 1 로 끝에 붙인다. timestamp 방식은 시드(0..n)와
    # 의미가 섞이고, 같은 초에 배정된 둘은 순서가 비결정적이었다(리뷰 #279).
    max_order = db.scalar(
        select(func.max(TrainerRoutine.sort_order))
        .where(TrainerRoutine.trainer_id == trainer_id, TrainerRoutine.member_id == member_id)
    )
    rt = TrainerRoutine(
        id=f"rt-{uuid.uuid4().hex[:12]}",
        trainer_id=trainer_id,
        member_id=member_id,
        name=name,
        minutes=minutes,
        type=type_,
        reason=reason,
        source=source,
        sort_order=(max_order or 0) + 1,
        client_request_id=client_request_id,
        created_at=datetime.now(timezone.utc),
    )
    db.add(rt)
    # 알림을 붙이기 **전에** 삽입을 flush 한다. 같은 키의 동시 요청 둘이 나란히 위
    # 조회를 통과하면 유니크 제약이 한쪽을 막는데, 그 충돌을 여기서 잡아야 진 쪽이
    # 알림까지 중복으로 쌓지 않는다(회원이 같은 배정 알림을 두 번 받지 않는다).
    # queue() 는 내부 조회를 하므로 그때 autoflush 로 터지면 이 지점을 지나친다.
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        if client_request_id:
            existing = find_routine_by_client_request(
                db, trainer_id, member_id, client_request_id
            )
            if existing is not None:
                return _routine_out(existing)
        raise

    # 배정은 회원이 앱을 열기 전에는 알 수 없는 변화다(#489).
    notification_service.queue(
        db,
        member_id=member_id,
        kind=notification_service.EXERCISE,
        category=notification_service.MEMBER_ROUTINE,
        title="새 운동 루틴이 배정되었어요",
        body=f"{name} · {minutes}분",
    )
    db.commit()
    db.refresh(rt)
    return _routine_out(rt)


def _session_summary(
    exercises: Sequence[ProgramDraftExercise],
) -> tuple[int, str, str]:
    """세션 하나를 루틴 한 건의 (분, 유형, 출처)로 요약한다. (#709)

    트레이너 웹이 단일 세션을 배정할 때 쓰던 규칙과 같다 — 분은 각 운동의
    `duration` 합, 유형은 가장 많은 유형, 출처는 AI 제안이 하나라도 있으면
    'ai'. 규칙을 서버로 옮긴 것은 세션이 여러 개가 되면서 클라이언트마다
    다르게 접히는 것을 막기 위해서다.
    """
    minutes = 0
    counts: dict[str, int] = {}
    has_ai = False
    for exercise in exercises:
        try:
            minutes += int(exercise.duration.strip())
        except ValueError:
            pass
        counts[exercise.type] = counts.get(exercise.type, 0) + 1
        if exercise.source == "ai":
            has_ai = True
    type_ = max(counts, key=lambda t: counts[t]) if counts else "근력"
    return minutes, type_, ("ai" if has_ai else "trainer")


def _program_request_key(base: str, index: int) -> str:
    """세션별 멱등키. 프로그램 전체가 한 번의 전송 시도이므로 같은 base 를 쓴다.

    세션마다 키를 나누는 이유는 `(trainer, member, client_request_id)` 유니크
    제약 때문이다 — 같은 키로 여러 행을 만들 수 없다.
    """
    return f"{base}#{index}"


def assign_program(
    db: Session, trainer_id: str, member_id: str, *,
    name: str,
    sessions: Sequence[ProgramDraftSession],
    client_request_id: str | None = None,
) -> list[RoutineOut]:
    """다중 세션 프로그램을 회원에게 배정한다. 세션 하나가 루틴 한 건이 된다. (#709)

    세션이 하나뿐이면 예전 단일 배정과 같은 모양이다 — 루틴 이름은 프로그램
    이름이고 `session_name` 이 비어 회원 화면에 없던 세션 라벨이 생기지 않는다.
    세션이 여럿이면 루틴 이름이 세션 이름이 되고 `program_name` 이 묶는다.

    [client_request_id] 가 오면 **프로그램 전체**에 대해 멱등하다. 재시도에 같은
    키를 다시 보내면 먼저 배정된 세션들을 그대로 돌려준다 — 중간까지 저장된
    상태에서 재시도해 세션이 반쯤 겹치는 일이 없다.

    알림은 프로그램당 한 번이다. 세션마다 보내면 회원 알림함이 한 번의 배정으로
    가득 찬다.
    """
    if client_request_id:
        existing = db.scalars(
            select(TrainerRoutine)
            .where(
                TrainerRoutine.trainer_id == trainer_id,
                TrainerRoutine.member_id == member_id,
                TrainerRoutine.client_request_id.in_(
                    [
                        _program_request_key(client_request_id, index)
                        for index in range(len(sessions))
                    ]
                ),
            )
            .order_by(TrainerRoutine.session_order)
        ).all()
        if existing:
            return [_routine_out(rt) for rt in existing]

    multi = len(sessions) > 1
    max_order = db.scalar(
        select(func.max(TrainerRoutine.sort_order)).where(
            TrainerRoutine.trainer_id == trainer_id,
            TrainerRoutine.member_id == member_id,
        )
    ) or 0
    now = datetime.now(timezone.utc)
    created: list[TrainerRoutine] = []
    for index, session in enumerate(sessions):
        minutes, type_, source = _session_summary(session.exercises)
        rt = TrainerRoutine(
            id=f"rt-{uuid.uuid4().hex[:12]}",
            trainer_id=trainer_id,
            member_id=member_id,
            name=(session.name or name) if multi else name,
            minutes=minutes,
            type=type_,
            reason=", ".join(e.name for e in session.exercises)[:200],
            source=source,
            program_name=name if multi else "",
            session_name=session.name if multi else "",
            session_order=index,
            exercises_json=json.dumps(
                [e.model_dump() for e in session.exercises], ensure_ascii=False
            ),
            sort_order=max_order + index + 1,
            client_request_id=(
                _program_request_key(client_request_id, index)
                if client_request_id
                else None
            ),
            created_at=now,
        )
        db.add(rt)
        created.append(rt)

    # 단일 배정과 같은 이유로 알림보다 먼저 flush 한다 — 동시 요청이 유니크
    # 제약에 걸리면 진 쪽이 알림까지 쌓지 않아야 한다.
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        if client_request_id:
            existing = db.scalars(
                select(TrainerRoutine)
                .where(
                    TrainerRoutine.trainer_id == trainer_id,
                    TrainerRoutine.member_id == member_id,
                    TrainerRoutine.client_request_id.in_(
                        [
                            _program_request_key(client_request_id, index)
                            for index in range(len(sessions))
                        ]
                    ),
                )
                .order_by(TrainerRoutine.session_order)
            ).all()
            if existing:
                return [_routine_out(rt) for rt in existing]
        raise

    total_minutes = sum(rt.minutes for rt in created)
    notification_service.queue(
        db,
        member_id=member_id,
        kind=notification_service.EXERCISE,
        category=notification_service.MEMBER_ROUTINE,
        title="새 운동 루틴이 배정되었어요",
        body=(
            f"{name} · 세션 {len(created)}개 · {total_minutes}분"
            if multi
            else f"{name} · {total_minutes}분"
        ),
    )
    db.commit()
    for rt in created:
        db.refresh(rt)
    return [_routine_out(rt) for rt in created]


# ---- 회원별 트레이너 메모 (#706) ----

class MemoNotFound(Exception):
    """그 트레이너·회원 쌍에 그 id 의 메모가 없다(라우터가 404 로 변환)."""


def _memo_out(memo: TrainerClientMemo) -> TrainerMemoOut:
    return TrainerMemoOut(
        id=memo.id,
        body=memo.body,
        source=memo.source,
        insight_id=memo.insight_id,
        insight_kind=memo.insight_kind,
        created_at=memo.created_at,
        updated_at=memo.updated_at,
    )


#: 메모 목록이 한 번에 내려주는 최대 건수. 메모는 지워지지 않고 쌓이기만 하는
#: 데이터라, 오래 쓴 계정에서 응답이 무한정 커지는 것을 막는다(알림함과 같은 이유).
_MEMO_LIMIT = 100


def build_memos(db: Session, trainer_id: str, member_id: str) -> list[TrainerMemoOut]:
    """담당 회원에 대해 내가 남긴 메모(최신 먼저, 최대 [_MEMO_LIMIT]건).

    직접 쓴 메모와 채팅 인사이트 메모를 한 목록으로 돌려준다 — 회원 상세가
    출처와 무관하게 "이 회원에 대해 남긴 기록"을 한 곳에서 보여 준다.

    같은 시각에 만들어진 둘의 순서가 흔들리지 않게 id 로 tie-break 한다.
    """
    rows = db.scalars(
        select(TrainerClientMemo)
        .where(
            TrainerClientMemo.trainer_id == trainer_id,
            TrainerClientMemo.member_id == member_id,
        )
        .order_by(TrainerClientMemo.created_at.desc(), TrainerClientMemo.id.desc())
        .limit(_MEMO_LIMIT)
    ).all()
    return [_memo_out(m) for m in rows]


def find_memo_by_insight(
    db: Session, trainer_id: str, member_id: str, insight_id: str
) -> TrainerClientMemo | None:
    return db.scalar(
        select(TrainerClientMemo).where(
            TrainerClientMemo.trainer_id == trainer_id,
            TrainerClientMemo.member_id == member_id,
            TrainerClientMemo.insight_id == insight_id,
        )
    )


def create_memo(
    db: Session, trainer_id: str, member_id: str,
    body: str, source: str = "trainer",
    insight_id: str | None = None, insight_kind: str = "",
) -> TrainerMemoOut:
    """회원 메모를 남긴다.

    [insight_id] 가 오면 그 인사이트에 대해 멱등하다 — 채팅에서 같은 신호를 다시
    저장해도 새 메모를 만들지 않고 먼저 저장된 메모를 그대로 돌려준다. 로컬
    저장 시절 `insightId` 로 중복을 막던 의미를 서버에서 그대로 유지한다.
    """
    if insight_id:
        existing = find_memo_by_insight(db, trainer_id, member_id, insight_id)
        if existing is not None:
            return _memo_out(existing)

    now = datetime.now(timezone.utc)
    memo = TrainerClientMemo(
        id=f"memo-{uuid.uuid4().hex[:12]}",
        trainer_id=trainer_id,
        member_id=member_id,
        body=body,
        source=source,
        insight_id=insight_id,
        insight_kind=insight_kind,
        created_at=now,
        updated_at=now,
    )
    db.add(memo)
    # 같은 insight_id 로 동시에 들어온 두 요청이 나란히 위 조회를 통과하면 유니크
    # 제약이 한쪽을 막는다. 그 충돌을 여기서 잡아 먼저 저장된 쪽을 돌려준다 —
    # 클라이언트 입장에서는 어느 쪽이 이겼든 "이미 저장된 그 메모"가 나온다.
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        if insight_id:
            existing = find_memo_by_insight(db, trainer_id, member_id, insight_id)
            if existing is not None:
                return _memo_out(existing)
        raise
    db.commit()
    db.refresh(memo)
    return _memo_out(memo)


def _owned_memo(
    db: Session, trainer_id: str, member_id: str, memo_id: str
) -> TrainerClientMemo:
    """내가 이 회원에 대해 남긴 메모만 집는다.

    남의 메모와 없는 메모를 똑같이 다룬다 — 존재 여부를 드러내면 id 를 훑는 것만
    으로 다른 트레이너가 메모를 남겼다는 사실을 알 수 있다.
    """
    memo = db.scalar(
        select(TrainerClientMemo).where(
            TrainerClientMemo.id == memo_id,
            TrainerClientMemo.trainer_id == trainer_id,
            TrainerClientMemo.member_id == member_id,
        )
    )
    if memo is None:
        raise MemoNotFound("메모를 찾을 수 없습니다.")
    return memo


def update_memo(
    db: Session, trainer_id: str, member_id: str, memo_id: str, fields: dict
) -> TrainerMemoOut:
    """메모 본문을 고친다. 출처(`source`/`insight_id`)는 그대로 둔다."""
    memo = _owned_memo(db, trainer_id, member_id, memo_id)
    if "body" in fields:
        memo.body = fields["body"]
    memo.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(memo)
    return _memo_out(memo)


def delete_memo(db: Session, trainer_id: str, member_id: str, memo_id: str) -> None:
    """메모를 지운다.

    비활성 플래그를 두지 않고 실제로 지운다 — 트레이너 혼자 보는 개인 메모라
    '지웠는데 서버에 남아 있는' 상태가 UX 상 의미가 없다.
    """
    memo = _owned_memo(db, trainer_id, member_id, memo_id)
    db.delete(memo)
    db.commit()


# ---- 프로그램 초안 (#708) ----

class ProgramDraftNotFound(Exception):
    """그 트레이너에게 그 id 의 초안이 없다(라우터가 404 로 변환)."""


#: 근거 문구 하나의 길이 상한. 스키마
#: (`RoutineSuggestionCreateRequest.evidence`)와 같은 값이다 — 예전 행이나 손으로
#: 고친 값이 화면 한 줄을 넘기지 않게 읽는 쪽에서도 자른다.
_EVIDENCE_MAX_LEN = 40

#: 한 제안이 들고 다니는 근거 수 상한. 스키마와 같은 값이다.
_EVIDENCE_MAX_ITEMS = 4


def suggestion_evidence(evidence_json: str) -> list[str]:
    """제안의 근거 문구를 읽는다. 깨진 값이면 빈 목록이다. (#790)

    `draft_exercises` 와 같은 이유로 관대하다 — 근거 하나가 이상해서 제안 카드
    자체가 안 뜨면, 트레이너는 검토할 것이 있는지조차 알 수 없다.
    """
    try:
        raw = json.loads(evidence_json) if evidence_json else []
    except json.JSONDecodeError:
        return []
    if not isinstance(raw, list):
        return []
    return [
        item.strip()[:_EVIDENCE_MAX_LEN]
        for item in raw[:_EVIDENCE_MAX_ITEMS]
        if isinstance(item, str) and item.strip()
    ]


def draft_exercises(exercises_json: str) -> list[ProgramDraftExercise]:
    """저장된 운동 목록을 읽는다. 깨진 항목이 목록 전체를 막지 않는다.

    스키마가 거른 값만 저장되지만, 손으로 고쳤거나 예전 형식이 남은 항목 하나
    때문에 초안을 아예 못 여는 편이 더 나쁘다 — 읽을 수 있는 항목만 돌려준다.
    """
    try:
        raw = json.loads(exercises_json) if exercises_json else []
    except json.JSONDecodeError:
        return []
    return _validated_exercises(raw)


def _validated_exercises(raw: object) -> list[ProgramDraftExercise]:
    if not isinstance(raw, list):
        return []
    out: list[ProgramDraftExercise] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        try:
            out.append(ProgramDraftExercise.model_validate(item))
        except ValidationError:
            continue
    return out


def draft_sessions(sessions_json: str) -> list[ProgramDraftSession]:
    """저장된 세션 목록을 순서 그대로 읽는다. (#709)

    운동과 같은 이유로 관대하다 — 읽을 수 없는 세션 하나가 프로그램 전체를
    못 열게 만들면 안 된다.
    """
    try:
        raw = json.loads(sessions_json) if sessions_json else []
    except json.JSONDecodeError:
        return []
    if not isinstance(raw, list):
        return []
    out: list[ProgramDraftSession] = []
    for index, item in enumerate(raw):
        if not isinstance(item, dict):
            continue
        out.append(
            ProgramDraftSession(
                id=str(item.get("id") or f"session-{index + 1}"),
                name=str(item.get("name") or ""),
                exercises=_validated_exercises(item.get("exercises")),
            )
        )
    return out


def dump_draft_sessions(sessions: Sequence[ProgramDraftSession]) -> str:
    return json.dumps(
        [session.model_dump() for session in sessions], ensure_ascii=False
    )


def _draft_out(draft: TrainerProgramDraft) -> TrainerProgramDraftOut:
    return TrainerProgramDraftOut(
        id=draft.id,
        name=draft.name,
        goal=draft.goal,
        period=draft.period,
        memo=draft.memo,
        sessions=draft_sessions(draft.sessions_json),
        created_at=draft.created_at,
        updated_at=draft.updated_at,
    )


#: 목록이 한 번에 내려주는 최대 초안 수. 초안은 지우지 않으면 쌓이기만 한다.
_PROGRAM_DRAFT_LIMIT = 100


def build_program_drafts(
    db: Session, trainer_id: str
) -> list[TrainerProgramDraftSummary]:
    """내가 저장한 프로그램 초안 목록(최근 수정 먼저).

    세션·운동 구성은 싣지 않는다 — 목록은 "무엇을 저장해 뒀나"만 보여 주고,
    편집기로 불러올 때 상세를 따로 읽는다.
    """
    rows = db.scalars(
        select(TrainerProgramDraft)
        .where(TrainerProgramDraft.trainer_id == trainer_id)
        .order_by(
            TrainerProgramDraft.updated_at.desc(), TrainerProgramDraft.id.desc()
        )
        .limit(_PROGRAM_DRAFT_LIMIT)
    ).all()
    out: list[TrainerProgramDraftSummary] = []
    for d in rows:
        sessions = draft_sessions(d.sessions_json)
        out.append(
            TrainerProgramDraftSummary(
                id=d.id,
                name=d.name,
                goal=d.goal,
                period=d.period,
                session_count=len(sessions),
                exercise_count=sum(len(s.exercises) for s in sessions),
                updated_at=d.updated_at,
            )
        )
    return out


def _owned_draft(
    db: Session, trainer_id: str, draft_id: str
) -> TrainerProgramDraft:
    """내가 저장한 초안만 집는다. 남의 초안과 없는 초안은 똑같이 404 다."""
    draft = db.scalar(
        select(TrainerProgramDraft).where(
            TrainerProgramDraft.id == draft_id,
            TrainerProgramDraft.trainer_id == trainer_id,
        )
    )
    if draft is None:
        raise ProgramDraftNotFound("저장된 프로그램을 찾을 수 없습니다.")
    return draft


def get_program_draft(
    db: Session, trainer_id: str, draft_id: str
) -> TrainerProgramDraftOut:
    return _draft_out(_owned_draft(db, trainer_id, draft_id))


def create_program_draft(
    db: Session, trainer_id: str, *,
    name: str, goal: str, period: str, memo: str,
    sessions: Sequence[ProgramDraftSession],
) -> TrainerProgramDraftOut:
    """프로그램 초안을 저장한다. 세션은 받은 순서 그대로 남는다."""
    now = datetime.now(timezone.utc)
    draft = TrainerProgramDraft(
        id=f"pgm-{uuid.uuid4().hex[:12]}",
        trainer_id=trainer_id,
        name=name,
        goal=goal,
        period=period,
        memo=memo,
        sessions_json=dump_draft_sessions(sessions),
        created_at=now,
        updated_at=now,
    )
    db.add(draft)
    db.commit()
    db.refresh(draft)
    return _draft_out(draft)


def update_program_draft(
    db: Session, trainer_id: str, draft_id: str, fields: dict
) -> TrainerProgramDraftOut:
    """저장된 초안을 고친다. 보낸 필드만 반영한다.

    `sessions` 는 통째로 교체한다 — 편집기가 항목 단위 diff 가 아니라 현재
    구성 전체를 들고 있다.
    """
    draft = _owned_draft(db, trainer_id, draft_id)
    for field in ("name", "goal", "period", "memo"):
        if field in fields:
            setattr(draft, field, fields[field])
    if "sessions" in fields:
        draft.sessions_json = dump_draft_sessions(
            [
                item
                if isinstance(item, ProgramDraftSession)
                else ProgramDraftSession.model_validate(item)
                for item in fields["sessions"]
            ]
        )
    draft.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(draft)
    return _draft_out(draft)


def delete_program_draft(db: Session, trainer_id: str, draft_id: str) -> None:
    """저장된 초안을 지운다. 배정된 루틴·스케줄은 건드리지 않는다 —
    초안에서 만들어진 뒤로는 서로 독립적인 데이터다."""
    draft = _owned_draft(db, trainer_id, draft_id)
    db.delete(draft)
    db.commit()


# ---- 스케줄 (트레이너 타임라인 + 예약→수업→기록 완료 루프) ----

class ScheduleError(ValueError):
    """스케줄 도메인 오류(라우터가 400 으로 변환)."""


class ScheduleConflict(Exception):
    """완료 세션 수정 등 상태 충돌(라우터가 409 로 변환)."""


def _program_items(program_json: str) -> list[ProgramItem]:
    try:
        raw = json.loads(program_json) if program_json else []
    except json.JSONDecodeError:
        raw = []
    out: list[ProgramItem] = []
    for m in raw:
        if not isinstance(m, dict):
            continue
        out.append(ProgramItem(
            name=str(m.get("name", "") or "-"),
            sets=int(m.get("sets", 0) or 0),
            reps=str(m.get("reps", "")),
            weight=str(m.get("weight", "")),
            # 이 키가 없는 예전 행은 세션 구분 없는 목록으로 그대로 읽힌다(#709).
            session=str(m.get("session", "") or ""),
        ))
    return out


def _schedule_out(s: TrainerSchedule) -> ScheduleSessionOut:
    return ScheduleSessionOut(
        id=s.id, date=s.date, time=s.time, client_name=s.client_name,
        type=s.type, duration_minutes=s.duration_minutes, status=s.status,
        note=s.note, program=_program_items(s.program_json),
        program_sent=s.program_sent_at is not None,
    )


def build_schedule(db: Session, trainer_id: str, day: str) -> list[ScheduleSessionOut]:
    """하루 타임라인(시간순, 공백 포함)."""
    return build_schedule_range(db, trainer_id, day, day)


def build_client_schedule(
    db: Session, trainer_id: str, member_id: str
) -> list[ScheduleSessionOut]:
    """한 고객의 전체 세션(날짜→시간 순), 기간 제한 없이.

    고객 상세의 루틴 이력이 쓴다. 넓은 날짜 구간으로 흉내내면 그 구간보다
    오래된 기록이 조용히 빠지고, 화면은 그걸 '기록 없음'으로 읽는다.
    행 수는 트레이너-고객 한 쌍의 세션 수라 자연히 작다.
    """
    rows = db.scalars(
        select(TrainerSchedule)
        .where(
            TrainerSchedule.trainer_id == trainer_id,
            TrainerSchedule.member_id == member_id,
        )
        .order_by(
            TrainerSchedule.date, TrainerSchedule.time, TrainerSchedule.sort_order
        )
    ).all()
    return [_schedule_out(s) for s in rows]


def build_schedule_range(
    db: Session,
    trainer_id: str,
    from_day: str,
    to_day: str,
    member_id: str | None = None,
) -> list[ScheduleSessionOut]:
    """[from_day, to_day] 구간의 슬롯을 날짜→시간 순으로.

    주 캘린더가 7일치를 한 번에 읽기 위한 것 — 하루짜리 조회를 요일마다
    반복하면 요청이 7배가 된다. `YYYY-MM-DD` 는 사전식 정렬이 곧 날짜순이라
    문자열 범위 비교로 충분하다.

    [member_id] 를 주면 그 고객의 세션만 (공백 슬롯은 자연히 빠진다 —
    배정된 회원이 없으므로).
    """
    conditions = [
        TrainerSchedule.trainer_id == trainer_id,
        TrainerSchedule.date >= from_day,
        TrainerSchedule.date <= to_day,
    ]
    if member_id is not None:
        conditions.append(TrainerSchedule.member_id == member_id)
    rows = db.scalars(
        select(TrainerSchedule)
        .where(*conditions)
        .order_by(
            TrainerSchedule.date, TrainerSchedule.time, TrainerSchedule.sort_order
        )
    ).all()
    return [_schedule_out(s) for s in rows]


#: booked_dates 조회 하한(일). 주간 스트립 도트용이라 과거 전체가 필요없다 — 시간이 갈수록
#: 결과가 무한정 커지는 것을 막는다(리뷰 #280). 문자열 날짜(YYYY-MM-DD)는 사전식 비교 가능.
_BOOKED_DATES_WINDOW_DAYS = 90


def booked_dates(db: Session, trainer_id: str) -> list[str]:
    """예약이 있는(공백 아닌) 날짜 목록 — 주간 스트립 도트용(최근 90일 이후)."""
    cutoff = (_today() - timedelta(days=_BOOKED_DATES_WINDOW_DAYS)).isoformat()
    rows = db.scalars(
        select(TrainerSchedule.date)
        .where(
            TrainerSchedule.trainer_id == trainer_id,
            TrainerSchedule.status != "공백",
            TrainerSchedule.date >= cutoff,
        )
        .distinct()
    ).all()
    return sorted(rows)


def _get_owned_session(db: Session, trainer_id: str, session_id: str) -> TrainerSchedule | None:
    s = db.get(TrainerSchedule, session_id)
    if s is None or s.trainer_id != trainer_id:
        return None
    return s


def _is_reservation_schedule(db: Session, session_id: str) -> bool:
    """Return whether a member reservation owns this schedule row."""
    return db.scalar(
        select(TrainerReservation.id)
        .where(TrainerReservation.schedule_id == session_id)
        .limit(1)
    ) is not None


def _dump_program(
    program: Sequence[ProgramItem | Mapping[str, object]],
) -> str:
    """Serialize validated program items from create and partial-update paths.

    Schedule creation passes ``ProgramItem`` instances, while
    ``ScheduleUpdateRequest.model_dump()`` recursively converts the same items
    to dictionaries before calling the service.  Supporting both forms keeps
    the service boundary consistent for API and direct service callers.
    """
    items = [
        item.model_dump() if isinstance(item, ProgramItem) else dict(item)
        for item in program
    ]
    return json.dumps(items, ensure_ascii=False)


def _existing_schedule_out(
    session: TrainerSchedule,
    *,
    date: str,
    time: str,
    client_name: str,
    member_id: str | None,
    type_: str,
    duration_minutes: int,
    note: str,
    program_json: str,
) -> ScheduleSessionOut:
    same_payload = (
        session.date == date
        and session.time == time
        and session.client_name == client_name
        and session.member_id == member_id
        and session.type == type_
        and session.duration_minutes == duration_minutes
        and session.note == note
        and session.program_json == program_json
    )
    if not same_payload:
        raise IdempotencyConflict(
            "같은 client_request_id에 다른 스케줄을 생성할 수 없습니다."
        )
    return _schedule_out(session)


def create_session(
    db: Session, trainer_id: str, *, date: str, time: str, client_name: str,
    member_id: str | None, type_: str, duration_minutes: int, note: str,
    program: list[ProgramItem], client_request_id: str | None = None,
) -> ScheduleSessionOut:
    program_json = _dump_program(program)
    if client_request_id:
        existing = db.scalar(
            select(TrainerSchedule).where(
                TrainerSchedule.trainer_id == trainer_id,
                TrainerSchedule.client_request_id == client_request_id,
            )
        )
        if existing is not None:
            return _existing_schedule_out(
                existing,
                date=date,
                time=time,
                client_name=client_name,
                member_id=member_id,
                type_=type_,
                duration_minutes=duration_minutes,
                note=note,
                program_json=program_json,
            )

    s = TrainerSchedule(
        id=f"sched-{uuid.uuid4().hex[:12]}",
        trainer_id=trainer_id,
        member_id=member_id,
        date=date,
        time=time,
        client_name=client_name,
        type=type_,
        duration_minutes=duration_minutes,
        status="예정",
        note=note,
        program_json=program_json,
        sort_order=0,
        client_request_id=client_request_id,
    )
    db.add(s)
    # 같은 키의 동시 요청은 유니크 제약으로 하나만 통과시킨 뒤, 패배한 요청은
    # 승자의 행을 읽어 같은 결과를 반환한다. 알림은 flush 뒤라 중복되지 않는다.
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        if client_request_id:
            existing = db.scalar(
                select(TrainerSchedule).where(
                    TrainerSchedule.trainer_id == trainer_id,
                    TrainerSchedule.client_request_id == client_request_id,
                )
            )
            if existing is not None:
                return _existing_schedule_out(
                    existing,
                    date=date,
                    time=time,
                    client_name=client_name,
                    member_id=member_id,
                    type_=type_,
                    duration_minutes=duration_minutes,
                    note=note,
                    program_json=program_json,
                )
        raise

    # 회원 몫의 일정이 잡혔을 때만 알린다 — 가망 고객('신규 고객 · 상담')처럼
    # member_id 가 없는 슬롯은 알릴 대상 자체가 없다(#489).
    if member_id is not None:
        notification_service.queue(
            db,
            member_id=member_id,
            kind=notification_service.EXERCISE,
            category=notification_service.MEMBER_SCHEDULE,
            title="새 일정이 등록되었어요",
            body=f"{date} {time} · {type_}",
        )
    db.commit()
    db.refresh(s)
    return _schedule_out(s)


def register_program(
    db: Session,
    trainer_id: str,
    member_id: str,
    *,
    date: str,
    time: str,
    client_name: str,
    program: list[ProgramItem],
) -> tuple[ScheduleSessionOut, bool] | None:
    """Atomically attach a program to a planned session or create one.

    Locking the trainer-client link serializes this command for one
    trainer/member pair. A concurrent request therefore cannot observe the
    same empty schedule state and create a duplicate session: the second
    request waits, then sees and updates the row committed by the first.
    """
    client_link = db.scalar(
        select(TrainerClient)
        .where(
            TrainerClient.trainer_id == trainer_id,
            TrainerClient.member_id == member_id,
        )
        .with_for_update()
    )
    if client_link is None:
        return None

    session = db.scalar(
        select(TrainerSchedule)
        .where(
            TrainerSchedule.trainer_id == trainer_id,
            TrainerSchedule.member_id == member_id,
            TrainerSchedule.date == date,
            TrainerSchedule.status == "예정",
        )
        .order_by(TrainerSchedule.time, TrainerSchedule.id)
        .limit(1)
        .with_for_update()
    )
    if session is None:
        created = create_session(
            db,
            trainer_id,
            date=date,
            time=time,
            client_name=client_name,
            member_id=member_id,
            type_="1:1 PT",
            duration_minutes=60,
            note="",
            program=program,
        )
        return created, False

    session.program_json = _dump_program(program)
    db.commit()
    db.refresh(session)
    return _schedule_out(session), True


def _member_visible_slot(s: TrainerSchedule) -> tuple[str, str, str, int]:
    """회원이 약속을 지키려고 아는 값들. 이 넷 중 하나라도 달라지면 알린다.

    메모(`note`)·프로그램은 트레이너의 준비물이라 빠져 있다 — 그것까지 알리면
    알림함이 같은 일정으로 차고, 정작 시각이 바뀐 알림이 묻힌다. (#664)
    """
    return (s.date, s.time, s.type, s.duration_minutes)


def _slot_body(slot: tuple[str, str, str, int]) -> str:
    date, time, type_, _ = slot
    return f"{date} {time} · {type_}"


def _notify_schedule_changed(
    db: Session,
    *,
    session: TrainerSchedule,
    before_member_id: str | None,
    before_slot: tuple[str, str, str, int],
) -> None:
    """바뀐 일정을 회원에게 알린다. **커밋하지 않는다.**

    등록만 알리고 변경·취소를 알리지 않으면, 회원은 "새 일정이 등록되었어요" 를
    믿고 이미 옮겨진 시간에 나간다. 취소 알림이 등록 알림보다 중요하다. (#664)
    """
    after_slot = _member_visible_slot(session)

    if before_member_id == session.member_id:
        if session.member_id is None or before_slot == after_slot:
            return
        notification_service.queue(
            db,
            member_id=session.member_id,
            kind=notification_service.EXERCISE,
            category=notification_service.MEMBER_SCHEDULE,
            title="일정이 변경되었어요",
            body=_slot_body(after_slot),
        )
        return

    # 다른 회원에게 넘긴 일정. 넘겨받은 쪽만 알리면 원래 회원은 약속이 사라진
    # 줄 모른 채 그 시간에 나간다 — 양쪽 모두 알린다.
    if before_member_id is not None:
        notification_service.queue(
            db,
            member_id=before_member_id,
            kind=notification_service.EXERCISE,
            category=notification_service.MEMBER_SCHEDULE,
            title="일정이 취소되었어요",
            body=_slot_body(before_slot),
        )
    if session.member_id is not None:
        notification_service.queue(
            db,
            member_id=session.member_id,
            kind=notification_service.EXERCISE,
            category=notification_service.MEMBER_SCHEDULE,
            title="새 일정이 등록되었어요",
            body=_slot_body(after_slot),
        )


def update_session(
    db: Session, trainer_id: str, session_id: str, fields: dict
) -> ScheduleSessionOut | None:
    """예약 부분 수정. 소유 슬롯이 아니면 None(라우터 404).

    완료된 세션은 이미 회원 운동기록(RoutineHistory)으로 적재됐다. 이후 member_id·program·
    note 등을 바꾸면 스케줄과 기록이 어긋나므로(리뷰 재-#2), 완료 세션 수정은 409 로 거부한다.
    """
    s = _get_owned_session(db, trainer_id, session_id)
    if s is None:
        return None
    # 회원에게 알릴지 판단하려면 **바꾸기 전** 값을 들고 있어야 한다. 넘긴
    # 일정의 취소 알림에는 옛 시각을 써야 회원이 어느 약속인지 안다.
    before_member_id = s.member_id
    before_slot = _member_visible_slot(s)
    # A reservation owns the booking coordinates and lifecycle, so changing
    # its time/member/type/duration through the general schedule API would
    # desynchronise the slot and remaining count. The trainer may still add
    # the PT plan and memo: those fields do not alter the reservation.
    if _is_reservation_schedule(db, session_id) and not set(fields).issubset(
        {"program", "note"}
    ):
        raise ScheduleConflict(
            "예약으로 생성된 일정은 일반 일정 화면에서 수정할 수 없습니다."
        )
    if s.status == "완료":
        raise ScheduleConflict("완료된 세션은 수정할 수 없습니다.")
    if "time" in fields:
        s.time = fields["time"]
    if "client_name" in fields:
        s.client_name = fields["client_name"]
    if "member_id" in fields:
        # 빈 문자열은 '배정 해제'로 해석 → NULL 로 저장(""는 users.id FK 위반이라 500 유발).
        s.member_id = fields["member_id"] or None
    if "type" in fields:
        s.type = fields["type"]
    if "duration_minutes" in fields:
        s.duration_minutes = fields["duration_minutes"]
    if "note" in fields:
        s.note = fields["note"]
    if "program" in fields and fields["program"] is not None:
        s.program_json = _dump_program(fields["program"])
    _notify_schedule_changed(
        db,
        session=s,
        before_member_id=before_member_id,
        before_slot=before_slot,
    )
    db.commit()
    db.refresh(s)
    return _schedule_out(s)


def delete_session(db: Session, trainer_id: str, session_id: str) -> bool:
    s = _get_owned_session(db, trainer_id, session_id)
    if s is None:
        return False
    if _is_reservation_schedule(db, session_id):
        raise ScheduleConflict(
            "예약으로 생성된 일정은 일반 일정 화면에서 삭제할 수 없습니다."
        )
    # 완료 세션은 완료 시 파생된 기록을 갖는다 — 트레이너 이력(sched-hist-{id})과
    # 회원 운동 기록(sched-ex-{id}) 두 개다. 세션을 지우면 둘 다 함께 지워 고아
    # 레코드가 남지 않게 한다(완료 시 적재의 역연산). 회원 쪽을 빠뜨리면 회원의
    # 주간 집계에만 지워진 PT 가 계속 잡힌다.
    if s.status == "완료":
        hist = db.get(RoutineHistory, f"sched-hist-{s.id}")
        if hist is not None:
            db.delete(hist)
        derived = db.get(ExerciseSession, _derived_exercise_id(s.id))
        if derived is not None:
            db.delete(derived)
    # 아직 오지 않은 약속만 알린다. 이미 끝난 PT 의 기록 정리까지 알리면 회원은
    # 지난 일을 취소 통보로 받는다. (#664)
    if s.member_id is not None and s.status != "완료":
        notification_service.queue(
            db,
            member_id=s.member_id,
            kind=notification_service.EXERCISE,
            category=notification_service.MEMBER_SCHEDULE,
            title="일정이 취소되었어요",
            body=_slot_body(_member_visible_slot(s)),
        )
    db.delete(s)
    db.commit()
    return True


#: PT 완료가 파생시키는 회원 운동 기록의 종류. `TrainerSchedule.type` 은 화면용
#: 한국어 라벨('1:1 PT'|'상담')이고 `ExerciseSession.type` 은 계약 값이라 매핑이
#: 필요하다. 여기 없는 종류는 **운동이 아니므로 기록을 만들지 않는다** — 상담
#: 한 시간이 회원 주간 운동량으로 잡히면 집계가 거짓이 된다.
_SESSION_EXERCISE_TYPE = {"1:1 PT": "strength"}

#: PT 는 트레이너가 붙어서 끌고 가는 시간이라 수기 입력의 '보통'보다 낮게 볼
#: 이유가 없다. 강도를 따로 입력받는 자리가 트레이너 앱에 없으므로 기본값을 쓴다.
_PT_INTENSITY = "moderate"


def _derived_exercise_id(session_id: str) -> str:
    """PT 완료가 파생시킨 운동 기록의 id — 슬롯 기준 결정론적.

    `sched-hist-{id}` 와 같은 이유다. 동시 완료나 재호출에도 같은 id 가 나와
    중복 행이 생기지 않는다.
    """
    return f"sched-ex-{session_id}"


def _add_member_exercise_log(
    db: Session, s: TrainerSchedule
) -> ExerciseSession | None:
    """완료된 PT 세션을 회원 쪽 운동 기록으로 적재. 대상이 아니면 None.

    `RoutineHistory` 는 트레이너 화면 전용이라(`/trainer/clients/{id}/history`)
    회원 앱에서는 읽지 않는다. 회원의 운동 탭·홈 대시보드 주간 집계는 전부
    `ExerciseSession` 에서 나오므로, 두 곳 모두에 남겨야 회원이 받은 PT 가
    자기 기록에 잡힌다. (#499)
    """
    ex_type = _SESSION_EXERCISE_TYPE.get(s.type)
    if s.member_id is None or ex_type is None or s.duration_minutes <= 0:
        return None
    row = ExerciseSession(
        id=_derived_exercise_id(s.id),
        user_id=s.member_id,
        # 주차·요일은 완료 시점이 아니라 **세션 날짜** 기준이다. 지난 주 세션을
        # 오늘 완료 처리해도 그 주의 집계로 들어가야 한다.
        week_start=exercise_service.monday_of_str(s.date),
        day_label=exercise_service.weekday_label_of(s.date),
        type=ex_type,
        minutes=s.duration_minutes,
        calories=exercise_service.estimate_calories(
            ex_type, s.duration_minutes, _PT_INTENSITY
        ),
        intensity=_PT_INTENSITY,
        source="trainer_pt",
    )
    db.add(row)
    return row


def send_session_program(
    db: Session,
    trainer_id: str,
    session_id: str,
    *,
    client_request_id: str | None = None,
) -> ScheduleSessionOut | None:
    """완료한 세션의 프로그램을 그 회원에게 배정한다. (#822)

    수업을 마친 뒤 "오늘 이걸 했습니다" 를 회원 앱으로 넘기는 자리다. 새 배정
    경로를 만들지 않고 [assign_program] 을 그대로 쓴다 — 회원이 받는 모양이
    트레이너가 코칭 탭에서 보내던 것과 같아야, 회원 화면에 출처마다 다른 루틴이
    생기지 않는다.

    - 소유 슬롯 아님 → None(404).
    - 회원이 없는 슬롯(상담·공백) → ScheduleError(400): 보낼 상대가 없다.
    - 완료 전 → ScheduleError(400): 아직 한 것이 아니라 할 것이다.
    - 프로그램이 비었으면 → ScheduleError(400): 빈 루틴만 간다.
    - 이미 보냈으면 그대로 반환(멱등). 두 번 눌러도 회원 루틴이 겹치지 않는다.
    """
    s = _get_owned_session(db, trainer_id, session_id)
    if s is None:
        return None
    if not s.member_id:
        raise ScheduleError("회원이 연결되지 않은 일정입니다.")
    if s.status != "완료":
        raise ScheduleError("완료한 일정만 보낼 수 있습니다.")
    items = _program_items(s.program_json)
    if not items:
        raise ScheduleError("보낼 프로그램이 없습니다.")
    if s.program_sent_at is not None:
        return _schedule_out(s)  # 멱등 no-op

    # 일정의 프로그램 항목({name,sets,reps,weight})을 배정 계약의 운동으로 옮긴다.
    # 세션은 하나다 — 회원 화면에 없던 세션 라벨이 생기지 않는다.
    exercises = [
        ProgramDraftExercise(
            id=f"{s.id}#{index}",
            name=item.name,
            sets=str(item.sets) if item.sets else "",
            reps=item.reps,
            weight=item.weight,
        )
        for index, item in enumerate(items)
    ]
    assign_program(
        db,
        trainer_id,
        s.member_id,
        name=f"{s.date} {s.type}".strip() or s.date,
        sessions=[ProgramDraftSession(id=s.id, name="", exercises=exercises)],
        client_request_id=client_request_id,
    )
    # 배정이 커밋된 뒤에만 보낸 것으로 남긴다. 반대 순서면 배정에 실패한 세션이
    # 화면에서 '전송됨' 이 되어 다시 보낼 수 없다.
    s.program_sent_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(s)
    return _schedule_out(s)


def complete_session(
    db: Session, trainer_id: str, session_id: str, note: str
) -> ScheduleSessionOut | None:
    """예정→완료. 매칭된 회원이 있으면 트레이너 쪽 기록(RoutineHistory)과 회원 쪽
    기록(ExerciseSession)으로 함께 적재해 '예약→수업→기록' 루프를 닫는다.

    - 소유 슬롯 아님 → None(404).
    - 공백/미래 일정 → ScheduleError(400).
    - 이미 완료 → 그대로 반환(멱등, 중복 기록 없음).
    두 기록 모두 id 가 슬롯 기준 결정론적이라 동시/재호출에도 중복되지 않는다.
    """
    s = _get_owned_session(db, trainer_id, session_id)
    if s is None:
        return None
    if s.status == "공백":
        raise ScheduleError("빈 슬롯은 완료할 수 없습니다.")
    if s.date > _today().isoformat():
        raise ScheduleError("미래 일정은 완료할 수 없습니다.")
    if s.status == "완료":
        return _schedule_out(s)  # 멱등 no-op

    # 조건부 전환(예정 → 완료). rowcount==1 인 호출만 '방금 전환한' 것이므로 그 호출만
    # 운동기록을 쓴다 — 동시 완료 요청이 둘 다 예정을 보고 중복 기록하는 것을 막는다.
    values: dict = {"status": "완료"}
    if note:
        values["note"] = note
    changed = db.execute(
        update(TrainerSchedule)
        .where(TrainerSchedule.id == session_id, TrainerSchedule.status == "예정")
        .values(**values)
    ).rowcount
    if changed != 1:
        db.commit()
        db.refresh(s)
        return _schedule_out(s)  # 동시 호출이 먼저 완료 처리함 — 기록 없이 현재 상태 반환

    exercise_log: ExerciseSession | None = None
    if s.member_id:
        program = _program_items(s.program_json)
        exercises = [
            f"{p.name} {p.sets}세트" if p.sets > 1 else f"{p.name} {p.reps}".strip()
            for p in program
        ]
        db.add(RoutineHistory(
            id=f"sched-hist-{s.id}",
            member_id=s.member_id,
            trainer_id=trainer_id,
            date=s.date,
            kind_label="PT 세션 · 트레이너 지도",
            completion_rate=100,
            exercises_json=json.dumps(exercises, ensure_ascii=False),
            trainer_note=note,
        ))
        exercise_log = _add_member_exercise_log(db, s)
    db.commit()
    db.refresh(s)
    out = _schedule_out(s)
    if exercise_log is not None:
        # 회원 입장에서 PT 도 '내가 한 운동'이라 코치가 검색할 수 있어야 한다(#586).
        # 커밋 뒤에 부르는 이유는 record_chat 과 같다 — 적재 실패의 롤백이 응답을
        # 깨뜨리지 않도록, 값은 미리 뽑아 두고 응답도 이미 만들어 둔다.
        # PT 완료는 멱등하게 재호출될 수 있고 id 도 슬롯 기준 결정론적이라
        # (`_derived_exercise_id`), 교체로 두어야 문서가 겹쳐 쌓이지 않는다.
        personal_ingest.refresh_exercise(
            db, exercise_log.user_id, session_id=exercise_log.id
        )
    return out


# ---- 회원측 미러 (내 담당 코치 / 받은 루틴 / 채팅 / 내 세션) ----

def _active_link(db: Session, member_id: str) -> TrainerClient | None:
    """회원의 현재 담당(활성) 링크 — 가장 오래된 active 1건. 없으면 None.

    '현재 담당 코치 1명' 판정의 단일 소스. get_member_trainer_id / build_member_coach 등이
    각자 같은 쿼리를 중복하면 divergence 위험이 있어 여기로 모은다(리뷰 #281).
    """
    return db.scalar(
        select(TrainerClient)
        .where(TrainerClient.member_id == member_id, TrainerClient.active.is_(True))
        .order_by(TrainerClient.created_at)
        .limit(1)
    )


def get_member_trainer_id(db: Session, member_id: str) -> str | None:
    """회원의 현재 담당 트레이너 id. 활성(active) 링크만 인정하며 없으면 None.

    휴면(비활성) 링크는 '현재 담당'이 아니므로 제외한다(리뷰 재-#3) — 비활성 링크만
    가진 회원은 코치 조회/발신이 불가(404/빈 목록)해야 한다.
    """
    link = _active_link(db, member_id)
    return link.trainer_id if link is not None else None


def _deactivate_coach_links(db: Session, member_id: str) -> bool:
    """활성 담당 링크를 전부 휴면으로 내린다(커밋 없음). 내린 게 있으면 True.

    링크 행을 지우지 않고 `active=False` 로 내린다 — 지난 코칭 기록(루틴·채팅·일정)이
    링크를 참조하므로 삭제하면 이력이 끊긴다. 비활성 링크는 `_active_link` 가 제외해
    이후 조회는 '담당 없음'으로 동작한다.

    **전부** 내리는 이유: partial unique index 가 회원당 1건을 강제하지만, 정합성이
    깨져 여러 건이 남은 경우 첫 건만 끄면 get_member_trainer_id() 가 계속 다른 링크를
    반환해 "해제했는데 그대로"가 된다(리뷰 지적).
    """
    links = db.scalars(
        select(TrainerClient).where(
            TrainerClient.member_id == member_id,
            TrainerClient.active.is_(True),
        )
    ).all()
    for link in links:
        link.active = False
    return bool(links)


def disconnect_member_gym(db: Session, member_id: str) -> bool:
    """회원이 헬스장 연결을 끊는다 — 담당 트레이너도 함께 끊긴다.

    떠난 헬스장의 트레이너를 담당으로 남겨 둘 수는 없다. 앱의 mock 도 같은 규칙이고
    (`MockGymRepository.disconnectMyGym`), MY 탭의 헬스장 휴지통이 이 경로다.
    둘 중 하나라도 끊었으면 True.

    두 해제를 **한 트랜잭션**으로 커밋한다. 각자 커밋하면 뒤 단계가 실패했을 때
    헬스장만 사라지고 담당은 살아 있는 반쪽 상태가 남는다.
    """
    from app.services import gym_service

    unlinked_gym = gym_service.unlink_member_gym(db, member_id)
    unlinked_trainer = _deactivate_coach_links(db, member_id)
    db.commit()
    return unlinked_gym or unlinked_trainer


def disconnect_member_coach(db: Session, member_id: str) -> bool:
    """회원이 담당 트레이너 연결을 끊는다 — 헬스장 연결은 그대로 둔다.

    끊었으면 True, 원래 없었으면 False.

    회원 일방으로 끊을 수 있게 두는 이유: 앱의 MY 탭이 이미 해제 버튼을 제공하고,
    트레이너 승인을 기다리게 하면 회원이 관계를 벗어날 방법이 없어진다. 트레이너
    로스터에서는 즉시 사라진다.
    """
    deactivated = _deactivate_coach_links(db, member_id)
    db.commit()
    return deactivated


def _member_gym_out(db: Session, member_id: str, profile: TrainerProfile) -> TrainerGymOut:
    """코치 요약에 실을 헬스장 — **회원 링크가 진실**이고, 트레이너 소속은 폴백이다.

    회원이 트레이너와 다른 헬스장에 연결돼 있을 수 있으므로(트레이너 이적 등) 먼저
    회원 링크를 본다. 링크가 없는 회원은 마이그레이션 백필 전 데이터이거나 담당만
    있고 헬스장 연결이 아직 없는 경우라, 예전처럼 트레이너 소속을 보여 준다 —
    갑자기 빈 카드가 되는 것보다 낫다.
    """
    from app.services import gym_service

    gym = gym_service.get_member_gym(db, member_id)
    if gym is not None:
        return TrainerGymOut(
            id=gym.id,
            name=gym.name,
            address=gym.address,
            # TrainerGymOut.hours 는 한 줄이다. 카드가 평일 영업시간을 보여 주므로
            # 주말 시간까지 합치지 않는다(트레이너 프로필의 gym_hours 와 같은 값).
            hours=gym.weekday_hours or "",
            phone=gym.phone or "",
        )
    return TrainerGymOut(
        id=profile.gym_id,
        name=profile.gym_name, address=profile.gym_address,
        hours=profile.gym_hours, phone=profile.gym_phone,
    )


def build_member_coach(db: Session, member_id: str) -> MemberCoachOut | None:
    """회원의 '내 담당 코치' 요약. 활성 담당이 없으면 None(라우터 404)."""
    link = _active_link(db, member_id)
    if link is None:
        return None
    trainer = db.get(User, link.trainer_id)
    profile = db.scalar(
        select(TrainerProfile).where(TrainerProfile.trainer_id == link.trainer_id)
    )
    if trainer is None or profile is None:
        return None
    return MemberCoachOut(
        trainer_id=trainer.id,
        name=trainer.name,
        specialty=profile.specialty,
        career=f"{profile.career_years}년",
        intro=profile.intro,
        gym=_member_gym_out(db, member_id, profile),
        goal=link.goal,
    )


def build_member_routines(db: Session, member_id: str) -> list[RoutineOut]:
    """회원이 받은 개인운동.

    담당 트레이너가 있으면 그 트레이너가 배정한 것(승인된 것만, #790).
    담당이 없으면 AI 가 안전 범위에서 직접 준비한 것(#782) — 예전에는 이 경우
    늘 빈 목록이라, 트레이너 없는 회원은 운동 탭에서 받을 것이 아무것도 없었다.
    """
    trainer_id = get_member_trainer_id(db, member_id)
    if trainer_id is None:
        auto_routine_service.ensure_auto_routines(db, member_id)
        return build_routines(db, member_id, None, for_member=True)
    return build_routines(db, member_id, trainer_id, for_member=True)


#: 회원 세션 목록 상한 — 시간이 지나며 누적되는 PT 세션을 최근 것 위주로 잘라 응답 크기를 묶는다.
_MEMBER_SESSIONS_LIMIT = 100


def build_member_sessions(db: Session, member_id: str) -> list[ScheduleSessionOut]:
    """회원의 PT 세션(현재 활성 담당 트레이너의 스케줄에서 매칭된 것), 최신순(최근 100건).

    routines 와 동일하게 **활성 트레이너로 스코프**한다 — member_id 로만 조회하면 코치
    재배정 후에도 이전 트레이너가 만든 세션이 계속 보인다(stale). 활성 담당이 없으면 빈 목록.
    """
    trainer_id = get_member_trainer_id(db, member_id)
    if trainer_id is None:
        return []
    rows = db.scalars(
        select(TrainerSchedule)
        .where(
            TrainerSchedule.member_id == member_id,
            TrainerSchedule.trainer_id == trainer_id,
        )
        .order_by(TrainerSchedule.date.desc(), TrainerSchedule.time.desc())
        .limit(_MEMBER_SESSIONS_LIMIT)
    ).all()
    return [_schedule_out(s) for s in rows]


def member_unread_count(db: Session, trainer_id: str, member_id: str) -> int:
    """회원 기준 미확인(트레이너가 보낸 read_at NULL) 메시지 수."""
    return db.scalar(
        select(func.count())
        .select_from(ChatMessage)
        .where(
            ChatMessage.trainer_id == trainer_id,
            ChatMessage.member_id == member_id,
            ChatMessage.sender == "trainer",
            ChatMessage.read_at.is_(None),
        )
    ) or 0


# ---- 트레이너 프로필 ----

def _certifications(profile: TrainerProfile) -> list[str]:
    """자격증 JSON 을 방어적으로 디코드. 깨진 값은 빈 목록으로 (프로필 화면이
    500 으로 죽는 것보다 낫다)."""
    try:
        certs = json.loads(profile.certifications_json) if profile.certifications_json else []
    except json.JSONDecodeError:
        return []
    if not isinstance(certs, list) or not all(isinstance(c, str) for c in certs):
        return []
    return certs


def build_trainer_me(trainer: User, profile: TrainerProfile) -> TrainerMe:
    """`GET /trainer/me` 응답. 조회와 수정이 같은 표현을 쓰도록 분리."""
    return TrainerMe(
        id=trainer.id,
        name=trainer.name,
        email=trainer.email,
        phone=profile.phone,
        specialty=profile.specialty,
        career=f"{profile.career_years}년",
        intro=profile.intro,
        certifications=_certifications(profile),
        gym=TrainerGymOut(
            id=profile.gym_id,
            name=profile.gym_name,
            address=profile.gym_address,
            hours=profile.gym_hours,
            phone=profile.gym_phone,
        ),
    )


#: `TrainerMeUpdate` 가 받는 호환용 헬스장 문자열. 소속(`gym_id`)이 설정돼 있으면
#: 이 값들은 Place/GymProfile 에서 파생되므로 직접 수정할 수 없다(#452).
GYM_TEXT_FIELDS = ("gym_name", "gym_address", "gym_hours", "gym_phone")


class GymTextLockedByAffiliation(Exception):
    """소속이 설정된 프로필에서 호환 문자열만 따로 바꾸려 한 경우. (#452)"""


def update_trainer_profile(
    db: Session, trainer: User, profile: TrainerProfile, fields: dict
) -> TrainerMe:
    """보낸 필드만 반영한다. 자격증은 통째로 교체(부분 병합은 순서가 모호하다).

    `gym_id` 가 있으면 호환 문자열은 소속에서 파생된 값이라 여기서 못 고친다 —
    문자열만 바꾸면 소속과 화면이 어긋난다. `GymTextLockedByAffiliation` 을 올리고
    라우터가 409 로 돌려준다. 소속이 없는(레거시·해제) 프로필은 예전처럼 직접 적는다.
    """
    if profile.gym_id is not None and any(f in fields for f in GYM_TEXT_FIELDS):
        raise GymTextLockedByAffiliation

    if "certifications" in fields:
        certs = [c.strip() for c in (fields["certifications"] or []) if c.strip()]
        profile.certifications_json = json.dumps(certs, ensure_ascii=False)
    for column in ("phone", "specialty", "career_years", "intro", *GYM_TEXT_FIELDS):
        if column in fields:
            setattr(profile, column, fields[column])
    db.commit()
    db.refresh(profile)
    return build_trainer_me(trainer, profile)


# ---- 소속 헬스장 (#452) ----

def _apply_gym_texts(profile: TrainerProfile, place: Place | None, gym: GymProfile | None) -> None:
    """호환 문자열을 소속에서 파생시킨다 — 소속이 진실이고 문자열은 그 사본이다.

    트레이너 앱은 아직 `gym.{name,address,hours,phone}` 만 읽으므로, 소속을 바꿔도
    문자열이 그대로면 화면에는 예전 헬스장이 남는다. 해제(place=None)면 비운다 —
    떠난 헬스장의 이름을 남겨 두면 회원 쪽 코치 카드가 그 값으로 폴백한다
    (`_member_gym_out`).
    """
    if place is None:
        profile.gym_name = ""
        profile.gym_address = ""
        profile.gym_hours = ""
        profile.gym_phone = ""
        return
    # places.name(200) 이 trainer_profiles.gym_name(100) 보다 길다 — 넘치면 DB 가 막는다.
    profile.gym_name = place.name[:100]
    profile.gym_address = place.address[:300]
    # 영업시간·전화는 헬스장 부가 정보(GymProfile)에만 있다. 카카오에서 발견한
    # 헬스장은 부가 정보가 없어 빈 값이 정상이다.
    profile.gym_hours = (gym.weekday_hours if gym else "")[:50]
    profile.gym_phone = (gym.phone if gym else "")[:20]


def set_trainer_gym(
    db: Session, trainer: User, profile: TrainerProfile, gym_id: str
) -> TrainerMe | None:
    """소속 헬스장을 설정·변경한다. 유효한 헬스장이 아니면 None(라우터 404).

    `places` 에 있고 category 가 'fitness' 인 곳만 받는다 — 상담 대상 검증
    (`consultation_service._validate_target`)·헬스장 디렉터리와 같은 조건이라야
    소속을 설정한 트레이너가 회원 화면에 제대로 뜬다(#451, #443).
    """
    place = db.scalar(
        select(Place).where(Place.id == gym_id, Place.category == "fitness")
    )
    if place is None:
        return None

    profile.gym_id = place.id
    _apply_gym_texts(profile, place, db.get(GymProfile, place.id))
    db.commit()
    db.refresh(profile)
    return build_trainer_me(trainer, profile)


def clear_trainer_gym(db: Session, trainer: User, profile: TrainerProfile) -> TrainerMe:
    """소속 해제. 원래 없었어도 성공한다 — 해제는 두 번 눌러도 오류가 아니다.

    회원↔헬스장 링크(`member_gyms`)는 건드리지 않는다. 회원이 직접 연결한 헬스장은
    트레이너가 이적해도 회원의 선택으로 남는다(#444).
    """
    profile.gym_id = None
    _apply_gym_texts(profile, None, None)
    db.commit()
    db.refresh(profile)
    return build_trainer_me(trainer, profile)


# ---- 주간 리포트 ----

def week_start_of(day: date) -> date:
    """그 주의 월요일."""
    return day - timedelta(days=day.weekday())


def build_weekly_report(
    db: Session, trainer_id: str, member_id: str, week_start: date
) -> WeeklyReportOut:
    """담당 고객 한 명의 한 주.

    O2O 코칭에서 회원이 재등록하는 이유는 "좋아졌다"를 볼 수 있을 때다. 여기서
    쓰는 값은 전부 두 앱이 이미 공유하는 데이터(식단·운동기록·스케줄)이며 새로
    수집하는 것이 없다.
    """
    monday = week_start_of(week_start)
    sunday = monday + timedelta(days=6)
    monday_str, sunday_str = monday.isoformat(), sunday.isoformat()

    member = db.get(User, member_id)
    member_name = member.name if member else "고객"

    sessions = db.scalars(
        select(TrainerSchedule).where(
            TrainerSchedule.trainer_id == trainer_id,
            TrainerSchedule.member_id == member_id,
            TrainerSchedule.date >= monday_str,
            TrainerSchedule.date <= sunday_str,
            TrainerSchedule.status != "공백",
        )
    ).all()
    booked = len(sessions)
    done = sum(1 for s in sessions if s.status == "완료")

    hist = db.scalars(
        select(RoutineHistory).where(
            RoutineHistory.member_id == member_id,
            RoutineHistory.date >= monday_str,
            RoutineHistory.date <= sunday_str,
            or_(RoutineHistory.trainer_id.is_(None), RoutineHistory.trainer_id == trainer_id),
        )
    ).all()
    week = _week_completion(hist, monday)
    days = _week_days(hist, monday, week)
    recorded = [d for d in week if d > 0]
    # 기록이 하나도 없으면 null — 0% 로 보고하면 "아무것도 안 했다"는 거짓말이 된다.
    completion_avg = round(sum(recorded) / len(recorded)) if recorded else None

    diet = db.scalars(
        select(DietEntry).where(
            DietEntry.user_id == member_id,
            DietEntry.date >= monday_str,
            DietEntry.date <= sunday_str,
        )
    ).all()
    diet_rows = list(diet)
    sodium_week = _sodium_week(diet_rows, monday)
    # 기록이 있는 날만 센다 — 아직 오지 않은 요일의 0 까지 나누면 주 초반
    # 평균이 실제보다 낮아진다(로스터의 `sodiumWeekAvg` 와 같은 규칙).
    recorded_sodium = [mg for mg in sodium_week if mg > 0]
    sodium_over_days = sum(1 for mg in sodium_week if mg > SODIUM_TARGET_MG)
    sodium_avg = (
        round(sum(recorded_sodium) / len(recorded_sodium)) if recorded_sodium else None
    )

    report = WeeklyReportOut(
        member_id=member_id,
        member_name=member_name,
        week_start=monday_str,
        week_end=sunday_str,
        sessions_booked=booked,
        sessions_done=done,
        completion_avg=completion_avg,
        sodium_over_days=sodium_over_days,
        sodium_avg=sodium_avg,
        week_completion=week,
        days=days,
        sodium_week=sodium_week,
        calories_week=_calories_week(diet_rows, monday),
        sugar_week=_sugar_week(diet_rows, monday),
        message="",
    )
    return report.model_copy(update={"message": report_message(report)})


def report_message(report: WeeklyReportOut) -> str:
    """회원 채팅 스레드에 그대로 들어갈 본문.

    별도 리포트 함이 아니라 이미 읽고 있는 대화에 도착하도록 평문으로 쓴다 —
    시스템 덤프가 아니라 담당 트레이너가 쓴 말처럼 보여야 한다.

    리포트 요약 카드(`trainer_report_summary_service`)와 **역할이 다르다.**
    카드는 트레이너가 훑는 메모라 짧고 건조하다. 이 글은 회원이 받는 편지라
    문단으로 쓰고, 수치마다 그래서 무엇을 하면 되는지를 붙인다. 트레이너가
    손보지 않고 그대로 보내도 사람이 쓴 것으로 읽혀야 한다.

    기록이 없는 항목은 문장을 아예 뺀다 — '이행률 0%'는 거짓말이다.
    """
    start = date.fromisoformat(report.week_start)
    end = date.fromisoformat(report.week_end)
    good = (report.completion_avg or 0) >= 70 and report.sodium_over_days <= 2
    period = f"{start.month}월 {start.day}일 – {end.month}월 {end.day}일"

    paragraphs: list[str] = [
        # 첫 줄에 무슨 메시지인지가 있어야 한다 — 회원의 대화방에는 다른
        # 메시지도 함께 쌓인다.
        f"{report.member_name}님, {period} 주간 리포트 정리해서 보내드려요."
    ]

    workout: list[str] = []
    if report.completion_avg is not None:
        workout.append(
            f"이번 주 운동은 평균 {report.completion_avg}%로 잘 따라오셨어요."
            if report.completion_avg >= 70
            else f"이번 주 운동 이행률은 평균 {report.completion_avg}%였어요. 많이 바쁘셨나 봐요."
        )
    if report.sessions_booked:
        workout.append(
            f"PT 세션은 {report.sessions_done}/{report.sessions_booked}회 진행했어요."
        )
    skipped = _skipped_names(report)
    if skipped:
        workout.append(
            f"다만 {_topic(', '.join(skipped))} 건너뛰셨더라고요. 컨디션 때문이었다면 "
            "다음 세션 때 말씀해 주세요. 대체 동작으로 바꿔 둘게요."
        )
    if workout:
        paragraphs.append(" ".join(workout))

    diet: list[str] = []
    if report.sodium_avg is not None:
        diet.append(
            f"나트륨은 하루 평균 {report.sodium_avg:,}mg으로 목표(2,000mg)를 "
            f"{report.sodium_over_days}일 넘겼어요. 국물을 절반만 남기셔도 "
            "하루 400~500mg은 줄어듭니다."
            if report.sodium_over_days > 0
            else f"나트륨은 하루 평균 {report.sodium_avg:,}mg으로 목표 안에서 잘 지키고 계세요."
        )
    recorded = [v for v in report.calories_week if v > 0]
    if recorded:
        diet.append(
            f"칼로리는 하루 평균 {round(sum(recorded) / len(recorded)):,}kcal이에요."
        )
    if diet:
        paragraphs.append(" ".join(diet))

    if len(paragraphs) == 1:
        # 인사말만 남았다 — 가리킬 '이 부분'이 없다. 기록이 없는 주에 격려부터
        # 하면 회원이 무엇을 하라는 말인지 알 수 없다.
        paragraphs.append(
            "이번 주는 남은 기록이 없어서 정리해 드릴 내용이 없네요. "
            "다음 주 시작을 같이 잡아 봐요."
        )
    else:
        paragraphs.append(
            "이번 주 정말 잘하셨어요. 다음 주도 이 페이스 그대로 가요!"
            if good
            else "다음 주에는 이 부분만 같이 신경 써 봐요. 루틴은 제가 조정해서 올려둘게요."
        )
    return "\n\n".join(paragraphs)


def _topic(word: str) -> str:
    """`은`/`는` 을 받침에 맞춰 붙인다.

    `은(는)` 은 사람이 쓴 글로 읽히지 않는다 — 회원이 그대로 받는 문장이라
    기계가 쓴 티가 나는 자리를 남기지 않는다.
    """
    if not word:
        return word
    last = word[-1]
    has_batchim = "가" <= last <= "힣" and (ord(last) - 0xAC00) % 28 != 0
    return f"{word}{'은' if has_batchim else '는'}"


def _skipped_names(report: WeeklyReportOut) -> list[str]:
    """그 주에 건너뛴 운동 이름. 이행률이 왜 100%가 아닌지의 답이다."""
    names: list[str] = []
    for day in report.days:
        for line in day.exercises:
            if "✗" not in line:
                continue
            name = line.replace("✗", "").strip()
            if name and name not in names:
                names.append(name)
    return names[:3]


# ---- 알림 수신 설정 ----

def build_notification_settings(
    profile: TrainerProfile,
) -> TrainerNotificationSettings:
    """`GET /trainer/me/settings` 응답."""
    return TrainerNotificationSettings(
        notify_new_message=profile.notify_new_message,
        notify_session_reminder=profile.notify_session_reminder,
        reminder_lead_minutes=profile.reminder_lead_minutes,
    )


def update_notification_settings(
    db: Session, profile: TrainerProfile, fields: dict
) -> TrainerNotificationSettings:
    """보낸 필드만 반영한다."""
    for column in (
        "notify_new_message",
        "notify_session_reminder",
        "reminder_lead_minutes",
    ):
        if column in fields:
            setattr(profile, column, fields[column])
    db.commit()
    db.refresh(profile)
    return build_notification_settings(profile)
