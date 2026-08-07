"""
트레이너 도메인 서비스 — 로스터/식단/기록 집계.

핵심(진짜 데이터 공유): 고객의 칼로리·나트륨·당류·나트륨 추세는 별도 복제본이 아니라
회원이 회원 앱에서 남긴 실제 DietEntry 를 집계한 값이다. 라우터는 얇게 두고 도메인
로직(집계·라벨링·계약 매핑)은 여기에 모은다.
"""
from __future__ import annotations

import json
import uuid
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, or_, select, tuple_, update
from sqlalchemy.orm import Session

from app.models.models import (
    ChatMessage, DietEntry, RoutineHistory, TrainerClient, TrainerProfile,
    TrainerRoutine, TrainerSchedule, User,
)
from app.schemas.trainer_api import (
    ChatMessageOut, ClientDietEntryOut, MemberCoachOut, ProgramItem, RoutineHistoryOut,
    RoutineOut, ScheduleSessionOut, TrainerClientOut, TrainerGymOut, TrainerMe,
    TrainerNotificationSettings, WeeklyReportOut,
)

# 일일 나트륨 목표(mg). 프론트 `sodiumTargetMg` 와 같은 값 — 리포트의
# '초과 N일'이 앱 화면의 경고와 어긋나면 안 된다.
SODIUM_TARGET_MG = 2000


def _today() -> date:
    return datetime.now().date()


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
    """tz-aware(또는 naive=UTC 가정) 시각 → 로컬(서버 TZ) 날짜 YYYY-MM-DD.

    created_at 은 UTC 로 저장되므로, 로컬 '오늘/어제' 판정과 맞추려면 로컬 날짜로 변환해야
    한다(안 그러면 KST 새벽엔 UTC 가 전날이라 '어제'로 어긋난다)."""
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    return ts.astimezone().date().isoformat()


def _today_totals(diet_rows: list[DietEntry], today_str: str) -> tuple[int, int, int]:
    cal = na = sugar = 0
    for e in diet_rows:
        if e.date == today_str:
            cal += e.total_calories
            na += e.sodium_mg
            sugar += e.sugar_g
    return cal, na, sugar


def _sodium_week(diet_rows: list[DietEntry], today: date) -> list[int]:
    """최근 7일 일별 나트륨 합(오래된→오늘). 기록 없는 날은 0."""
    by_date: dict[str, int] = {}
    for e in diet_rows:
        by_date[e.date] = by_date.get(e.date, 0) + e.sodium_mg
    return [
        by_date.get((today - timedelta(days=off)).isoformat(), 0)
        for off in range(6, -1, -1)
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

    # 최근 7일 식단(오늘 합계 + 나트륨 추세) — 전 고객 배치, 날짜 한정
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
        cal, na, sugar = _today_totals(diet_rows, today_str)
        last_msg = last_msg_by.get(link.member_id)
        last_rt = last_rt_by.get(link.member_id)

        out.append(TrainerClientOut(
            id=link.member_id,
            name=member.name,
            avatar=member.name[:1] if member.name else "?",
            goal=link.goal,
            last_message=last_msg.body if last_msg else "",
            last_time=relative_time_label(last_msg.created_at) if last_msg else "-",
            active=link.active,
            calories=cal,
            sodium_mg=na,
            sugar_g=sugar,
            last_routine=(
                relative_day_label(_local_date_iso(last_rt.created_at))
                if last_rt else "-"
            ),
            week_completion=_week_completion(hist_by_member.get(link.member_id, []), monday),
            sodium_week=_sodium_week(diet_rows, today),
        ))
    return out


def build_client_diet(db: Session, member_id: str, day: str) -> list[ClientDietEntryOut]:
    """회원의 특정 날짜 식단(회원 실데이터)을 고객 식단 서브탭 형태로."""
    rows = db.scalars(
        select(DietEntry)
        .where(DietEntry.user_id == member_id, DietEntry.date == day)
        .order_by(DietEntry.created_at, DietEntry.id)
    ).all()

    out: list[ClientDietEntryOut] = []
    for r in rows:
        try:
            foods = json.loads(r.foods_json) if r.foods_json else []
        except json.JSONDecodeError:
            foods = []
        items = ", ".join(f.get("name", "") for f in foods if f.get("name"))
        out.append(ClientDietEntryOut(
            meal=_meal_kr(r.meal_type),
            items=items,
            calories=r.total_calories,
            sodium_mg=r.sodium_mg,
        ))
    return out


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

    out: list[RoutineHistoryOut] = []
    for r in rows:
        try:
            exercises = json.loads(r.exercises_json) if r.exercises_json else []
        except json.JSONDecodeError:
            exercises = []
        out.append(RoutineHistoryOut(
            date_label=history_date_label(r.date),
            label=r.kind_label,
            completion_rate=r.completion_rate,
            exercises=exercises,
            client_feedback=r.client_feedback,
            trainer_note=r.trainer_note,
        ))
    return out


# ---- 채팅 (트레이너↔회원, 양방향 공유 스레드) ----

def _hhmm(ts: datetime) -> str:
    """created_at → 로컬 HH:MM (KST 서버면 KST)."""
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    return ts.astimezone().strftime("%H:%M")


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


def send_message(
    db: Session, trainer_id: str, member_id: str, sender: str, text: str,
    viewer: str = "trainer",
) -> ChatMessageOut:
    """스레드에 메시지 추가(sender: 'trainer'|'member'). 로스터 last_message 는
    build_roster 가 최신 메시지를 읽어 자동 반영하므로 별도 비정규화가 없다."""
    msg = ChatMessage(
        id=f"chat-{uuid.uuid4().hex[:12]}",
        trainer_id=trainer_id,
        member_id=member_id,
        sender=sender,
        body=text,
        created_at=datetime.now(timezone.utc),
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return ChatMessageOut(
        id=msg.id, sender=_sender_out(msg.sender, viewer), body=msg.body,
        time_label=_hhmm(msg.created_at), created_at=_iso(msg.created_at),
    )


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


# ---- 루틴 배정 (트레이너/AI → 회원, 양쪽에서 보이는 공유 데이터) ----

def build_routines(db: Session, member_id: str, trainer_id: str) -> list[RoutineOut]:
    """이 트레이너가 회원에게 배정한 루틴(정렬순)."""
    rows = db.scalars(
        select(TrainerRoutine)
        .where(TrainerRoutine.trainer_id == trainer_id, TrainerRoutine.member_id == member_id)
        .order_by(TrainerRoutine.sort_order, TrainerRoutine.created_at)
    ).all()
    return [
        RoutineOut(
            id=r.id, name=r.name, minutes=r.minutes, type=r.type,
            reason=r.reason, source=r.source,
        )
        for r in rows
    ]


def assign_routine(
    db: Session, trainer_id: str, member_id: str,
    name: str, minutes: int, type_: str, reason: str, source: str,
) -> RoutineOut:
    """회원에게 루틴 배정. 로스터 last_routine 은 build_roster 가 최신 루틴을 읽어 반영."""
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
        created_at=datetime.now(timezone.utc),
    )
    db.add(rt)
    db.commit()
    db.refresh(rt)
    return RoutineOut(
        id=rt.id, name=rt.name, minutes=rt.minutes, type=rt.type,
        reason=rt.reason, source=rt.source,
    )


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
        ))
    return out


def _schedule_out(s: TrainerSchedule) -> ScheduleSessionOut:
    return ScheduleSessionOut(
        id=s.id, date=s.date, time=s.time, client_name=s.client_name,
        type=s.type, duration_minutes=s.duration_minutes, status=s.status,
        note=s.note, program=_program_items(s.program_json),
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


def create_session(
    db: Session, trainer_id: str, *, date: str, time: str, client_name: str,
    member_id: str | None, type_: str, duration_minutes: int, note: str,
    program: list[ProgramItem],
) -> ScheduleSessionOut:
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
        program_json=json.dumps([p.model_dump() for p in program], ensure_ascii=False),
        sort_order=0,
    )
    db.add(s)
    db.commit()
    db.refresh(s)
    return _schedule_out(s)


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
        s.program_json = json.dumps(
            [p.model_dump() for p in fields["program"]], ensure_ascii=False
        )
    db.commit()
    db.refresh(s)
    return _schedule_out(s)


def delete_session(db: Session, trainer_id: str, session_id: str) -> bool:
    s = _get_owned_session(db, trainer_id, session_id)
    if s is None:
        return False
    # 완료 세션은 완료 시 파생된 운동기록(sched-hist-{id})을 갖는다. 세션을 지우면 그
    # 파생 기록도 함께 지워 고아 레코드가 회원 이력에 남지 않게 한다(완료 시 적재의 역연산).
    if s.status == "완료":
        hist = db.get(RoutineHistory, f"sched-hist-{s.id}")
        if hist is not None:
            db.delete(hist)
    db.delete(s)
    db.commit()
    return True


def complete_session(
    db: Session, trainer_id: str, session_id: str, note: str
) -> ScheduleSessionOut | None:
    """예정→완료. 매칭된 회원이 있으면 운동기록(RoutineHistory)으로 적재해
    '예약→수업→기록' 루프를 닫는다.

    - 소유 슬롯 아님 → None(404).
    - 공백/미래 일정 → ScheduleError(400).
    - 이미 완료 → 그대로 반환(멱등, 중복 기록 없음).
    기록 id 는 슬롯 기준 결정론적(sched-hist-{id})이라 동시/재호출에도 중복되지 않는다.
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
    db.commit()
    db.refresh(s)
    return _schedule_out(s)


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


def disconnect_member_coach(db: Session, member_id: str) -> bool:
    """회원이 담당 트레이너 연결을 끊는다. 끊었으면 True, 원래 없었으면 False.

    링크 행을 지우지 않고 `active=False` 로 내린다 — 지난 코칭 기록(루틴·채팅·일정)이
    링크를 참조하므로 삭제하면 이력이 끊긴다. 비활성 링크는 `_active_link` 가 제외해
    이후 조회는 '담당 없음'으로 동작한다.

    회원 일방으로 끊을 수 있게 두는 이유: 앱의 MY 탭이 이미 해제 버튼을 제공하고,
    트레이너 승인을 기다리게 하면 회원이 관계를 벗어날 방법이 없어진다. 트레이너
    로스터에서는 즉시 사라진다.
    """
    # 활성 링크를 **전부** 내린다. partial unique index 가 회원당 1건을 강제하지만,
    # 정합성이 깨져 여러 건이 남은 경우 첫 건만 끄면 get_member_trainer_id() 가 계속
    # 다른 링크를 반환해 "해제했는데 그대로"가 된다(리뷰 지적).
    links = db.scalars(
        select(TrainerClient).where(
            TrainerClient.member_id == member_id,
            TrainerClient.active.is_(True),
        )
    ).all()
    if not links:
        return False
    for link in links:
        link.active = False
    db.commit()
    return True


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
        gym=TrainerGymOut(
            id=profile.gym_id,
            name=profile.gym_name, address=profile.gym_address,
            hours=profile.gym_hours, phone=profile.gym_phone,
        ),
        goal=link.goal,
    )


def build_member_routines(db: Session, member_id: str) -> list[RoutineOut]:
    """회원이 받은 루틴(담당 트레이너 배정). 담당 없으면 빈 목록."""
    trainer_id = get_member_trainer_id(db, member_id)
    if trainer_id is None:
        return []
    return build_routines(db, member_id, trainer_id)


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


def update_trainer_profile(
    db: Session, trainer: User, profile: TrainerProfile, fields: dict
) -> TrainerMe:
    """보낸 필드만 반영한다. 자격증은 통째로 교체(부분 병합은 순서가 모호하다)."""
    if "certifications" in fields:
        certs = [c.strip() for c in (fields["certifications"] or []) if c.strip()]
        profile.certifications_json = json.dumps(certs, ensure_ascii=False)
    for column in (
        "phone", "specialty", "career_years", "intro",
        "gym_name", "gym_address", "gym_hours", "gym_phone",
    ):
        if column in fields:
            setattr(profile, column, fields[column])
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
    sodium_by_day: dict[str, int] = defaultdict(int)
    for e in diet:
        sodium_by_day[e.date] += int(e.sodium_mg or 0)
    daily = list(sodium_by_day.values())
    sodium_over_days = sum(1 for mg in daily if mg > SODIUM_TARGET_MG)
    sodium_avg = round(sum(daily) / len(daily)) if daily else None

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
        message="",
    )
    return report.model_copy(update={"message": report_message(report)})


def report_message(report: WeeklyReportOut) -> str:
    """회원 채팅 스레드에 그대로 들어갈 본문.

    별도 리포트 함이 아니라 이미 읽고 있는 대화에 도착하도록 평문으로 쓴다 —
    시스템 덤프가 아니라 담당 트레이너가 쓴 말처럼 보여야 한다.
    """
    start = date.fromisoformat(report.week_start)
    end = date.fromisoformat(report.week_end)
    good = (report.completion_avg or 0) >= 70 and report.sodium_over_days <= 2
    lines = [
        f"📊 {start.month}월 {start.day}일 – {end.month}월 {end.day}일 주간 리포트",
        f"PT 세션 {report.sessions_done}/{report.sessions_booked}회 완료",
    ]
    if report.completion_avg is not None:
        lines.append(f"운동 이행률 평균 {report.completion_avg}%")
    if report.sodium_avg is not None:
        lines.append(
            f"나트륨 평균 {report.sodium_avg}mg · 목표 초과 {report.sodium_over_days}일"
        )
    lines.append(
        "이번 주 정말 잘하셨어요. 다음 주도 이 페이스 유지해요!"
        if good
        else "다음 주에는 조금만 더 챙겨봐요. 제가 루틴을 조정해 둘게요."
    )
    return "\n".join(lines)


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
