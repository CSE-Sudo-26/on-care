"""운동 유형 어휘 — 유산소 / 근력 / 유연성 / 기타 네 가지. (#996)

예전에는 회원 기록이 `cardio|strength|yoga|walking`, 트레이너 루틴이
`걷기|유산소|근력|요가|스트레칭|기타` 로 서로 다른 어휘를 썼다. 같은 운동을 두
화면이 다른 이름으로 부르니 집계·리포트에서 버킷을 화면마다 다시 만들어야 했다.

네 가지로 좁히고 한 곳에서 정규화한다. 세분화가 필요한 자리(트레이너가 프로그램을
짤 때의 세부 종목)는 유형이 아니라 **종목 이름**으로 적는다 — 유형은 집계 축이지
운동 이름이 아니다.

옛 값은 버리지 않고 흡수한다. 이미 저장된 기록과 아직 옛 값을 보내는 클라이언트가
있으므로, 정규화는 읽기·쓰기 양쪽에서 일어난다.
"""
from __future__ import annotations

#: 표준 영문 코드 — 회원 앱 기록(`exercise_sessions.type`)이 쓴다.
CARDIO = "cardio"
STRENGTH = "strength"
FLEXIBILITY = "flexibility"
OTHER = "other"

CANONICAL_TYPES: tuple[str, ...] = (CARDIO, STRENGTH, FLEXIBILITY, OTHER)

#: 표준 한글 라벨 — 트레이너 루틴(`trainer_routines.type`)이 쓴다.
KOREAN_LABELS: tuple[str, ...] = ("유산소", "근력", "유연성", "기타")

_TO_CODE = {
    # 표준
    CARDIO: CARDIO,
    STRENGTH: STRENGTH,
    FLEXIBILITY: FLEXIBILITY,
    OTHER: OTHER,
    "유산소": CARDIO,
    "근력": STRENGTH,
    "유연성": FLEXIBILITY,
    "기타": OTHER,
    # 옛 값 — 걷기는 유산소로, 요가·스트레칭은 유연성으로 접는다.
    "walking": CARDIO,
    "걷기": CARDIO,
    "yoga": FLEXIBILITY,
    "요가": FLEXIBILITY,
    "stretching": FLEXIBILITY,
    "스트레칭": FLEXIBILITY,
}

_CODE_TO_KO = {
    CARDIO: "유산소",
    STRENGTH: "근력",
    FLEXIBILITY: "유연성",
    OTHER: "기타",
}


def normalize(value: str | None) -> str:
    """어떤 표기로 들어와도 표준 영문 코드로. 모르는 값은 `other`."""
    if not value:
        return OTHER
    return _TO_CODE.get(value.strip(), OTHER)


def normalize_ko(value: str | None) -> str:
    """어떤 표기로 들어와도 표준 한글 라벨로. 모르는 값은 `기타`."""
    return _CODE_TO_KO[normalize(value)]


#: 옛 어휘 → 표준 한글 라벨. 표준 값과 모르는 값은 여기 없다.
_LEGACY_KO = {
    "걷기": "유산소",
    "요가": "유연성",
    "스트레칭": "유연성",
    "walking": "유산소",
    "yoga": "유연성",
    "stretching": "유연성",
}


def fold_legacy_ko(value: object) -> object:
    """옛 값만 표준 한글 라벨로 접는다. **모르는 값은 그대로 둔다.**

    `normalize_ko` 와 나눠 둔 이유가 이것이다 — 스키마 검증 앞단에서 모든 값을
    기타로 덮으면 오타나 엉뚱한 입력이 조용히 통과한다. 옛 어휘를 받아 주는 것과
    아무 값이나 받아 주는 것은 다르다. (#996)
    """
    if isinstance(value, str):
        return _LEGACY_KO.get(value.strip(), value)
    return value


def label_for(value: str | None) -> str:
    """사람이 읽을 라벨. **모르는 값은 원문 그대로** 둔다.

    `normalize_ko` 와 다른 점이 여기다. 검색 문서에 넣는 문구는 회원이 실제로
    적은 것을 잃지 않아야 한다 — 손으로 넣은 `crossfit` 을 `기타` 로 덮으면
    "크로스핏 얼마나 했지" 라는 질문이 자기 기록을 못 찾는다.
    """
    if not value:
        return _CODE_TO_KO[OTHER]
    key = value.strip()
    if key in _TO_CODE:
        return _CODE_TO_KO[_TO_CODE[key]]
    return key


def is_legacy(value: str | None) -> bool:
    """옛 어휘인가 — 마이그레이션·이관 검증에서 쓴다."""
    return bool(value) and value not in CANONICAL_TYPES and value not in KOREAN_LABELS
