"""
운동 주간 집계 서비스 — 프론트 _exerciseCurrentWeek 로직을 그대로 재현.

핵심 규칙(프론트와 동일):
- 요일 라벨: 월~일 (월=index 0)
- 타입 버킷: 유산소 / 근력 / 유연성 / 기타 네 가지(app.services.exercise_types).
  옛 값(walking·yoga·stretching)은 읽는 자리에서 접어 준다.
- date_label: 오늘/어제/MM월 DD일/N요일 (요일 라벨 → 날짜 환산)
- time_label, items: 타입별 기본값 합성 (drift 스키마에 없는 표시용 데이터)
- streak: 운동한 요일 중 가장 긴 연속 구간의 길이 ("N일 연속"). 활성 일수의 단순
  합계가 아니다 — 월·수·금 운동은 3일이 아니라 1일 연속. 프론트의
  `longestActiveStreak` 와 같은 정의.
- sessions 정렬: 최근 요일 먼저
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

from app.core import clock
from app.services import exercise_types, period_window

WEEKDAY_LABELS = ["월", "화", "수", "목", "금", "토", "일"]

#: 운동 타입별 분당 소모 칼로리. 회원 앱의 `_estimateCalories`
#: (`exercise_flows.dart`) 표를 그대로 옮긴 값이다 — 수기 입력은 앱이 계산해
#: 보내고 PT 완료분은 서버가 계산하므로, 두 값이 다르면 같은 운동인데 회원
#: 화면에서 칼로리가 갈린다.
_KCAL_PER_MIN = {
    exercise_types.CARDIO: 9.0,
    exercise_types.STRENGTH: 6.0,
    exercise_types.FLEXIBILITY: 3.0,
    exercise_types.OTHER: 5.0,
}

#: 강도 배수 — 회원 앱 `_intensityFactor` 와 같다.
_INTENSITY_FACTOR = {"light": 0.85, "moderate": 1.0, "high": 1.2}

#: 근력 1세트가 차지하는 벽시계 시간(세트 + 휴식). 회원 앱
#: `kStrengthMinutesPerSetWithRest` 와 같은 값이다 — 세트를 모르는 옛 기록을
#: 세트로 되짚을 때만 쓴다. (#1262)
STRENGTH_MINUTES_PER_SET = 3.0


def sets_of(row) -> int:
    """근력 기록의 세트 수. 적혀 있으면 그 값, 없으면 분에서 환산한 값."""
    recorded = getattr(row, "sets", None)
    if recorded:
        return int(recorded)
    return round(row.minutes / STRENGTH_MINUTES_PER_SET)


def session_date_of(row) -> date | None:
    """기록의 실제 날짜. 저장은 (주 시작 + 요일 라벨)로 쪼개져 있다. (#1276)

    요일만으로는 몇 주 전 기록과 이번 주 기록이 구분되지 않는다 — 앱이 수정
    시트를 열 때 원래 날짜를 되살리려면 여기서 되돌려야 한다. 값이 깨졌으면
    None 이다: 지어낸 날짜보다 빈 칸이 낫다.
    """
    try:
        monday = date.fromisoformat(row.week_start)
        return monday + timedelta(days=WEEKDAY_LABELS.index(row.day_label))
    except (AttributeError, TypeError, ValueError):
        return None


def monday_of_this_week_str() -> str:
    today = clock.today()
    return (today - timedelta(days=today.weekday())).isoformat()


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
        return WEEKDAY_LABELS[clock.today().weekday()]
    return WEEKDAY_LABELS[d.weekday()]


def estimate_calories(type_: str, minutes: int, intensity: str) -> int:
    """분·강도로 소모 칼로리 추정. 회원 앱과 같은 표를 쓴다.

    운동 유형은 정규화해서 본다 — 옛 값(`walking`·`yoga`)으로 저장된 기록도
    같은 표를 타야 회원 화면에서 칼로리가 갈리지 않는다.
    """
    per_min = _KCAL_PER_MIN.get(
        exercise_types.normalize(type_), _KCAL_PER_MIN[exercise_types.OTHER]
    )
    factor = _INTENSITY_FACTOR.get(intensity, 1.0)
    return round(per_min * max(minutes, 0) * factor)


def _date_label_for_day(day_label: str) -> str:
    today = clock.today()
    today_idx = today.weekday()  # 0=월
    if day_label not in WEEKDAY_LABELS:
        return day_label
    day_idx = WEEKDAY_LABELS.index(day_label)
    delta = today_idx - day_idx
    if delta == 0:
        return "오늘"
    if delta == 1:
        return "어제"
    if 1 < delta <= 6:
        d = today - timedelta(days=delta)
        return f"{d.month}월 {d.day}일"
    return f"{day_label}요일"


def _default_time_label(t: str) -> str:
    return {
        exercise_types.CARDIO: "07:30",
        exercise_types.STRENGTH: "18:00",
        exercise_types.FLEXIBILITY: "20:00",
    }.get(exercise_types.normalize(t), "15:00")


def _default_items(t: str) -> list[str]:
    return {
        exercise_types.CARDIO: ["러닝머신 30분"],
        exercise_types.STRENGTH: ["스쿼트 3세트", "데드리프트 3세트"],
        exercise_types.FLEXIBILITY: ["전신 스트레칭 20분"],
    }.get(exercise_types.normalize(t), [])


def _bucket(t: str) -> str:
    """집계 축. 기타는 유산소가 아니라 자기 칸으로 간다 (#996)."""
    return exercise_types.normalize(t)


#: 프로필에 목표가 없을 때 쓰는 기본값. 회원 앱의 `UserProfile` 기본값과 같다 —
#: 두 앱이 다른 기본값을 쓰면 같은 회원의 그래프에 다른 목표선이 그려진다.
DEFAULT_WEEKLY_MINUTES_GOAL = 150
DEFAULT_WEEKLY_BURN_GOAL = 500


def weekly_goals(profile) -> tuple[int, int]:
    """(주간 운동 시간 목표, 주간 소모 칼로리 목표). 프로필이 없으면 기본값."""
    minutes = getattr(profile, "weekly_exercise_minutes_goal", None)
    calories = getattr(profile, "weekly_burn_goal", None)
    return (
        minutes if minutes and minutes > 0 else DEFAULT_WEEKLY_MINUTES_GOAL,
        calories if calories and calories > 0 else DEFAULT_WEEKLY_BURN_GOAL,
    )


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
    per_flex = {l: 0 for l in WEEKDAY_LABELS}
    per_other = {l: 0 for l in WEEKDAY_LABELS}
    per_sets = {l: 0 for l in WEEKDAY_LABELS}
    total_minutes = 0
    total_calories = 0
    sessions = []

    for r in rows:
        total_minutes += r.minutes
        total_calories += r.calories
        per_day[r.day_label] = per_day.get(r.day_label, 0) + r.minutes
        per_day_cal[r.day_label] = per_day_cal.get(r.day_label, 0) + r.calories
        bucket_map = {
            exercise_types.CARDIO: per_cardio,
            exercise_types.STRENGTH: per_strength,
            exercise_types.FLEXIBILITY: per_flex,
            exercise_types.OTHER: per_other,
        }
        bucket = _bucket(r.type)
        target = bucket_map[bucket]
        target[r.day_label] = target.get(r.day_label, 0) + r.minutes
        if bucket == exercise_types.STRENGTH:
            per_sets[r.day_label] = per_sets.get(r.day_label, 0) + sets_of(r)
        sessions.append({
            "id": r.id, "day_label": r.day_label, "type": r.type,
            "date": session_date_of(r),
            "name": getattr(r, "name", "") or "",
            "minutes": r.minutes,
            "sets": getattr(r, "sets", None),
            "weight": getattr(r, "weight", None),
            "calories": r.calories,
            "intensity": getattr(r, "intensity", "moderate") or "moderate",
            "source": getattr(r, "source", "member") or "member",
            "assigned_routine_id": getattr(r, "assigned_routine_id", None),
            "assigned_routine_name": getattr(r, "assigned_routine_name", "") or "",
            "member_note": getattr(r, "member_note", "") or "",
            "trainer_feedback": getattr(r, "trainer_feedback", "") or "",
            "completed_at": getattr(r, "completed_at", None),
            "date_label": _date_label_for_day(r.day_label),
            "time_label": _default_time_label(r.type),
            # 회원이 적은 이름이 있으면 그게 이 기록의 내용이다. 없을 때만
            # 유형별 기본 문구로 채운다 — 이름 칸이 생기기 전 기록들이다. (#1276)
            "items": (
                [getattr(r, "assigned_routine_name", "")]
                if getattr(r, "assigned_routine_name", "")
                else [r.name] if getattr(r, "name", "")
                else _default_items(r.type)
            ),
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
        "strength_sets": [per_sets[l] for l in WEEKDAY_LABELS],
        "flexibility_minutes": [per_flex[l] for l in WEEKDAY_LABELS],
        "other_minutes": [per_other[l] for l in WEEKDAY_LABELS],
        # 옛 이름. 아직 이 필드를 읽는 클라이언트가 있어 같은 값을 함께 내려준다.
        # 두 앱이 flexibility_minutes 로 옮긴 뒤에 지운다. (#996)
        "stretching_minutes": [per_flex[l] for l in WEEKDAY_LABELS],
        "day_labels": WEEKDAY_LABELS,
        "total_minutes": total_minutes,
        "total_calories": total_calories,
        "streak_days": streak,
        "ai_coach_message": msg,
    }


# --- 기간별 운동 조언 (#1025) -------------------------------------------------
#
# 식단이 먼저 한 것(#1017)과 같은 규칙이다. 기간을 바꾸는 것은 "무엇을 볼지" 를
# 바꾸는 일인데, 그래프만 갈리고 조언이 오늘 이야기로 남으면 이번 주를 보면서
# "오늘은 유산소를 했네요" 를 읽게 된다.
#
# 없는 기록으로 조언을 지어내지 않는다 — 기록이 없으면 없다고 말한다.


@dataclass(frozen=True)
class ExerciseDayTotals:
    """하루치 운동 합계. **기록이 있는 날만** 만들어진다."""

    date: date
    minutes: int
    calories: int
    #: 유형별 시간(분). 키는 `exercise_types` 의 네 가지다.
    by_type: dict[str, int]

    @property
    def main_type(self) -> str:
        """그날 가장 오래 한 유형. 같으면 유산소 → 근력 → 유연성 → 기타 순."""
        order = [
            exercise_types.CARDIO,
            exercise_types.STRENGTH,
            exercise_types.FLEXIBILITY,
            exercise_types.OTHER,
        ]
        return max(order, key=lambda t: (self.by_type.get(t, 0), -order.index(t)))


def _date_of(week_start: str, day_label: str) -> date | None:
    """`week_start`(월요일) + 요일 라벨 → 실제 날짜.

    운동 기록은 날짜가 아니라 (그 주 월요일, 요일) 로 저장된다. 구간을 물어보려면
    실제 날짜로 되돌려야 한다.
    """
    if day_label not in WEEKDAY_LABELS:
        return None
    try:
        monday = date.fromisoformat(week_start)
    except ValueError:
        return None
    return monday + timedelta(days=WEEKDAY_LABELS.index(day_label))


def daily_totals(rows: list, start: str, end: str) -> list[ExerciseDayTotals]:
    """[start, end] 구간의 기록 있는 날만 날짜순으로. (#1025)

    기록이 없는 날을 0 으로 채우지 않는다 — 쉰 날과 적지 않은 날은 다른 말이고,
    평균이 그 차이를 삼키면 조언이 사실과 어긋난다.
    """
    per_day: dict[date, dict] = {}
    for row in rows:
        when = _date_of(row.week_start, row.day_label)
        if when is None or not (start <= when.isoformat() <= end):
            continue
        bucket = per_day.setdefault(
            when, {"minutes": 0, "calories": 0, "by_type": {}}
        )
        bucket["minutes"] += row.minutes or 0
        bucket["calories"] += row.calories or 0
        kind = exercise_types.normalize(row.type)
        bucket["by_type"][kind] = bucket["by_type"].get(kind, 0) + (row.minutes or 0)
    return [
        ExerciseDayTotals(
            date=when,
            minutes=v["minutes"],
            calories=v["calories"],
            by_type=v["by_type"],
        )
        for when, v in sorted(per_day.items())
    ]


def _avg(values: list[int]) -> float:
    return sum(values) / len(values) if values else 0


def period_coach_message(days: list[ExerciseDayTotals], period: str) -> str:
    """기간에 맞는 운동 조언. (#1025)

    기간마다 **재료가 다르다.** 오늘은 오늘 한 운동, 이번 주는 며칠 움직였고
    무엇에 치우쳤는지, 전체는 최근 4주와 그 이전의 추세다. 말투도 다르다 —
    오늘은 다음 한 걸음을 제안하고, 이번 주·전체는 되짚어 준다.
    """
    if not days:
        if period == period_window.PERIOD_WEEK:
            return "이번 주 운동 기록이 아직 없어요. 가벼운 산책 한 번도 흐름이 됩니다."
        if period == period_window.PERIOD_ALL:
            return "기록이 쌓이면 운동량과 유형의 흐름을 짚어 드릴게요."
        return "아직 오늘 운동 기록이 없어요. 10분 걷기부터 시작해 볼까요?"

    if period == period_window.PERIOD_TODAY:
        today = days[-1]
        label = exercise_types.label_for(today.main_type)
        return (
            f"오늘 {label} 위주로 {today.minutes}분, {today.calories}kcal 를 썼어요. "
            "마무리로 가볍게 스트레칭하면 회복이 빨라져요."
        )

    total_minutes = sum(d.minutes for d in days)
    active_days = len(days)

    if period == period_window.PERIOD_WEEK:
        if active_days <= 1:
            return (
                f"이번 주는 {active_days}일 움직였어요. "
                "한 번 더 나가면 흐름이 끊기지 않아요."
            )
        # 한 유형에 쏠렸는지 — 코칭에서 가장 먼저 짚는 지점이다.
        by_type: dict[str, int] = {}
        for d in days:
            for kind, minutes in d.by_type.items():
                by_type[kind] = by_type.get(kind, 0) + minutes
        top = max(by_type, key=lambda k: by_type[k]) if by_type else None
        if top is not None and total_minutes and by_type[top] / total_minutes >= 0.8:
            missing = (
                exercise_types.STRENGTH
                if top == exercise_types.CARDIO
                else exercise_types.CARDIO
            )
            return (
                f"이번 주 {active_days}일 {total_minutes}분을 채웠는데 "
                f"{exercise_types.label_for(top)} 에 몰려 있어요. "
                f"{exercise_types.label_for(missing)} 를 한 번 섞어 볼까요?"
            )
        return (
            f"이번 주 {active_days}일 동안 {total_minutes}분 운동했어요. "
            "유형도 고르게 섞였네요. 이 흐름을 이어가요."
        )

    # 전체 — 최근 4주와 그 이전을 견준다. "나아지는 중인가" 가 이 화면의 질문이다.
    recent_from = days[-1].date - timedelta(days=27)
    recent = [d.minutes for d in days if d.date >= recent_from]
    earlier = [d.minutes for d in days if d.date < recent_from]
    if earlier and recent:
        if _avg(recent) > _avg(earlier) * 1.1:
            return (
                "최근 4주 운동량이 그 전보다 늘었어요. "
                "지금 방식이 회원님께 맞는 것 같아요."
            )
        if _avg(recent) < _avg(earlier) * 0.9:
            return (
                "최근 4주 들어 운동량이 줄고 있어요. "
                "무엇이 달라졌는지 한 주만 되짚어 볼까요?"
            )
    return (
        f"기록을 통틀어 {active_days}일 {total_minutes}분을 움직였어요. "
        "큰 기복 없이 이어가고 있어요."
    )
