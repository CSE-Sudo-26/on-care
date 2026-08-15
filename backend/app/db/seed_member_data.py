"""
담당 회원의 건강 데이터 데모 시드 — 트레이너 로스터/식단/기록을 실데이터로 채운다.

**데모/개발 전용 (실서비스 아님).** 이 시드는 `SEED_DEMO_DATA=true` 일 때만 실행된다
(init_db 게이팅). 실서비스(prod)는 `SEED_DEMO_DATA=false` 로 두어 여기서 만드는 고정
데모 계정(김민수 등)을 넣지 않고, **진짜 사용자가 앱에서 직접 만든 데이터만** 쌓이게
한다. 즉 이 파일은 데모/발표·개발·CI 재현용 고정 데이터이지, 운영 사용자 데이터가 아니다.

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
import logging
import time
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core import clock
from app.core.config import get_settings
from app.db.seed_trainer import TRAINER_ID, _MEMBERS
from app.db.session import SessionLocal
from app.models import models
from app.services.coach import personal_ingest
from app.services.coach.rag import has_personal_doc

logger = logging.getLogger(__name__)


#: PostgreSQL unique_violation. 동시 기동(멀티 인스턴스)이 같은 결정론적 id를 경쟁
#: 삽입할 때만 발생하는 코드로, 이때만 '이미 다른 인스턴스가 넣음'으로 보고 넘긴다.
_PG_UNIQUE_VIOLATION = "23505"


def _safe_commit(db: Session) -> None:
    """시드 커밋. 동시 기동이 같은 결정론적 id를 경쟁 삽입한 UNIQUE 충돌(23505)만
    무시하고 넘어간다. FK(23503)·NOT NULL(23502)·CHECK 등 진짜 오류는 데이터가 롤백된
    채 조용히 기동을 이어가면 안 되므로 다시 발생시켜 기동을 실패시킨다."""
    try:
        db.commit()
    except IntegrityError as e:
        db.rollback()
        sqlstate = getattr(getattr(e, "orig", None), "sqlstate", None)
        if sqlstate != _PG_UNIQUE_VIOLATION:
            raise
        logger.info("member seed commit skipped (already seeded by a concurrent start)")

# 회원별 오늘 3끼 (meal_type, 음식, 칼로리, 나트륨, 당류, 탄수화물, 단백질, 지방)
# — 프론트 seed 와 동일 수치.
# 하루 나트륨 합 == _SODIUM_WEEK[member][-1](오늘) 이 되도록 맞춰 둠.
_TODAY_MEALS: dict[
    str, list[tuple[str, str, int, int, float, float, float, float]]
] = {
    "user-demo": [
        ("breakfast", "스크램블 에그, 딸기", 217, 221, 6.3, 10, 13.5, 14.5),
        ("lunch", "짬뽕", 750, 3200, 8.5, 107, 29, 22.5),
        ("snack", "아이스 아메리카노, 견과류 한 봉", 100, 7, 3, 3, 2.5, 8),
    ],
    "user-jisu": [
        ("breakfast", "그릭요거트, 과일", 280, 200, 38, 40, 15, 6),
        ("lunch", "현미밥, 불고기, 나물", 750, 980, 0, 90, 35, 20),
        ("dinner", "연어 샐러드", 650, 620, 0, 20, 40, 22),
    ],
    "user-sungho": [
        ("breakfast", "계란 3개, 토스트", 480, 520, 0, 35, 28, 24),
        ("lunch", "짜장면", 890, 1200, 55, 120, 25, 30),
        ("dinner", "삼겹살, 쌈채소", 730, 680, 0, 20, 45, 50),
    ],
}

# 최근 7일 일별 나트륨(오래된→오늘). 마지막 값은 오늘 3끼 합과 일치.
#: 시드가 채우는 과거 주 수(이번 주 포함) — `seed_roster` 와 같은 값이다.
_HISTORY_WEEKS = 12

#: 과거 주에 곱하는 계수 — `seed_roster._WEEK_FACTORS` 와 같다.
_WEEK_FACTORS = (1.0, 0.94, 1.08, 0.9, 1.05, 0.97, 1.11)

_SODIUM_WEEK: dict[str, list[int]] = {
    "user-demo": [2400, 2200, 1900, 2050, 2300, 1850, 3428],
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


# 회원별 채팅 스레드 (sender: trainer|client, text, days_ago) — 프론트 시드와 정렬.
#
# user-demo 스레드는 회원 앱·트레이너 앱의 데모 시드와 **같은 대화**여야 한다.
# 김민수는 회원 앱 데모 사용자(user-demo)와 같은 계정이라, 실서버로 붙여도
# 데모에서 보던 대화가 그대로 이어져야 하기 때문이다. 같은 목록이 아래 두 곳에
# 있다 — 한 곳만 고치면 그 파일의 테스트가 깨진다:
#   * frontend/flutter_trainer/lib/core/storage/seed_clients.dart (트레이너 시점)
#   * frontend/flutter/lib/features/member_coach/data/repositories/
#     mock_member_coach_repository.dart (회원 시점)
#
# days_ago 는 그 메시지가 며칠 전 것인지다. 전부 같은 시각에 몰아넣으면 사흘에
# 걸친 대화가 30분짜리 수다로 보이고, 화면이 날짜로 묶는 자리(하루치 AI 분석
# 안내)도 하나로 뭉친다.
_CHAT: dict[str, list[tuple[str, str, int]]] = {
    "user-demo": [
        # 1일차.
        ("trainer", "민수님, 지난주 기록 정리해 봤는데 요일마다 이행률이 들쭉날쭉하네요. 바쁜 요일이 정해져 있나요?", 5),
        ("client", "화요일이랑 목요일이 야근이 많아요 😥", 5),
        ("trainer", "그럼 그 이틀은 15분짜리 짧은 루틴으로 바꿔 둘게요. 안 하는 것보다 훨씬 낫습니다", 5),
        ("client", "그 정도면 퇴근하고도 할 수 있을 것 같아요", 5),
        ("trainer", "혈압약 드시는 시간은 그대로시죠? 유산소가 그 시간과 겹치지 않게 잡을게요", 5),
        ("client", "네, 아침 8시 그대로예요", 5),
        ("trainer", "확인했어요. 화·목은 15분 저강도로 바꿔서 보냈습니다 🙂", 5),
        # 2일차.
        ("trainer", "민수님, 요즘 나트륨이 목표(2,000mg) 근처에서 자주 걸리네요. 국·찌개가 잦으신 편인가요?", 4),
        ("client", "회사 구내식당이라 국물이 늘 나와요 😅", 4),
        ("trainer", "국물만 절반 남기셔도 400~500mg은 빠져요. 그거 하나만 먼저 해보죠", 4),
        ("client", "오늘은 국물 안 마셨어요! 걷기도 25분 했습니다", 4),
        ("trainer", "좋아요 👏 그 한 가지만 지켜도 추이가 달라져요", 4),
        ("trainer", "내일 루틴은 걷기 20분으로 조금 늘려서 보냈어요. 주말까지 이 페이스로 가봐요", 4),
        # 3일차.
        ("trainer", "민수님, AI 식단 분석 잘 받았어요 👍 오늘 나트륨이 목표치를 좀 넘었는데 어떠셨어요?", 0),
        ("client", "찌개 먹을 때 국물을 많이 마셨나봐요 😅", 0),
        ("trainer", "그렇군요! 오늘 PT 후에 부상이나 불편한 데는 없으셨나요?", 0),
        ("client", "무릎이 가볍게 당기긴 했는데 괜찮아요", 0),
        ("trainer", "확인했어요. AI가 오늘 식단 기반으로 유산소 루틴을 추천했는데, 무릎 상태 감안해서 런닝 대신 걷기로 조정해서 보낼게요. 다음 PT 때 봐요 💪", 0),
    ],
    "user-jisu": [
        ("trainer", "지수님, AI 운동 데이터 수신했어요 — 오늘 인터벌 런닝 25분 완료! 컨디션은 어때요?", 0),
        ("client", "생각보다 괜찮았어요. 숨이 금방 차더라고요 😮‍💨", 0),
        ("trainer", "심폐 지구력 올라가는 과정이에요 💪 AI 분석 보니까 당류는 목표 안에 있고, "
                    "루틴 다음 주부터 근력 비중 늘려볼게요. 식단도 AI 추천 참고해서 업데이트해 드릴게요", 0),
    ],
    "user-sungho": [
        ("trainer", "성호님, 이번 주 운동 기록이 AI 쪽에서 안 잡히는데 몸은 괜찮으세요?", 0),
        ("client", "이번 주 일이 너무 많아서 못 갔어요 😓", 0),
        ("trainer", "이해해요! 대신 AI 식단 분석 보니까 나트륨이 좀 높더라고요. 주말에 30분 걷기라도 하면 "
                    "도움 돼요. AI가 그에 맞는 루틴 다시 짜줬으니까 앱에서 확인해보세요 🙂", 0),
    ],
}

# 회원별 AI 배정 루틴 (name, minutes, type, reason) — 프론트 aiRoutine 정렬.
_ROUTINES: dict[str, list[tuple[str, int, str, str]]] = {
    "user-demo": [
        ("저강도 유산소 (걷기)", 30, "유산소", "혈압 안정에 효과적"),
        ("하체 스트레칭", 15, "스트레칭", "혈액순환 개선"),
        ("코어 강화", 10, "근력", "기초대사량 향상"),
        ("어깨 관절 보호 스트레칭", 8, "스트레칭",
         "PT 피드백 반영 · 오른쪽 어깨 보호"),
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

# 사용자 앱 데모 회원(김민수)의 이번 주 운동 세션 — 프론트 MockExerciseRepository 와 동일.
# (요일, 종류, 분, 칼로리). 수요일은 휴식 → 목~일 4일 연속. 주간 칼로리 헤드라인은
# 백엔드가 세션 합(=2450)으로 계산한다(프론트 목업의 튜닝 헤드라인 1980 은 세션 합과
# 무관한 표시값이라 재현 대상이 아니다 — 실서비스는 합계가 정답).
_EXERCISE_WEEK: dict[str, list[tuple[str, str, int, int]]] = {
    "user-demo": [
        ("월", "cardio", 40, 300),
        ("화", "strength", 60, 420),
        ("목", "cardio", 65, 480),
        ("금", "cardio", 55, 400),
        ("토", "cardio", 45, 330),
        ("일", "strength", 50, 520),
    ],
}

# day_label → 요일 인덱스(월=0 … 일=6, date.weekday() 와 동일). 운동 시드는 이 인덱스로
# "오늘까지의 요일"만 넣어, 주중 실행 시 미래 요일이 이번 주 합계·streak 에 잡히는 것을 막는다.
_WEEKDAY_INDEX: dict[str, int] = {
    "월": 0, "화": 1, "수": 2, "목": 3, "금": 4, "토": 5, "일": 6,
}

# 사용자 앱 데모 회원(김민수)의 건강 프로필 — 프론트 MockMyHealthRepository/프로필 목업과
# 동일. 위험도·활동점수·기본정보 + 목표치는 구조화 컬럼(goal_*/daily_*)에 넣는다.
# conditions 는 위험도 서술에서 추론(목업엔 명시 없음). 키(height_cm)·성별은 목업에 없어 비운다.
_HEALTH_PROFILE: dict[str, dict] = {
    "user-demo": {
        "risk_title": "고혈압·당뇨 위험 주의",
        "risk_body": "최근 혈압과 혈당 추세가 다소 높습니다. 식단·운동 관리에 신경 써주세요.",
        "risk_level": "medium",
        "conditions": "고혈압, 당뇨 전단계",
        "phone": "010-1234-5678",
        "birth_date": "1990-01-15",
        "activity_points": 1240,
        "activity_rank": 14,
        # 일일 영양 목표(프론트 프로필 목업과 동일)
        "daily_calories": 2000,
        "daily_sodium_mg": 2000,
        "daily_sugar_g": 50,
        "daily_carbs_g": 275,
        "daily_protein_g": 100,
        "daily_fat_g": 55,
        # 주간 운동 목표
        "weekly_workout_goal": 7,
        "weekly_exercise_minutes_goal": 150,
        "weekly_burn_goal": 1500,
        "onboarded": True,
    },
}


# 트레이너 오늘 타임라인 (time, client, member_id, type, duration, status, note, program).
# member_id 는 유효 회원일 때만 연결(아니면 표시용 이름만). 프론트 TRAINER_SCHEDULE 정렬.
_SCHEDULE: list[tuple[str, str, str | None, str, int, str, str, list[dict]]] = [
    ("10:00", "김민수", "user-demo", "1:1 PT", 60, "완료", "무릎 컨디션 양호. 레그프레스 중량 소폭 증가 가능.", [
        {"name": "레그프레스", "sets": 3, "reps": "12회", "weight": "80kg"},
        {"name": "레그컬", "sets": 3, "reps": "12회", "weight": "40kg"},
        {"name": "카프레이즈", "sets": 3, "reps": "20회", "weight": "자체중량"},
        {"name": "하체 스트레칭", "sets": 1, "reps": "10분", "weight": "-"},
    ]),
    ("12:00", "이지수", "user-jisu", "1:1 PT", 50, "완료", "데드리프트 자세 안정적. 다음 세션 60kg 도전.", [
        {"name": "데드리프트", "sets": 4, "reps": "8회", "weight": "55kg"},
        {"name": "루마니안 데드리프트", "sets": 3, "reps": "10회", "weight": "40kg"},
        {"name": "플랭크", "sets": 3, "reps": "45초", "weight": "-"},
        {"name": "코어 서킷", "sets": 2, "reps": "12회", "weight": "-"},
    ]),
    ("14:00", "", None, "", 0, "공백", "", []),
    ("15:00", "박성호", "user-sungho", "1:1 PT", 60, "예정", "", [
        {"name": "벤치프레스", "sets": 4, "reps": "8회", "weight": "65kg"},
        {"name": "인클라인 덤벨 프레스", "sets": 3, "reps": "10회", "weight": "26kg"},
        {"name": "트라이셉스 딥", "sets": 3, "reps": "12회", "weight": "-"},
    ]),
    ("17:00", "신규 회원", None, "상담", 30, "예정", "", []),
    ("19:00", "", None, "", 0, "공백", "", []),
]


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
            _seed_exercise(db, user_id)
            _seed_health_profile(db, user_id)
        _seed_schedule(db, valid)
    finally:
        db.close()


def ingest_seeded_documents() -> None:
    """시드가 **전부** 끝난 뒤 호출한다 — `init_db` 의 마지막 시드 단계.

    이 함수 안에서 부르면 안 된다. 확장 회원(4~15)의 기록은 `seed_roster_metrics`
    가 이 뒤에 만들기 때문에, 여기서 훑으면 첫 기동에 그들 문서가 통째로 빠진다
    (재기동해야 채워졌다 — 실제로 그렇게 나왔다).
    """
    db: Session = SessionLocal()
    try:
        _ingest_seeded_documents(db, _valid_member_ids(db))
    finally:
        db.close()


def _ingest_seeded_documents(db: Session, valid: set[str]) -> None:
    """시드 기록을 개인 RAG 문서로 적재한다(멱등) — #604.

    적재는 원래 실시간 API 경로에서만 일어난다. 시드는 테이블에 직접 insert 하므로
    데모 계정에는 개인 문서가 하나도 없었고, 그래서 비대칭이 생겼다:
      * 트레이너 루틴 생성 — `chat_messages` 를 직접 조회해 시드 대화를 본다
      * 회원 앱 AI 코치 — RAG 만 보므로 시드 식단·운동·대화를 못 본다
    데모에서 "이번 주 운동 어땠어?" 라고 물으면 기록이 있는데도 일반론이 나왔다.

    멱등은 `source_ref`(#603)로 판정한다 — 이미 적재된 기록은 임베딩을 다시 부르지
    않는다. 그래서 비용이 드는 것은 사실상 최초 기동 한 번뿐이다.
    """
    settings = get_settings()
    if not settings.seed_rag_ingest or not settings.rag_auto_ingest:
        return

    started = time.monotonic()
    ingested = 0
    for member_id in sorted(valid):
        ingested += _ingest_member_documents(db, member_id)

    if ingested:
        logger.info(
            "시드 개인 RAG 적재: %d건 (%.1fs). 이미 적재된 기록은 건너뜀.",
            ingested, time.monotonic() - started,
        )


#: 시드가 만든 행의 id 접두사. 이 접두사로만 좁히는 이유가 있다 — 사용자가 앱에서
#: 남긴 기록은 실시간 경로가 이미 적재했고, 그중 #603 이전에 적재된 문서는
#: `source_ref` 가 NULL 이라 멱등 판정에 걸리지 않는다. 전체를 훑으면 그런 기록이
#: 두 벌씩 검색된다.
_SEED_ID_PREFIX = "seed-"


def _ingest_member_documents(db: Session, member_id: str) -> int:
    """한 회원의 시드 식단·운동·대화를 적재하고 적재한 건수를 돌려준다."""
    count = 0

    for entry in db.scalars(
        select(models.DietEntry).where(
            models.DietEntry.user_id == member_id,
            models.DietEntry.id.like(f"{_SEED_ID_PREFIX}%"),
        )
    ).all():
        count += _ingested(
            personal_ingest.record_diet,
            db, member_id, date=entry.date, foods=_entry_foods(entry),
            total_calories=entry.total_calories, sodium_mg=entry.sodium_mg,
            sugar_g=entry.sugar_g, source_ref=entry.id,
        )

    for session in db.scalars(
        select(models.ExerciseSession).where(
            models.ExerciseSession.user_id == member_id,
            models.ExerciseSession.id.like(f"{_SEED_ID_PREFIX}%"),
        )
    ).all():
        count += _ingested(
            personal_ingest.record_exercise,
            db, member_id, date=_session_date(session),
            exercise_type=session.type, minutes=session.minutes,
            calories=session.calories, intensity=session.intensity,
            source_ref=session.id,
        )

    for msg in db.scalars(
        select(models.ChatMessage).where(
            models.ChatMessage.member_id == member_id,
            models.ChatMessage.id.like(f"{_SEED_ID_PREFIX}%"),
        )
    ).all():
        count += _ingested(
            personal_ingest.record_chat,
            db, member_id, sender=msg.sender, text=msg.body,
            date=clock.to_seoul(msg.created_at).date().isoformat(),
            source_ref=msg.id,
        )

    return count


def _ingested(record, db: Session, member_id: str, **fields) -> int:
    """`once` 경로로 적재하고 실제로 새로 넣었으면 1을 돌려준다.

    적재 여부를 여기서 미리 확인하지 않는다 — 확인과 삽입이 갈라지면 두 인스턴스가
    동시에 기동할 때 같은 기록의 청크가 두 벌 들어간다. `ensure_personal_text` 가
    잠금 안에서 확인까지 하므로, 우리는 문서 수 변화로 새로 넣었는지만 센다.
    """
    before = has_personal_doc(db, member_id, fields["source_ref"])
    record(db, member_id, once=True, **fields)
    return 0 if before else int(has_personal_doc(db, member_id, fields["source_ref"]))


def _entry_foods(entry: models.DietEntry) -> list[dict]:
    """저장된 foods_json → 리스트. 깨진 값이면 빈 목록(시드가 기동을 막으면 안 된다)."""
    try:
        value = json.loads(entry.foods_json or "[]")
    except (TypeError, ValueError):
        return []
    return value if isinstance(value, list) else []


def _session_date(session: models.ExerciseSession) -> str:
    """세션의 실제 날짜. 저장은 (주 시작 + 요일 라벨)로 쪼개져 있다."""
    try:
        monday = date.fromisoformat(session.week_start)
        return (
            monday + timedelta(days=_WEEKDAY_INDEX[session.day_label])
        ).isoformat()
    except (ValueError, KeyError):
        return session.week_start


def _seed_schedule(db: Session, valid: set[str]) -> None:
    """트레이너 오늘 타임라인 시드(멱등, 날짜 인식). 트레이너 계정이 없으면 스킵."""
    if db.scalar(
        select(models.User.id).where(
            models.User.id == TRAINER_ID, models.User.role == "trainer"
        )
    ) is None:
        return
    today = clock.today_iso()
    # 오늘 스케줄이 이미 있으면 스킵(날짜 넘어가면 새로 시드)
    if db.scalar(
        select(models.TrainerSchedule.id)
        .where(
            models.TrainerSchedule.trainer_id == TRAINER_ID,
            models.TrainerSchedule.date == today,
        )
        .limit(1)
    ) is not None:
        return
    for i, (time, cname, mid, typ, dur, status, note, program) in enumerate(_SCHEDULE):
        member_id = mid if (mid and mid in valid) else None
        db.add(models.TrainerSchedule(
            id=f"seed-schedule-{today}-{i}",
            trainer_id=TRAINER_ID,
            member_id=member_id,
            date=today,
            time=time,
            client_name=cname,
            type=typ,
            duration_minutes=dur,
            status=status,
            note=note,
            program_json=json.dumps(program, ensure_ascii=False),
            sort_order=i,
        ))
    _safe_commit(db)


def _seed_chat(db: Session, member_id: str) -> None:
    """트레이너↔회원 채팅 스레드(멱등, 결정론적 id). 최근 시각으로 정렬되게 시드.

    **이미 있는 시드 행은 건너뛰지 않고 현재 대화로 덮어쓴다.** 건너뛰면, 전에
    시드된 DB(공유 Neon 포함)가 옛 본문을 그대로 들고 새로 늘어난 메시지만
    덧붙여 앞뒤가 다른 스레드가 된다 — 실제로 이 스레드는 다섯 개에서 열여덟
    개로 바뀌면서 앞 다섯 개의 본문도 전부 달라졌다(리뷰 지적). 대화가 줄어든
    경우를 위해 남는 시드 행도 지운다.

    회원이 앱에서 직접 보낸 메시지는 `chat-` 로 시작하는 다른 id 라 건드리지
    않는다 — 지우는 대상은 `seed-chat-{member_id}-` 접두사뿐이다.
    """
    thread = _CHAT.get(member_id)
    if not thread:
        return
    # 스레드가 최근으로 보이도록 base 를 하루 안쪽 과거로 두고, 메시지마다 그
    # 메시지의 days_ago 만큼 더 과거로 민다. 같은 날 안에서는 2분 간격이다.
    # days_ago 가 뒤로 갈수록 작아지므로 시각은 계속 증가한다 — 스레드 정렬은
    # (created_at, id) 이라 이 단조성이 대화 순서를 보장한다.
    #
    # **시각을 정오로 고정한다.** 예전에는 `now - 2시간` 을 그대로 썼는데, 시드가
    # 자정 근처(UTC 01:30~02:00)에 돌면 base 가 23:5x 가 되어 `+ i*2분` 이 자정을
    # 넘었다. 그러면 같은 days_ago 묶음이 이틀로 쪼개져 **사흘치 대화가 나흘**이 되고,
    # 날짜로 묶는 화면(하루치 AI 분석 안내)도 함께 어긋난다. CI 가 그 시간대에 걸리면
    # `test_demo_thread_spans_three_days` 가 아무 변경 없이 실패했다.
    #
    # 묶음 안의 최대 간격이 34분이라 정오 기준이면 어떤 시각에 시드해도 자정을 넘지
    # 않는다. 오늘 정오가 아직 오지 않았으면 하루 뒤로 물러 미래 시각을 만들지 않는다.
    now = datetime.now(timezone.utc)
    span = timedelta(minutes=(len(thread) - 1) * 2)
    base = now.replace(hour=12, minute=0, second=0, microsecond=0)
    if base + span > now:
        base -= timedelta(days=1)
    keep: set[str] = set()
    for i, (sender, text, days_ago) in enumerate(thread):
        cid = f"seed-chat-{member_id}-{i}"
        keep.add(cid)
        created_at = base - timedelta(days=days_ago) + timedelta(minutes=i * 2)
        sender_out = "member" if sender == "client" else "trainer"
        row = db.get(models.ChatMessage, cid)
        if row is None:
            db.add(models.ChatMessage(
                id=cid,
                trainer_id=TRAINER_ID,
                member_id=member_id,
                sender=sender_out,
                body=text,
                created_at=created_at,
            ))
            continue
        row.sender = sender_out
        row.body = text
        row.created_at = created_at

    stale = db.scalars(
        select(models.ChatMessage).where(
            models.ChatMessage.member_id == member_id,
            models.ChatMessage.id.like(f"seed-chat-{member_id}-%"),
        )
    ).all()
    for row in stale:
        if row.id not in keep:
            db.delete(row)
    _safe_commit(db)


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
    _safe_commit(db)


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

    today = clock.today()
    today_str = today.isoformat()

    # 오늘 3끼 (오늘 기록이 아직 없을 때만)
    if not _has_diet_on(db, member_id, today_str):
        for i, meal in enumerate(meals):
            meal_type, items, cal, na, sugar, carbs, protein, fat = meal
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
                carbs_g=carbs,
                protein_g=protein,
                fat_g=fat,
                sodium_mg=na,
                sugar_g=sugar,
                engine="seed",
            ))

    # 과거 일별 기록 (해당 날짜에 기록이 없을 때만 — 중복 합산 방지).
    # 리포트가 과거 주로 이동할 수 있어 이번 주만 채우면 한 주만 뒤로 가도
    # 화면이 빈다(#752).
    # 이미 기록이 있는 날짜를 한 번에 읽는다 — 날마다 조회하면 12주치 시딩이
    # 눈에 띄게 느려진다.
    logged = set(
        db.scalars(
            select(models.DietEntry.date).where(
                models.DietEntry.user_id == member_id
            )
        ).all()
    )
    for offset in range(1, _HISTORY_WEEKS * 7):
        d = (today - timedelta(days=offset)).isoformat()
        if d in logged:
            continue
        logged.add(d)
        factor = _WEEK_FACTORS[(offset // 7) % len(_WEEK_FACTORS)]
        na = round(sodium_week[6 - (offset % 7)] * factor)
        calories = round(1500 * factor)
        db.add(models.DietEntry(
            id=f"seed-diet-{member_id}-{d}-agg",
            user_id=member_id,
            date=d,
            meal_type="lunch",
            time_label="",
            foods_json=json.dumps(
                [{"name": "기록된 식단", "calories": calories, "sodium_mg": na, "sugar_g": 0}],
                ensure_ascii=False,
            ),
            total_calories=calories,
            sodium_mg=na,
            sugar_g=round(na / 60.0, 1),
            engine="seed",
        ))
    _safe_commit(db)


def _seed_history(db: Session, member_id: str) -> None:
    sessions = _HISTORY.get(member_id)
    if not sessions:
        return

    today = clock.today()
    # 오늘/이틀전/나흘전을 한 주기로 두고 과거 주까지 되풀이한다. 리포트가
    # 과거 주로 이동할 수 있어, 이번 주만 채우면 이행률이 곧 비어 버린다(#752).
    #
    # 멱등성은 행 id(회원+날짜)로 지킨다. 예전처럼 "오늘 기록이 있으면 통째로
    # 건너뛰기" 로 두면, 오늘치가 이미 있는 DB 에는 과거 주가 영영 채워지지
    # 않는다.
    existing = set(
        db.scalars(
            select(models.RoutineHistory.id).where(
                models.RoutineHistory.member_id == member_id
            )
        ).all()
    )
    for week in range(_HISTORY_WEEKS):
        factor = _WEEK_FACTORS[week % len(_WEEK_FACTORS)]
        for idx, (rate, kind, exercises, feedback, note) in enumerate(sessions):
            d = (today - timedelta(days=idx * 2 + week * 7)).isoformat()
            hid = f"seed-hist-{member_id}-{d}"
            if hid in existing:
                continue
            existing.add(hid)
            db.add(models.RoutineHistory(
                id=hid,
                member_id=member_id,
                trainer_id=TRAINER_ID if kind.startswith("PT") else None,
                date=d,
                kind_label=kind,
                completion_rate=min(100, round(rate * factor)),
                exercises_json=json.dumps(exercises, ensure_ascii=False),
                # 과거 주까지 같은 문구를 반복하면 화면이 복사본처럼 읽힌다 —
                # 이번 주 것만 실제 대화를 남긴다.
                client_feedback=feedback if week == 0 else "",
                trainer_note=note if week == 0 else "",
            ))
    _safe_commit(db)


def _seed_exercise(db: Session, member_id: str) -> None:
    """회원 이번 주 운동 세션 시드(멱등, 날짜 인식) — 사용자 앱 운동 화면용.

    이번 주 세션 중 **오늘까지의 요일만** 넣는다. 주중에 실행돼도 미래 요일이 이번 주
    합계·streak 에 잡히지 않도록(예: 수요일에 시드해도 목~일은 넣지 않음). 멱등은
    세션 id 단위로 판정하므로, 주가 진행되며 재실행되면 새로 지난 요일이 채워지고
    이미 있는 요일은 건너뛴다(중복·왜곡 없음). 주가 바뀌면 새 week_start 로 누적된다."""
    week = _EXERCISE_WEEK.get(member_id)
    if not week:
        return
    today = clock.today()
    week_start = (today - timedelta(days=today.weekday())).isoformat()  # 이번 주 월요일
    added = False
    for day_label, ex_type, minutes, calories in week:
        idx = _WEEKDAY_INDEX.get(day_label)
        if idx is None or idx > today.weekday():
            continue  # 미래(또는 알 수 없는) 요일은 아직 시드하지 않는다.
        session_id = f"seed-ex-{member_id}-{week_start}-{day_label}"
        if db.scalar(
            select(models.ExerciseSession.id)
            .where(models.ExerciseSession.id == session_id)
            .limit(1)
        ) is not None:
            continue  # 멱등: 이미 있는 요일은 스킵.
        db.add(models.ExerciseSession(
            id=session_id,
            user_id=member_id,
            week_start=week_start,
            day_label=day_label,
            type=ex_type,
            minutes=minutes,
            calories=calories,
            intensity="moderate",
        ))
        added = True
    if added:
        _safe_commit(db)


def _seed_health_profile(db: Session, member_id: str) -> None:
    """회원 건강 프로필(위험도·활동점수·기본정보) 시드(멱등). 이미 있으면 스킵.
    사용자 앱 홈/My Health 의 위험 카드·활동점수가 실데이터로 뜨게 한다."""
    fields = _HEALTH_PROFILE.get(member_id)
    if not fields:
        return
    if db.scalar(
        select(models.HealthProfile.id)
        .where(models.HealthProfile.user_id == member_id)
        .limit(1)
    ) is not None:
        return
    db.add(models.HealthProfile(user_id=member_id, **fields))
    _safe_commit(db)
