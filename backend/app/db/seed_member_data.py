"""
담당 회원의 건강 데이터 데모 시드 — 트레이너 로스터/식단/기록을 실데이터로 채운다.

여기서 넣는 식단(DietEntry)·운동기록(RoutineHistory)은 "회원이 회원 앱에서 남긴
실제 데이터"다. 트레이너 API 는 이 데이터를 그대로 읽어 로스터를 집계하므로,
트레이너↔회원 데이터 공유가 시드 단계에서부터 실제로 성립한다.

멱등 + 날짜 인식:
- 오늘 식단은 회원에게 오늘 DietEntry 가 없을 때만 3끼를 넣는다.
- 최근 6일 나트륨 추세는 해당 날짜에 DietEntry 가 없을 때만 1건씩 넣는다
  (이미 '오늘'로 들어갔던 날은 건너뛰어 중복 합산을 막는다).
- 운동기록은 회원에게 오늘 기록이 없을 때만 최근 3세션을 넣는다.
날짜가 넘어가면 자연히 '오늘'이 새로 시드되고 과거 데이터는 누적되어 실제 이력이 된다.
"""
from __future__ import annotations

import json
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.seed_trainer import TRAINER_ID, _MEMBERS
from app.db.session import SessionLocal
from app.models import models

# 회원별 오늘 3끼 (meal_type, 음식, 칼로리, 나트륨, 당류) — 프론트 seed 와 동일 수치.
# 하루 나트륨 합 == _SODIUM_WEEK[member][-1](오늘) 이 되도록 맞춰 둠.
_TODAY_MEALS: dict[str, list[tuple[str, str, int, int, int]]] = {
    "user-demo": [
        ("breakfast", "오트밀, 바나나", 315, 380, 0),
        ("lunch", "닭가슴살 샐러드, 현미밥", 620, 890, 45),
        ("dinner", "두부찌개, 잡곡밥", 485, 830, 0),
    ],
    "user-jisu": [
        ("breakfast", "그릭요거트, 과일", 280, 200, 38),
        ("lunch", "현미밥, 불고기, 나물", 750, 980, 0),
        ("dinner", "연어 샐러드", 650, 620, 0),
    ],
    "user-sungho": [
        ("breakfast", "계란 3개, 토스트", 480, 520, 0),
        ("lunch", "짜장면", 890, 1200, 55),
        ("dinner", "삼겹살, 쌈채소", 730, 680, 0),
    ],
}

# 최근 7일 일별 나트륨(오래된→오늘). 마지막 값은 오늘 3끼 합과 일치.
_SODIUM_WEEK: dict[str, list[int]] = {
    "user-demo": [2400, 2200, 1900, 2050, 2300, 1850, 2100],
    "user-jisu": [1700, 1950, 1600, 1800, 2100, 1750, 1800],
    "user-sungho": [2600, 2500, 2300, 2450, 2200, 2550, 2400],
}

# 최근 운동 세션(최신순): (완료율, 종류라벨, 운동목록, 회원피드백, 트레이너메모).
# 오늘/이틀전/나흘전 날짜로 시드. PT 세션은 trainer_id 를 붙인다.
_HISTORY: dict[str, list[tuple[int, str, list[str], str, str]]] = {
    "user-demo": [
        (100, "PT 세션 · 트레이너 지도", ["레그프레스 3세트", "레그컬 3세트", "하체 스트레칭"],
         "무릎이 좀 당겼지만 트레이너님 덕분에 잘 마쳤어요 😊",
         "무릎 가동범위 체크 필요. 다음 세션 중량 조절 예정."),
        (67, "AI 루틴 · 자율 운동", ["걷기 30분 ✓", "코어 강화 10분 ✓", "스트레칭 ✗ (생략)"],
         "스트레칭은 시간이 없어서 못 했어요", ""),
        (100, "AI 루틴 · 자율 운동", ["걷기 30분 ✓", "코어 강화 10분 ✓", "하체 스트레칭 15분 ✓"],
         "오늘은 다 했어요! 뿌듯해요 💪", ""),
    ],
    "user-jisu": [
        (100, "AI 루틴 · 자율 운동", ["인터벌 런닝 25분 ✓", "스쿼트 3세트 ✓", "플랭크 10분 ✓"],
         "런닝이 힘들었는데 다 했어요! 숨이 많이 찼어요",
         "심폐지구력 향상 중. 다음 주 런닝 강도 소폭 올릴 예정."),
        (100, "PT 세션 · 트레이너 지도", ["데드리프트 3세트", "런지 3세트", "코어 서킷"],
         "데드리프트 자세 교정 도움 많이 됐어요!", ""),
        (67, "AI 루틴 · 자율 운동", ["런닝 25분 ✓", "스쿼트 ✓", "플랭크 ✗ (피로)"],
         "마지막 플랭크는 너무 지쳐서 못 했어요", ""),
    ],
    "user-sungho": [
        (100, "PT 세션 · 트레이너 지도", ["벤치프레스 4세트", "인클라인 덤벨 3세트", "트라이셉스 딥"],
         "가슴이 많이 타는 느낌이었어요. 좋았어요!",
         "벤치 중량 62.5kg → 65kg 도전 가능. 다음 PT 때 시도 예정."),
        (33, "AI 루틴 · 자율 운동", ["벤치프레스 ✓", "데드리프트 ✗", "유산소 ✗"],
         "회사 일이 생겨서 벤치만 하고 나왔어요", ""),
        (0, "AI 루틴 · 자율 운동", ["벤치프레스 ✗", "데드리프트 ✗", "유산소 ✗"],
         "못 갔어요 😓", ""),
    ],
}


def _valid_member_ids(db: Session) -> set[str]:
    """트레이너 데모에 실제로 링크되고 회원 역할인 member_id 집합.

    이메일 충돌 등으로 회원 계정/링크가 만들어지지 않았으면(#249 시드가 스킵) 그 회원의
    건강 데이터를 넣으면 FK 오류로 기동이 죽는다. 유효한 회원만 시드 대상으로 삼는다.
    """
    rows = db.execute(
        select(models.TrainerClient.member_id)
        .join(models.User, models.User.id == models.TrainerClient.member_id)
        .where(
            models.TrainerClient.trainer_id == TRAINER_ID,
            models.User.role == "member",
        )
    ).all()
    return {r[0] for r in rows}


# 회원별 채팅 스레드 (sender: trainer|client, text) — 프론트 seed_data 정렬.
_CHAT: dict[str, list[tuple[str, str]]] = {
    "user-demo": [
        ("trainer", "민수님, AI 식단 분석 잘 받았어요 👍 오늘 나트륨이 목표치를 좀 넘었는데 어떠셨어요?"),
        ("client", "찌개 먹을 때 국물을 많이 마셨나봐요 😅"),
        ("trainer", "그렇군요! 오늘 PT 후에 부상이나 불편한 데는 없으셨나요?"),
        ("client", "무릎이 가볍게 당기긴 했는데 괜찮아요"),
        ("trainer", "확인했어요. AI가 오늘 식단 기반으로 유산소 루틴을 추천했는데, 무릎 상태 감안해서 "
                    "런닝 대신 걷기로 조정해서 보낼게요. 다음 PT 때 봐요 💪"),
    ],
    "user-jisu": [
        ("trainer", "지수님, AI 운동 데이터 수신했어요 — 오늘 인터벌 런닝 25분 완료! 컨디션은 어때요?"),
        ("client", "생각보다 괜찮았어요. 숨이 금방 차더라고요 😮‍💨"),
        ("trainer", "심폐 지구력 올라가는 과정이에요 💪 AI 분석 보니까 당류는 목표 안에 있고, "
                    "루틴 다음 주부터 근력 비중 늘려볼게요. 식단도 AI 추천 참고해서 업데이트해 드릴게요"),
    ],
    "user-sungho": [
        ("trainer", "성호님, 이번 주 운동 기록이 AI 쪽에서 안 잡히는데 몸은 괜찮으세요?"),
        ("client", "이번 주 일이 너무 많아서 못 갔어요 😓"),
        ("trainer", "이해해요! 대신 AI 식단 분석 보니까 나트륨이 좀 높더라고요. 주말에 30분 걷기라도 하면 "
                    "도움 돼요. AI가 그에 맞는 루틴 다시 짜줬으니까 앱에서 확인해보세요 🙂"),
    ],
}

# 회원별 AI 배정 루틴 (name, minutes, type, reason) — 프론트 aiRoutine 정렬.
_ROUTINES: dict[str, list[tuple[str, int, str, str]]] = {
    "user-demo": [
        ("저강도 유산소 (걷기)", 30, "유산소", "혈압 안정에 효과적"),
        ("하체 스트레칭", 15, "스트레칭", "혈액순환 개선"),
        ("코어 강화", 10, "근력", "기초대사량 향상"),
    ],
    "user-jisu": [
        ("인터벌 런닝", 25, "유산소", "체지방 연소 효율↑"),
        ("스쿼트 3세트", 15, "근력", "하체 근력 강화"),
        ("플랭크", 10, "근력", "코어 안정화"),
    ],
    "user-sungho": [
        ("벤치프레스 4세트", 20, "근력", "상체 근력 목표"),
        ("데드리프트 3세트", 15, "근력", "전신 근력 향상"),
        ("유산소 쿨다운", 10, "유산소", "나트륨 배출 지원"),
    ],
}


def seed_member_health_data() -> None:
    db: Session = SessionLocal()
    try:
        valid = _valid_member_ids(db)
        for user_id, *_ in _MEMBERS:
            if user_id not in valid:
                # 계정/링크 없음(이메일 충돌 등) → FK 오류 방지 위해 건너뛴다.
                continue
            _seed_diet(db, user_id)
            _seed_history(db, user_id)
            _seed_chat(db, user_id)
            _seed_routines(db, user_id)
    finally:
        db.close()


def _seed_chat(db: Session, member_id: str) -> None:
    """트레이너↔회원 채팅 스레드(멱등, 결정론적 id). 최근 시각으로 정렬되게 시드."""
    thread = _CHAT.get(member_id)
    if not thread:
        return
    # 스레드가 최근으로 보이도록 base 를 몇 시간 전으로 두고 2분 간격.
    base = datetime.now(timezone.utc) - timedelta(hours=2)
    for i, (sender, text) in enumerate(thread):
        cid = f"seed-chat-{member_id}-{i}"
        if db.get(models.ChatMessage, cid) is not None:
            continue
        db.add(models.ChatMessage(
            id=cid,
            trainer_id=TRAINER_ID,
            member_id=member_id,
            sender="member" if sender == "client" else "trainer",
            body=text,
            created_at=base + timedelta(minutes=i * 2),
        ))
    db.commit()


def _seed_routines(db: Session, member_id: str) -> None:
    """AI 배정 루틴 시드(멱등, 결정론적 id)."""
    routines = _ROUTINES.get(member_id)
    if not routines:
        return
    for i, (name, minutes, rtype, reason) in enumerate(routines):
        rid = f"seed-routine-{member_id}-{i}"
        if db.get(models.TrainerRoutine, rid) is not None:
            continue
        db.add(models.TrainerRoutine(
            id=rid,
            trainer_id=TRAINER_ID,
            member_id=member_id,
            name=name,
            minutes=minutes,
            type=rtype,
            reason=reason,
            source="ai",
            sort_order=i,
        ))
    db.commit()


def _has_diet_on(db: Session, member_id: str, day: str) -> bool:
    return db.scalar(
        select(models.DietEntry.id)
        .where(models.DietEntry.user_id == member_id, models.DietEntry.date == day)
        .limit(1)
    ) is not None


def _seed_diet(db: Session, member_id: str) -> None:
    meals = _TODAY_MEALS.get(member_id)
    sodium_week = _SODIUM_WEEK.get(member_id)
    if not meals or not sodium_week:
        return

    today = date.today()
    today_str = today.isoformat()

    # 오늘 3끼 (오늘 기록이 아직 없을 때만)
    if not _has_diet_on(db, member_id, today_str):
        for i, (meal_type, items, cal, na, sugar) in enumerate(meals):
            db.add(models.DietEntry(
                id=f"seed-diet-{member_id}-{today_str}-{i}",
                user_id=member_id,
                date=today_str,
                meal_type=meal_type,
                time_label={"breakfast": "08:00", "lunch": "12:30", "dinner": "19:00"}.get(meal_type, ""),
                foods_json=json.dumps(
                    [{"name": items, "calories": cal, "sodium_mg": na, "sugar_g": sugar}],
                    ensure_ascii=False,
                ),
                total_calories=cal,
                sodium_mg=na,
                sugar_g=sugar,
                engine="seed",
            ))

    # 최근 6일 나트륨 추세 (해당 날짜에 기록이 없을 때만 — 중복 합산 방지)
    for offset in range(1, 7):
        d = (today - timedelta(days=offset)).isoformat()
        if _has_diet_on(db, member_id, d):
            continue
        na = sodium_week[6 - offset]
        db.add(models.DietEntry(
            id=f"seed-diet-{member_id}-{d}-agg",
            user_id=member_id,
            date=d,
            meal_type="lunch",
            time_label="",
            foods_json=json.dumps(
                [{"name": "기록된 식단", "calories": 1500, "sodium_mg": na, "sugar_g": 0}],
                ensure_ascii=False,
            ),
            total_calories=1500,
            sodium_mg=na,
            sugar_g=0,
            engine="seed",
        ))
    db.commit()


def _seed_history(db: Session, member_id: str) -> None:
    sessions = _HISTORY.get(member_id)
    if not sessions:
        return

    today = date.today()
    # 오늘 기록이 이미 있으면 스킵(멱등, 날짜 넘어가면 새로 시드)
    if db.scalar(
        select(models.RoutineHistory.id)
        .where(
            models.RoutineHistory.member_id == member_id,
            models.RoutineHistory.date == today.isoformat(),
        )
        .limit(1)
    ) is not None:
        return

    for idx, (rate, kind, exercises, feedback, note) in enumerate(sessions):
        d = (today - timedelta(days=idx * 2)).isoformat()  # 오늘/이틀전/나흘전
        hid = f"seed-hist-{member_id}-{d}"
        if db.get(models.RoutineHistory, hid) is not None:
            continue
        db.add(models.RoutineHistory(
            id=hid,
            member_id=member_id,
            trainer_id=TRAINER_ID if kind.startswith("PT") else None,
            date=d,
            kind_label=kind,
            completion_rate=rate,
            exercises_json=json.dumps(exercises, ensure_ascii=False),
            client_feedback=feedback,
            trainer_note=note,
        ))
    db.commit()
