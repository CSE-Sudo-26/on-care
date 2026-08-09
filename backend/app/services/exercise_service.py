"""
운동 주간 집계 서비스 — 프론트 _exerciseCurrentWeek 로직을 그대로 재현.

핵심 규칙(프론트와 동일):
- 요일 라벨: 월~일 (월=index 0)
- 타입 버킷: cardio|walking → 유산소, strength → 근력, yoga|stretching → 스트레칭
- date_label: 오늘/어제/MM월 DD일/N요일 (요일 라벨 → 날짜 환산)
- time_label, items: 타입별 기본값 합성 (drift 스키마에 없는 표시용 데이터)
- streak: 운동한 요일 중 가장 긴 연속 구간의 길이 ("N일 연속"). 활성 일수의 단순
  합계가 아니다 — 월·수·금 운동은 3일이 아니라 1일 연속. 프론트의
  `longestActiveStreak` 와 같은 정의.
- sessions 정렬: 최근 요일 먼저
"""
from __future__ import annotations

from datetime import date, datetime, timedelta

WEEKDAY_LABELS = ["월", "화", "수", "목", "금", "토", "일"]

#: 운동 타입별 분당 소모 칼로리. 회원 앱의 `_estimateCalories`
#: (`exercise_flows.dart`) 표를 그대로 옮긴 값이다 — 수기 입력은 앱이 계산해
#: 보내고 PT 완료분은 서버가 계산하므로, 두 값이 다르면 같은 운동인데 회원
#: 화면에서 칼로리가 갈린다.
_KCAL_PER_MIN = {
    "cardio": 9.0,
    "strength": 6.0,
    "walking": 4.0,
    "stretching": 3.0,
    "yoga": 3.0,
    "other": 5.0,
}

#: 강도 배수 — 회원 앱 `_intensityFactor` 와 같다.
_INTENSITY_FACTOR = {"light": 0.85, "moderate": 1.0, "high": 1.2}


def monday_of_this_week_str() -> str:
    now = datetime.now()
    monday = now - timedelta(days=now.weekday())
    return monday.strftime("%Y-%m-%d")


def monday_of_str(day: str) -> str:
    """`day`(YYYY-MM-DD) 가 속한 주의 월요일.

    지난 주 세션을 오늘 완료 처리할 수 있으므로, 파생 기록의 주차는 완료 시점이
    아니라 **세션 날짜** 기준이어야 한다. 형식이 깨진 값은 이번 주로 떨어뜨린다.
    """
    try:
        d = date.fromisoformat(day)
    except (TypeError, ValueError):
        return monday_of_this_week_str()
    return (d - timedelta(days=d.weekday())).isoformat()


def weekday_label_of(day: str) -> str:
    """`day`(YYYY-MM-DD) 의 요일 라벨(월~일). 형식이 깨지면 오늘 요일."""
    try:
        d = date.fromisoformat(day)
    except (TypeError, ValueError):
        return WEEKDAY_LABELS[datetime.now().weekday()]
    return WEEKDAY_LABELS[d.weekday()]


def estimate_calories(type_: str, minutes: int, intensity: str) -> int:
    """분·강도로 소모 칼로리 추정. 회원 앱과 같은 표를 쓴다."""
    per_min = _KCAL_PER_MIN.get(type_, _KCAL_PER_MIN["other"])
    factor = _INTENSITY_FACTOR.get(intensity, 1.0)
    return round(per_min * max(minutes, 0) * factor)


def _date_label_for_day(day_label: str) -> str:
    now = datetime.now()
    today_idx = now.weekday()  # 0=월
    if day_label not in WEEKDAY_LABELS:
        return day_label
    day_idx = WEEKDAY_LABELS.index(day_label)
    delta = today_idx - day_idx
    if delta == 0:
        return "오늘"
    if delta == 1:
        return "어제"
    if 1 < delta <= 6:
        d = now - timedelta(days=delta)
        return f"{d.month}월 {d.day}일"
    return f"{day_label}요일"


def _default_time_label(t: str) -> str:
    return {
        "cardio": "07:30", "strength": "18:00",
        "yoga": "20:00", "stretching": "20:00", "walking": "12:00",
    }.get(t, "15:00")


def _default_items(t: str) -> list[str]:
    return {
        "cardio": ["러닝머신 30분"],
        "strength": ["스쿼트 3세트", "데드리프트 3세트"],
        "yoga": ["전신 스트레칭 20분"], "stretching": ["전신 스트레칭 20분"],
        "walking": ["공원 산책"],
    }.get(t, [])


def _bucket(t: str) -> str:
    if t in ("cardio", "walking"):
        return "cardio"
    if t == "strength":
        return "strength"
    if t in ("yoga", "stretching"):
        return "stretching"
    return "cardio"


def _longest_streak(daily: list[int]) -> int:
    """'N일 연속' — 운동한 요일 중 가장 긴 연속 구간의 길이.

    활성 일수의 단순 합계가 아니다: 월·수·금 운동은 3일이 아니라 1일 연속.
    프론트 `longestActiveStreak` / LocalApiInterceptor 와 같은 정의.
    """
    best = run = 0
    for m in daily:
        run = run + 1 if m > 0 else 0
        best = max(best, run)
    return best


def build_current_week(rows: list) -> dict:
    """ExerciseSession row 리스트 → 프론트 계약 형태의 dict."""
    per_day = {l: 0 for l in WEEKDAY_LABELS}
    per_day_cal = {l: 0 for l in WEEKDAY_LABELS}
    per_cardio = {l: 0 for l in WEEKDAY_LABELS}
    per_strength = {l: 0 for l in WEEKDAY_LABELS}
    per_stretch = {l: 0 for l in WEEKDAY_LABELS}
    total_minutes = 0
    total_calories = 0
    sessions = []

    for r in rows:
        total_minutes += r.minutes
        total_calories += r.calories
        per_day[r.day_label] = per_day.get(r.day_label, 0) + r.minutes
        per_day_cal[r.day_label] = per_day_cal.get(r.day_label, 0) + r.calories
        bucket_map ={"cardio": per_cardio, "strength": per_strength, "stretching": per_stretch}
        target = bucket_map[_bucket(r.type)]
        target[r.day_label] = target.get(r.day_label, 0) + r.minutes
        sessions.append({
            "id": r.id, "day_label": r.day_label, "type": r.type,
            "minutes": r.minutes, "calories": r.calories,
            "intensity": getattr(r, "intensity", "moderate") or "moderate",
            "source": getattr(r, "source", "member") or "member",
            "date_label": _date_label_for_day(r.day_label),
            "time_label": _default_time_label(r.type),
            "items": _default_items(r.type),
        })

    # 최근 요일 먼저
    sessions.sort(key=lambda s: WEEKDAY_LABELS.index(s["day_label"]), reverse=True)

    daily = [per_day[l] for l in WEEKDAY_LABELS]
    streak = _longest_streak(daily)

    msg = (
        "주간 운동 목표 80%를 달성했어요! 오늘 가볍게 걷기를 더해 100%를 채워봐요."
        if total_minutes >= 240
        else "이번 주는 운동량이 조금 부족해요. 가벼운 산책부터 다시 시작해 봐요."
    )

    return {
        "sessions": sessions,
        "daily_minutes": daily,
        "daily_calories": [per_day_cal[l] for l in WEEKDAY_LABELS],
        "cardio_minutes": [per_cardio[l] for l in WEEKDAY_LABELS],
        "strength_minutes": [per_strength[l] for l in WEEKDAY_LABELS],
        "stretching_minutes": [per_stretch[l] for l in WEEKDAY_LABELS],
        "day_labels": WEEKDAY_LABELS,
        "total_minutes": total_minutes,
        "total_calories": total_calories,
        "streak_days": streak,
        "ai_coach_message": msg,
    }
