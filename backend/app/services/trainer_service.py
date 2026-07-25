"""
트레이너 도메인 서비스 — 로스터/식단/기록 집계.

핵심(진짜 데이터 공유): 고객의 칼로리·나트륨·당류·나트륨 추세는 별도 복제본이 아니라
회원이 회원 앱에서 남긴 실제 DietEntry 를 집계한 값이다. 라우터는 얇게 두고 도메인
로직(집계·라벨링·계약 매핑)은 여기에 모은다.
"""
from __future__ import annotations

import json
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.models import (
    ChatMessage, DietEntry, RoutineHistory, TrainerClient, TrainerRoutine, User,
)
from app.schemas.trainer_api import (
    ClientDietEntryOut, RoutineHistoryOut, TrainerClientOut,
)


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


def build_roster(db: Session, trainer_id: str) -> list[TrainerClientOut]:
    """트레이너의 담당 고객 로스터. 각 카드의 영양 지표는 회원 실데이터에서 집계."""
    links = db.scalars(
        select(TrainerClient)
        .where(TrainerClient.trainer_id == trainer_id)
        .order_by(TrainerClient.sort_order, TrainerClient.created_at)
    ).all()

    today = _today()
    today_str = today.isoformat()
    monday = today - timedelta(days=today.weekday())

    out: list[TrainerClientOut] = []
    for link in links:
        member = db.get(User, link.member_id)
        if member is None:
            continue

        diet_rows = db.scalars(
            select(DietEntry).where(DietEntry.user_id == link.member_id)
        ).all()
        hist_rows = db.scalars(
            select(RoutineHistory).where(RoutineHistory.member_id == link.member_id)
        ).all()

        cal, na, sugar = _today_totals(diet_rows, today_str)

        last_msg = db.scalar(
            select(ChatMessage)
            .where(
                ChatMessage.trainer_id == trainer_id,
                ChatMessage.member_id == link.member_id,
            )
            .order_by(ChatMessage.created_at.desc())
            .limit(1)
        )
        last_rt = db.scalar(
            select(TrainerRoutine)
            .where(
                TrainerRoutine.trainer_id == trainer_id,
                TrainerRoutine.member_id == link.member_id,
            )
            .order_by(TrainerRoutine.created_at.desc())
            .limit(1)
        )

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
                relative_day_label(last_rt.created_at.date().isoformat())
                if last_rt else "-"
            ),
            week_completion=_week_completion(hist_rows, monday),
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


def build_client_history(db: Session, member_id: str) -> list[RoutineHistoryOut]:
    """회원의 운동 완료 기록(최신순)."""
    rows = db.scalars(
        select(RoutineHistory)
        .where(RoutineHistory.member_id == member_id)
        .order_by(RoutineHistory.date.desc(), RoutineHistory.created_at.desc())
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
