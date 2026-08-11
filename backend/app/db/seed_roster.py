"""로스터 확장 회원(4~15번)의 주간 지표 시드.

트레이너 웹의 목업 로스터(`frontend/flutter_trainer/lib/core/storage/seed_clients.dart`)
는 고객 15명을 **화면 상태의 fixture** 로 설계했다 — 나트륨 초과, 이행률 저조, 휴면,
답장 대기, 짧은 스파크라인 같은 상태를 클릭만으로 도달할 수 있게 하려고 고른 숫자다.
실 API 시드는 3명뿐이라 실서버로 전환하면 그 상태 대부분이 재현되지 않았다(#572).

여기서는 **지표를 만들 최소 기록만** 넣는다. 로스터의 주간 지표는 저장 필드가 아니라
실데이터에서 계산되기 때문이다(`trainer_service._sodium_week` / `_week_completion`).
따라서 "계정만 만들고 지표를 채운다"는 불가능하고, 하루치 식단·운동 기록이 곧 지표다.

기존 3명(김민수·이지수·박성호)의 풍부한 상세 데이터(끼니별 음식·피드백·트레이너 메모·
채팅·스케줄)는 `seed_member_data.py` 가 계속 담당한다. 여기 12명은 로스터·차트·경고가
동작할 만큼만 채우고 상세는 비운다.
"""
from __future__ import annotations

import json
import logging
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core import clock
from app.db.session import SessionLocal
from app.models import models

logger = logging.getLogger(__name__)

#: 목업 로스터에서 옮긴 주간 지표.
#:
#: * ``sodium``  — 최근 7일 일별 나트륨(오래된→오늘). `_sodium_week` 가 날짜별 합으로 읽는다.
#: * ``completion`` — 이번 주 월→일 일별 완료율. `_week_completion` 이 날짜별 최댓값으로 읽는다.
#:   0 인 날은 "기록 없음" 이므로 행을 만들지 않는다(경고 규칙이 0 을 평균에서 제외한다).
#: * ``awaiting`` — 회원이 마지막으로 말한 채로 남은 스레드(답장 대기 배지).
#:
#: 7개보다 짧은 나트륨 배열은 의도된 것이다 — 기록이 끊겼거나(문가영) 이제 막
#: 시작한(노은채) 고객의 짧은 스파크라인을 그리기 위한 값이다. 끊긴 쪽은 과거에,
#: 시작한 쪽은 오늘에 붙인다.
_METRICS: dict[str, dict] = {
    "user-hayun": {  # 정하윤 — V자: 무너졌다 회복, 나트륨 급락 후 반등
        "sodium": [2900, 2600, 1500, 1250, 1400, 1900, 1650],
        "completion": [100, 25, 0, 0, 50, 100, 100],
        "awaiting": False,
    },
    "user-woojin": {  # 최우진 — 완벽한 주(경고 0). 정상 상태의 기준선
        "sodium": [1300, 1250, 1100, 1200, 1150, 1090, 1180],
        "completion": [100, 100, 100, 100, 100, 100, 100],
        "awaiting": False,
    },
    "user-kangseoyeon": {  # 강서연 — 주중 완벽, 주말에 나트륨 폭발
        "sodium": [1400, 1350, 1500, 1420, 1380, 3100, 2750],
        "completion": [100, 100, 100, 100, 100, 0, 0],
        "awaiting": False,
    },
    "user-dohyun": {  # 임도현 — 기록 전무(빈 상태 화면)
        "sodium": [],
        "completion": [0, 0, 0, 0, 0, 0, 0],
        "awaiting": False,
    },
    "user-sera": {  # 오세라 — 우하향: 이행률 붕괴 + 나트륨 상승
        "sodium": [1900, 2150, 2400, 2650, 2900, 3050, 3250],
        "completion": [80, 60, 40, 33, 20, 0, 0],
        "awaiting": True,
    },
    "user-junhyuk": {  # 배준혁 — 야근형: 이행률 저조 + 나트륨 들쭉날쭉
        "sodium": [2100, 2600, 1800, 2900, 2200, 1600, 2280],
        "completion": [50, 0, 33, 0, 25, 0, 0],
        "awaiting": True,
    },
    "user-yuna": {  # 신유나 — 회복 중: 나트륨 우하향, 이행률 우상향
        "sodium": [2800, 2500, 2200, 1950, 1800, 1750, 1720],
        "completion": [0, 0, 33, 67, 100, 100, 100],
        "awaiting": False,
    },
    "user-jiho": {  # 한지호 — 정체기: 목표선 위아래로 진동(경계값)
        "sodium": [1990, 2010, 1995, 2005, 1998, 2015, 2010],
        "completion": [67, 67, 67, 67, 67, 67, 67],
        "awaiting": False,
    },
    "user-gayoung": {  # 문가영 — 휴면: 주 3일치만 기록되고 끊김
        "sodium": [2100, 1950, 1030],
        "completion": [33, 0, 0, 0, 0, 0, 0],
        "awaiting": True,
        "anchor": "past",
    },
    "user-taekyung": {  # 류태경 — 극단: 0↔100, 1200↔3200 지그재그
        "sodium": [1200, 3100, 1350, 2950, 1100, 3200, 3100],
        "completion": [100, 0, 100, 0, 100, 0, 0],
        "awaiting": True,
    },
    "user-seojin": {  # 백서진 — 운동은 완벽한데 나트륨만 계속 초과
        "sodium": [2400, 2550, 2700, 2600, 2800, 2650, 2680],
        "completion": [100, 100, 100, 100, 100, 100, 100],
        "awaiting": False,
    },
    "user-eunchae": {  # 노은채 — 단 하루만 기록(단일 포인트 스파크라인)
        "sodium": [1450],
        "completion": [100, 0, 0, 0, 0, 0, 0],
        "awaiting": False,
        "anchor": "today",
    },
}

#: 상세 기록은 기존 3명만 둔다. 여기 12명의 식단은 지표를 만들기 위한 한 줄짜리다.
_MEAL_NAME = "기록된 식사"
_ROUTINE_LABEL = "AI 루틴 · 자율 운동"
_AWAITING_TEXT = "트레이너님, 이번 주 루틴 관련해서 여쭤볼 게 있어요."


def seed_roster_metrics() -> None:
    """확장 회원의 주간 지표용 최소 기록을 시드(멱등)."""
    db: Session = SessionLocal()
    try:
        for member_id, spec in _METRICS.items():
            if db.get(models.User, member_id) is None:
                continue  # 계정 시드가 건너뛴 회원(이메일 충돌 등)
            _seed_sodium_days(db, member_id, spec)
            _seed_completion_days(db, member_id, spec["completion"])
            if spec.get("awaiting"):
                _seed_awaiting_message(db, member_id)
        db.commit()
    finally:
        db.close()


def _sodium_offsets(values: list[int], anchor: str) -> list[tuple[int, int]]:
    """(오늘로부터 며칠 전, 나트륨) 목록.

    7개면 6일 전~오늘에 그대로 얹는다. 짧으면 [anchor] 를 따른다 — 기록이 끊긴
    고객은 과거에, 이제 시작한 고객은 오늘에 붙어야 스파크라인이 이야기와 맞는다.
    """
    if not values:
        return []
    if len(values) >= 7:
        return [(6 - i, v) for i, v in enumerate(values[-7:])]
    if anchor == "today":
        return [(len(values) - 1 - i, v) for i, v in enumerate(values)]
    return [(6 - i, v) for i, v in enumerate(values)]


def _seed_sodium_days(db: Session, member_id: str, spec: dict) -> None:
    today = clock.today()
    for offset, sodium in _sodium_offsets(spec["sodium"], spec.get("anchor", "recent")):
        date = (today - timedelta(days=offset)).isoformat()
        entry_id = f"seed-roster-diet-{member_id}-{date}"
        if db.get(models.DietEntry, entry_id) is not None:
            continue
        # 하루 한 줄. 끼니별 상세는 기존 3명만 가진다.
        calories = 500 + (sodium // 10)
        db.add(models.DietEntry(
            id=entry_id,
            user_id=member_id,
            date=date,
            meal_type="lunch",
            time_label="12:30",
            foods_json=json.dumps(
                [{"name": _MEAL_NAME, "calories": calories}], ensure_ascii=False
            ),
            total_calories=calories,
            sodium_mg=sodium,
            sugar_g=float(sodium) / 60.0,
        ))


def _seed_completion_days(db: Session, member_id: str, completion: list[int]) -> None:
    monday = clock.today() - timedelta(days=clock.today().weekday())
    for i, rate in enumerate(completion):
        if rate <= 0:
            continue  # 기록 없음 — 행을 만들면 '0% 수행'이라는 다른 뜻이 된다
        date = (monday + timedelta(days=i)).isoformat()
        hist_id = f"seed-roster-hist-{member_id}-{date}"
        if db.get(models.RoutineHistory, hist_id) is not None:
            continue
        db.add(models.RoutineHistory(
            id=hist_id,
            member_id=member_id,
            trainer_id=None,
            date=date,
            kind_label=_ROUTINE_LABEL,
            completion_rate=rate,
            exercises_json=json.dumps([], ensure_ascii=False),
        ))


def _seed_awaiting_message(db: Session, member_id: str) -> None:
    """회원이 마지막으로 말한 채로 남은 스레드(답장 대기 배지)."""
    from app.db.seed_trainer import TRAINER_ID

    msg_id = f"seed-roster-chat-{member_id}"
    if db.get(models.ChatMessage, msg_id) is not None:
        return
    exists = db.scalar(
        select(models.ChatMessage.id)
        .where(
            models.ChatMessage.trainer_id == TRAINER_ID,
            models.ChatMessage.member_id == member_id,
        )
        .limit(1)
    )
    if exists is not None:
        return
    db.add(models.ChatMessage(
        id=msg_id,
        trainer_id=TRAINER_ID,
        member_id=member_id,
        sender="member",
        body=_AWAITING_TEXT,
        created_at=clock.now(),
    ))
