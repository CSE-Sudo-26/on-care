#!/usr/bin/env python3
"""김민수 데모 픽스처(`shared/demo_fixture/assets/kim_minsu.json`)를 만든다.

픽스처는 **결과물이 원본**이다 — 사용자앱·트레이너웹·백엔드는 이 JSON 을 읽기만
하고 아무것도 계산하지 않는다. 이 스크립트는 그 JSON 을 처음 짜 넣기 위한
도구이고, 이후 값을 손보고 싶으면 JSON 을 직접 고쳐도 된다. 다시 돌리면 손댄
내용이 날아가므로, 규칙 자체를 바꿀 때만 쓴다.

    python3 tool/gen_demo_fixture.py

날짜는 절대 날짜로 적지 않는다. 달력 주 격자(`weeks`: 몇 주 전 × 요일)가 12주를
채우고, 최근 사흘(`recent`: 오늘·어제·그제)만 큐레이션이 그 위를 덮는다. 주 격자를
쓰는 이유는 리포트·추이 그래프가 달력 주로 묶기 때문이다 — 오늘로부터의 일수만으로
적으면 "회식이 몰린 주" 같은 이야기가 두 주에 걸쳐 잘린다.
"""

from __future__ import annotations

import json
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[1]

#: 픽스처 원본. 사람이 읽고 고치는 파일이다.
OUT = _ROOT / "shared/demo_fixture/assets/kim_minsu.json"

#: 백엔드가 읽는 같은 파일. 내용은 [OUT] 과 **바이트까지 같아야 한다**
#: (`backend/tests/test_demo_fixture.py` 가 검사한다).
#:
#: 왜 복사본이 있나: 백엔드 이미지는 `docker build .` 을 `backend/` 에서 돌려서
#: 빌드 컨텍스트 밖(`shared/`)의 파일을 담을 수 없다. 컨텍스트를 레포 루트로 올리는
#: 건 배포 워크플로를 건드리는 일이라 여기서 하지 않는다. 대신 이 스크립트가 두
#: 곳에 함께 써서 손으로 맞출 일을 없앤다.
OUT_BACKEND = _ROOT / "backend/app/db/demo_fixture_data.json"

#: 두 Flutter 앱이 읽는 같은 내용. 에셋이 아니라 **Dart 상수**로 심는다.
#:
#: 에셋으로 두면 읽는 데 `rootBundle` 이 필요하고 그건 비동기다. 위젯 테스트는 가짜
#: 비동기 안에서 도는데, 거기서 에셋을 기다리면 펌프될 때까지 풀리지 않아 테스트가
#: 통째로 멈춘다 — 26초에 끝나던 파일이 10분을 넘겨도 끝나지 않았다. 상수로 두면
#: 읽기가 동기라 그 함정이 없고, 새 테스트를 쓰는 사람이 밟을 일도 없다.
OUT_DART = _ROOT / "shared/demo_fixture/lib/src/fixture_json.g.dart"

HISTORY_WEEKS = 12

# ── 음식 ───────────────────────────────────────────────────────────────────
# (이름, 칼로리, 나트륨mg, 당류g, 탄수g, 단백g, 지방g)
FOODS: dict[str, tuple[str, int, int, float, float, float, float]] = {
    "oatmeal": ("오트밀", 250, 100, 6, 42, 10, 6),
    "banana": ("바나나", 105, 1, 14, 27, 1.3, 0.4),
    "greek-yogurt": ("그릭 요거트", 170, 75, 7, 8, 18, 8),
    "nuts": ("견과류", 150, 5, 2, 6, 5, 13),
    "scrambled-egg": ("스크램블 에그", 185, 220, 0.8, 2, 13, 14),
    "strawberry": ("딸기", 32, 1, 5.5, 8, 0.5, 0.5),
    "chicken-salad": ("닭가슴살 샐러드", 315, 395, 10, 19, 34, 11.1),
    "bibimbap": ("야채비빔밥", 610, 900, 12, 92, 20, 16),
    "jjamppong": ("짬뽕", 750, 3200, 8.5, 107, 29, 22.5),
    "doenjang-jjigae": ("된장찌개", 300, 1300, 5, 18, 24, 15),
    "rice": ("밥", 310, 5, 0.7, 67, 6, 2.5),
    "grilled-salmon": ("연어구이", 395, 505, 9, 19, 35, 19),
    "brown-rice": ("현미밥", 280, 5, 0, 58, 6, 2),
    "sweet-potato": ("고구마", 130, 20, 6.5, 30, 2, 0.2),
    "iced-americano": ("아이스 아메리카노", 10, 5, 0, 2, 0.5, 0),
    "nut-pack": ("견과류 한 봉", 90, 2, 3, 1, 2, 8),
    "samgyeopsal": ("삼겹살 2인분", 620, 880, 1, 2, 42, 50),
    "soju": ("소주 1병", 55, 0, 0, 0, 0, 0),
    "choco-cake": ("초코 케이크 한 조각", 330, 280, 24, 42, 5, 15),
    "cafe-latte": ("카페라떼", 100, 95, 5.3, 10, 5, 4),
}

# ── 끼니 ───────────────────────────────────────────────────────────────────
# (끼니종류, 시각, 사진, AI 코멘트, 음식들)
#
# 사진 에셋이 없는 끼니는 가장 가까운 한식 상차림을 재사용한다. 삼겹살·디저트가
# 그렇다 — 에셋이 생기면 여기만 고치면 세 곳이 함께 따라온다.
MEALS: dict[str, tuple[str, str, str, str, list[str]]] = {
    "breakfast-oatmeal-banana": (
        "breakfast", "08:05", "assets/images/diet-oatmeal-banana.jpeg",
        "오트밀로 식이섬유를 챙긴 아침이에요.",
        ["oatmeal", "banana"],
    ),
    "breakfast-greek-yogurt-nuts": (
        "breakfast", "08:30", "assets/images/diet-greek-yogurt-nuts.jpeg",
        "단백질과 불포화지방을 고르게 섭취했어요.",
        ["greek-yogurt", "nuts"],
    ),
    "breakfast-egg-strawberry": (
        "breakfast", "07:50", "assets/images/breakfast-scrambled-egg-strawberry.jpg",
        "달걀 단백질에 과일로 비타민을 더했어요.",
        ["scrambled-egg", "strawberry"],
    ),
    "lunch-chicken-salad": (
        "lunch", "12:30", "assets/images/diet-chicken-salad.jpg",
        "닭가슴살과 채소로 단백질·식이섬유를 챙겼어요.",
        ["chicken-salad"],
    ),
    "lunch-bibimbap": (
        "lunch", "12:20", "assets/images/diet-vegetable-bibimbap.jpg",
        "야채가 풍부해요. 고추장을 줄이면 나트륨이 더 좋아져요.",
        ["bibimbap"],
    ),
    "lunch-jjamppong": (
        "lunch", "12:50", "assets/images/lunch-jjamppong.jpg",
        "국물 나트륨이 높은 날이에요. 국물은 남기는 편이 좋아요.",
        ["jjamppong"],
    ),
    "lunch-doenjang-rice": (
        "lunch", "12:10", "assets/images/diet-doenjang-rice.jpeg",
        "집밥 한 상이에요. 찌개 국물만 조금 남겨 보세요.",
        ["doenjang-jjigae", "rice"],
    ),
    "dinner-salmon-brown-rice": (
        "dinner", "18:40", "assets/images/diet-salmon-brown-rice.jpeg",
        "연어의 지방과 현미밥의 복합 탄수화물 조합이 좋아요.",
        ["grilled-salmon", "brown-rice"],
    ),
    "dinner-doenjang-rice": (
        "dinner", "19:10", "assets/images/diet-doenjang-rice.jpeg",
        "포만감은 좋지만 국물 나트륨이 높은 편이에요.",
        ["doenjang-jjigae", "rice"],
    ),
    "dinner-chicken-salad-sweet-potato": (
        "dinner", "18:20", "assets/images/diet-chicken-salad.jpg",
        "가볍게 마무리한 저녁이에요.",
        ["chicken-salad", "sweet-potato"],
    ),
    "dinner-samgyeopsal": (
        "dinner", "19:30", "assets/images/diet-doenjang-rice.jpeg",
        "고기와 술이 함께여서 칼로리가 크게 올라갔어요. 다음 날은 가볍게 시작해 보세요.",
        ["samgyeopsal", "rice", "soju"],
    ),
    "snack-coffee-nuts": (
        "snack", "15:40", "assets/images/snack-coffee-nuts.jpg",
        "당류가 낮고 건강한 지방을 채운 간식이에요.",
        ["iced-americano", "nut-pack"],
    ),
    "snack-cake-latte": (
        "snack", "21:10", "assets/images/snack-coffee-nuts.jpg",
        "디저트로 당류가 하루 목표를 넘었어요.",
        ["choco-cake", "cafe-latte"],
    ),
}

# ── 요일별 루틴 ────────────────────────────────────────────────────────────
# 이행률은 여기 항목의 `done` 개수에서 나온다 — 퍼센트를 따로 적으면 화면의
# "3개 중 2개 완료" 와 숫자가 갈라진다(#754).
#
# (이름, 종류, 분, 칼로리). 수요일은 휴식이라 항목이 없다 — 사용자앱의 주간
# 활동 그래프와 백엔드 시드가 이미 쓰던 리듬이다.
ROUTINE: dict[int, list[tuple[str, str, int]]] = {
    0: [("저강도 유산소 (걷기) 30분", "cardio", 30),
        ("코어 강화 10분", "strength", 10),
        ("하체 스트레칭 5분", "flexibility", 5)],
    1: [("저강도 유산소 (걷기) 40분", "cardio", 40),
        ("하체 스트레칭 10분", "flexibility", 10)],
    2: [],
    3: [("저강도 유산소 (걷기) 35분", "cardio", 35),
        ("코어 강화 20분", "strength", 20),
        ("하체 스트레칭 5분", "flexibility", 5)],
    4: [("저강도 유산소 (걷기) 45분", "cardio", 45),
        ("어깨 관절 보호 스트레칭 10분", "flexibility", 10)],
    5: [("저강도 유산소 (걷기) 25분", "cardio", 25),
        ("코어 강화 30분", "strength", 30),
        ("하체 스트레칭 15분", "flexibility", 15)],
    6: [("저강도 유산소 (걷기) 20분", "cardio", 20),
        ("하체 스트레칭 10분", "flexibility", 10)],
}

#: 분당 칼로리. 종류마다 다르다 — 걷기와 스트레칭을 같은 값으로 두면 주간 활동
#: 그래프의 스택이 실제 운동 강도와 어긋난다.
#:
#: 값은 앱·백엔드의 추정표와 **같아야 한다**(`_estimateCalories`,
#: `exercise_service._KCAL_PER_MIN`). 예전에는 여기만 7.5·5 로 낮아, 데모의 30분
#: 유산소는 225kcal 인데 같은 운동을 회원이 직접 기록하면 270kcal 이 나왔다.
#: 같은 사람의 같은 운동이 기록 경로에 따라 다른 숫자가 되는 셈이다. (#997)
KCAL_PER_MIN = {"cardio": 9, "strength": 6, "flexibility": 3}

# ── 주별 이야기 ────────────────────────────────────────────────────────────
# 12주를 7가지 주로 돌려 채운다. 예전에는 주마다 계수 하나를 곱해 흔들었는데,
# 그러면 12주 내내 나트륨은 늘 초과하고 칼로리는 늘 목표 안이었다. 사람은 그렇게
# 살지 않는다 — 회식이 몰린 주는 칼로리도 당류도 같이 넘고, 코칭이 먹힌 주는
# 나트륨이 목표 안으로 들어온다. 그래서 계수가 아니라 **그 주에 뭘 먹었는지** 로
# 적는다.
#
# 값은 요일(월→일)마다 (아침, 점심, 저녁, 간식). None 은 그 끼니를 기록하지 않은
# 것이고, 요일 전체가 None 이면 하루를 통째로 비운다 — "기록이 없는 날" 도 데모에
# 남아 있어야 그 빈 화면이 맞게 동작하는지 볼 수 있다.
B_OAT, B_YOG, B_EGG = (
    "breakfast-oatmeal-banana",
    "breakfast-greek-yogurt-nuts",
    "breakfast-egg-strawberry",
)
# 짬뽕(3,200mg)은 **오늘 하루**에만 쓴다. 한 끼로 하루 나트륨을 다 쓰는 끼니라,
# 격자에 섞으면 그날의 나트륨÷칼로리가 2 를 넘어 `seed_clients.dart` 가 지키라고
# 적어 둔 1.0~1.5 를 깬다. 오늘의 예외라는 점이 코칭 알림의 근거이기도 하다.
L_SAL, L_BIB, L_JJA, L_DOE = (
    "lunch-chicken-salad", "lunch-bibimbap", "lunch-jjamppong", "lunch-doenjang-rice",
)
D_SLM, D_DOE, D_SAL, D_SAM = (
    "dinner-salmon-brown-rice", "dinner-doenjang-rice",
    "dinner-chicken-salad-sweet-potato", "dinner-samgyeopsal",
)
S_NUT, S_CAK = "snack-coffee-nuts", "snack-cake-latte"

WEEK_STORIES: list[tuple[str, list[list[str | None] | None], dict[int, int]]] = [
    # (한 줄 설명, 요일별 끼니, 요일별로 못 한 루틴 항목 수)
    (
        "평소의 한 주 — 국물이 잦지만 기록은 성실하다.",
        [
            [B_YOG, L_SAL, D_SLM, None],
            [B_OAT, L_DOE, D_SAL, S_NUT],
            [B_EGG, L_BIB, D_DOE, None],
            [B_YOG, L_SAL, D_SLM, S_NUT],
            [B_OAT, L_BIB, D_DOE, None],
            [B_EGG, L_DOE, D_SAL, S_NUT],
            [B_YOG, L_DOE, D_SLM, None],
        ],
        # 화·목이 낮다. 트레이너 스레드에서 김민수가 "화요일이랑 목요일이 야근이
        # 많아요" 라고 답하는데, 이행률이 그 요일에 떨어져 있지 않으면 대화가 화면의
        # 숫자와 어긋난다(`seed_clients.dart` 의 chat).
        {1: 1, 3: 1},
    ),
    (
        "가볍게 간 한 주 — 세 지표가 모두 목표 안에 든다.",
        [
            [B_YOG, L_SAL, D_SLM, None],
            [B_YOG, L_SAL, D_SAL, S_NUT],
            [B_OAT, L_BIB, D_SLM, None],
            [B_EGG, L_SAL, D_SAL, S_NUT],
            [B_YOG, L_BIB, D_SLM, None],
            [B_OAT, L_SAL, D_SAL, None],
            [B_EGG, L_SAL, D_SLM, S_NUT],
        ],
        {},
    ),
    (
        "회식이 몰린 주 — 칼로리와 당류가 함께 목표를 넘는다.",
        [
            [B_OAT, L_DOE, D_SAM, S_CAK],
            [B_EGG, L_DOE, D_SAL, S_CAK],
            [B_YOG, L_BIB, D_SAM, None],
            [B_OAT, L_BIB, D_DOE, S_CAK],
            [B_EGG, L_DOE, D_SAM, S_CAK],
            [B_OAT, L_BIB, D_SAL, S_CAK],
            [B_YOG, L_SAL, D_SLM, None],
        ],
        {1: 2, 3: 2, 4: 1, 5: 2},
    ),
    (
        "코칭이 먹힌 주 — 국물을 줄여 나트륨이 목표 안으로 들어온다.",
        [
            [B_YOG, L_SAL, D_SLM, None],
            [B_OAT, L_SAL, D_SAL, S_NUT],
            [B_EGG, L_SAL, D_SLM, None],
            [B_YOG, L_BIB, D_SAL, S_NUT],
            [B_OAT, L_SAL, D_SLM, None],
            [B_EGG, L_SAL, D_SAL, S_NUT],
            [B_YOG, L_SAL, D_SLM, None],
        ],
        {5: 1},
    ),
    (
        "평범한 한 주 — 구내식당 국물이 나트륨을 밀어 올린다.",
        [
            [B_OAT, L_DOE, D_SLM, None],
            [B_EGG, L_BIB, D_DOE, S_NUT],
            [B_YOG, L_DOE, D_SAL, None],
            [B_OAT, L_DOE, D_SLM, S_NUT],
            [B_EGG, L_BIB, D_DOE, None],
            [B_YOG, L_DOE, D_SAL, S_NUT],
            [B_OAT, L_SAL, D_SLM, None],
        ],
        {1: 1, 6: 1},
    ),
    (
        "야근이 많던 주 — 늦은 저녁은 기록이 비어 있다.",
        [
            [B_YOG, L_DOE, D_SLM, None],
            [B_OAT, L_DOE, None, S_NUT],
            [B_EGG, L_BIB, D_DOE, None],
            [B_YOG, L_DOE, None, S_NUT],
            [B_OAT, L_SAL, D_SLM, None],
            [B_EGG, L_BIB, D_SAL, None],
            [B_YOG, L_SAL, D_SLM, S_NUT],
        ],
        {1: 2, 3: 1, 4: 1},
    ),
    (
        "기록을 막 시작한 주 — 아예 빠진 날이 있다.",
        [
            [B_OAT, L_BIB, D_DOE, None],
            None,
            [B_EGG, L_DOE, D_SLM, None],
            [B_YOG, L_DOE, None, None],
            None,
            [B_OAT, L_BIB, D_SAL, S_NUT],
            [B_EGG, L_SAL, D_SLM, None],
        ],
        {0: 1, 1: 1, 3: 2, 4: 1, 5: 2, 6: 1},
    ),
]

# ── 큐레이션 사흘 ──────────────────────────────────────────────────────────
# 시연에 쓰는 오늘·어제·그제. 주 격자 위를 덮는다.
#
# 어제는 약속이 있던 날 — 하루 합이 2,380kcal · 2,261mg · 63.0g 으로 칼로리와
# 당류가 목표(2,000kcal · 50g)를 넘는다. 목표선과 초과 색이 실제로 동작하는지
# 시연에서 눈으로 확인하려면 넘긴 날이 하나는 있어야 하고, **어제**여야 데모를
# 여는 날이 언제든 항상 화면에 들어온다. 오늘은 점심 짬뽕 한 그릇이 나트륨을 다
# 쓴 하루다(3,428mg) — 오늘 코칭 알림의 근거가 그 조합이다.
#
# `id` 를 못 박은 끼니는 시연 중 화면에서 지목하는 행이라 값이 고정이어야 한다.
RECENT: list[dict] = [
    {
        "offset": 0,
        "label": "PT 세션 · 트레이너 지도",
        "pt": True,
        "clientFeedback": "무릎이 좀 당겼지만 트레이너님 덕분에 잘 마쳤어요 😊",
        "trainerNote": "무릎 가동범위 체크 필요. 다음 세션 중량 조절 예정.",
        "dayMessage": "점심 짬뽕으로 오늘 나트륨 섭취가 많았어요. 저녁은 양념을 줄인 채소와 단백질 위주로 구성해 보세요.",
        "exercises": [
            ("레그프레스 3세트", "strength", 25, True),
            ("레그컬 3세트", "strength", 20, True),
            ("하체 스트레칭 15분", "flexibility", 15, True),
        ],
        "meals": [
            (B_EGG, "seed-diet-breakfast", "08:20",
             "단백질과 식이섬유의 깔끔한 조합으로, 소금 간과 기름만 조절하면 혈당과 혈압 모두 잡는 우수한 식단입니다."),
            (L_JJA, "seed-diet-lunch", "12:40",
             "정제 면과 높은 나트륨으로 혈압·혈당 부담이 매우 크니, 국물은 남기고 야채 위주로 드시는 것이 좋습니다."),
            (S_NUT, "seed-diet-snack", "15:30",
             "당류와 칼로리가 낮고 견과류의 건강한 지방이 채워져 완벽한 간식입니다."),
        ],
    },
    {
        "offset": 1,
        "label": "AI 루틴 · 자율 운동",
        "pt": False,
        "clientFeedback": "스트레칭은 시간이 없어서 못 했어요",
        "trainerNote": "",
        "dayMessage": "약속이 있어 칼로리와 당류가 목표를 넘은 하루예요. 오늘은 가볍게 시작해 보세요.",
        "exercises": [
            ("저강도 유산소 (걷기) 30분", "cardio", 30, True),
            ("코어 강화 10분", "strength", 10, True),
            ("하체 스트레칭 15분", "flexibility", 15, False),
        ],
        "meals": [
            (B_OAT, "seed-diet-yesterday-breakfast", "08:10",
             "오트밀로 식이섬유를 챙겼어요. 바나나가 들어가 당류는 다소 높은 편이에요."),
            (L_BIB, "seed-diet-yesterday-lunch", "12:30",
             "야채가 풍부한 비빔밥이에요. 고추장을 줄이면 나트륨을 더 조절할 수 있어요."),
            (D_SAM, "seed-diet-yesterday-dinner", None, None),
            (S_CAK, "seed-diet-yesterday-snack", None, None),
        ],
    },
    {
        "offset": 2,
        "label": "AI 루틴 · 자율 운동",
        "pt": False,
        "clientFeedback": "오늘은 다 했어요! 뿌듯해요 💪",
        "trainerNote": "",
        "dayMessage": "연어와 현미밥으로 탄단지 균형을 잘 맞췄어요.",
        "exercises": [
            ("저강도 유산소 (걷기) 30분", "cardio", 30, True),
            ("코어 강화 10분", "strength", 10, True),
            ("하체 스트레칭 15분", "flexibility", 15, True),
        ],
        "meals": [
            (B_YOG, "seed-diet-two-days-ago-breakfast", "08:35",
             "그릭 요거트의 단백질과 견과류의 불포화지방을 고르게 섭취했어요."),
            (L_BIB, "seed-diet-two-days-ago-lunch", "12:20",
             "야채가 풍부한 비빔밥이에요. 고추장을 줄이면 나트륨을 더 조절할 수 있어요."),
            (D_SLM, "seed-diet-two-days-ago-dinner", "18:50",
             "연어의 지방과 현미밥의 복합 탄수화물 조합이 좋아요."),
        ],
    },
]


def _round1(value: float) -> float:
    """당류·탄단지는 소수 한 자리. 부동소수 찌꺼기가 JSON 에 남지 않게 자른다."""
    return round(value + 0.0, 1)


def _meal_entry(
    meal_id: str,
    *,
    row_id: str | None = None,
    time_label: str | None = None,
    ai_comment: str | None = None,
) -> dict:
    entry: dict = {"meal": meal_id}
    if row_id:
        entry["id"] = row_id
    if time_label:
        entry["timeLabel"] = time_label
    if ai_comment:
        entry["aiComment"] = ai_comment
    return entry


def _exercise(name: str, kind: str, minutes: int, done: bool) -> dict:
    return {
        "name": name,
        "type": kind,
        "minutes": minutes,
        "calories": round(minutes * KCAL_PER_MIN[kind]),
        "done": done,
    }


def _grid_day(weekday: int, plan: list[str | None], skipped: int) -> dict:
    routine = ROUTINE[weekday]
    kept = len(routine) - skipped
    return {
        "weekday": weekday,
        "label": "AI 루틴 · 자율 운동",
        "pt": False,
        "exercises": [
            _exercise(name, kind, minutes, index < kept)
            for index, (name, kind, minutes) in enumerate(routine)
        ],
        "meals": [_meal_entry(meal) for meal in plan if meal is not None],
    }


def build() -> dict:
    weeks = []
    for index in range(HISTORY_WEEKS):
        note, plans, skips = WEEK_STORIES[index % len(WEEK_STORIES)]
        days = []
        for weekday in range(7):
            plan = plans[weekday]
            if plan is None:
                # 기록이 아예 없는 날. 루틴도 남기지 않는다 — 식단만 비고 운동만
                # 남으면 그날 화면이 반쪽으로 읽힌다.
                days.append({"weekday": weekday, "exercises": [], "meals": []})
                continue
            days.append(_grid_day(weekday, plan, skips.get(weekday, 0)))
        weeks.append({"weeksAgo": index, "note": note, "days": days})

    recent = []
    for day in RECENT:
        recent.append({
            "offset": day["offset"],
            "label": day["label"],
            "pt": day["pt"],
            "clientFeedback": day["clientFeedback"],
            "trainerNote": day["trainerNote"],
            "dayMessage": day["dayMessage"],
            "exercises": [_exercise(*item) for item in day["exercises"]],
            "meals": [
                _meal_entry(meal, row_id=row_id, time_label=time_label, ai_comment=comment)
                for meal, row_id, time_label, comment in day["meals"]
            ],
        })

    return {
        "version": 1,
        "readme": (
            "김민수 데모 데이터의 단일 원본. 사용자앱·트레이너웹·백엔드가 이 파일만 "
            "읽는다. 날짜는 상대값이다 — weeks[].weeksAgo 는 이번 주 월요일에서 몇 주 "
            "거슬러 올라가는지, days[].weekday 는 월(0)~일(6). recent[].offset 은 "
            "오늘로부터의 일수이고 주 격자 위를 덮는다. 이행률은 exercises[].done "
            "개수에서 계산한다 — 퍼센트를 따로 적지 않는다."
        ),
        "member": {
            "name": "김민수",
            "userAppSeedId": "user-demo",
            "trainerClientId": "seed-client-1",
        },
        "historyWeeks": HISTORY_WEEKS,
        "foods": {
            key: {
                "name": name,
                "calories": calories,
                "sodiumMg": sodium,
                "sugarG": _round1(sugar),
                "carbsG": _round1(carbs),
                "proteinG": _round1(protein),
                "fatG": _round1(fat),
            }
            for key, (name, calories, sodium, sugar, carbs, protein, fat) in FOODS.items()
        },
        "meals": {
            key: {
                "mealType": meal_type,
                "timeLabel": time_label,
                "photoAsset": photo,
                "aiComment": comment,
                "foods": foods,
            }
            for key, (meal_type, time_label, photo, comment, foods) in MEALS.items()
        },
        "recent": recent,
        "weeks": weeks,
    }


_DART_HEADER = '''// GENERATED — 손으로 고치지 말 것.
//
// `python3 tool/gen_demo_fixture.py` 가
// `shared/demo_fixture/assets/kim_minsu.json` 과 함께 만든다. 고칠 값은 그 JSON 에
// 있고, 두 파일이 어긋나면 패키지 테스트가 잡는다.

/// 김민수 데모 픽스처의 JSON 원문.
const String kimMinsuFixtureJson = r\'\'\'
'''


def main() -> None:
    payload = json.dumps(build(), ensure_ascii=False, indent=2) + "\n"
    for path in (OUT, OUT_BACKEND):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload, encoding="utf-8")
        print(f"wrote {path}")

    # raw 문자열(r''')로 감싼다 — JSON 에 백슬래시 이스케이프가 들어와도 Dart 가 다시
    # 해석하지 않는다. JSON 은 작은따옴표 세 개를 만들 수 없어(문자열 값은 큰따옴표로
    # 이스케이프된다) 구분자와 부딪히지 않는다.
    assert "'''" not in payload, "픽스처에 ''' 이 들어가면 raw 문자열이 깨진다"
    OUT_DART.parent.mkdir(parents=True, exist_ok=True)
    OUT_DART.write_text(_DART_HEADER + payload + "''';\n", encoding="utf-8")
    print(f"wrote {OUT_DART}")


if __name__ == "__main__":
    main()
