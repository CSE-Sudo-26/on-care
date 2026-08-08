"""음식명 → 공공 식품영양성분 DB 매칭.

정규화(normalize)와 후보 매칭(match_in_rows)은 순수 함수로, 모델/DB 의존이 없어
로컬 유닛 테스트가 가능하다. DB 조회가 필요한 match_food 만 지연 import 한다.

매칭 전략(오탐 < 폴백 원칙: 틀린 영양가보다 추정 유지가 낫다):
  1) 정확 일치       : 정규화 이름이 동일
  2) 포함(질의가 상세): DB 음식명이 질의 안에 들어감 → 가장 긴 이름 채택
     (예: "점심에 먹은 김치찌개 1인분" → "김치찌개")
  3) 유일 포함        : 질의가 정확히 한 DB 이름의 부분일 때만 채택(모호하면 폴백)
"""
from __future__ import annotations

import re

_DIGIT = re.compile(r"\d+")
_PUNCT = re.compile(r"[\s()\[\]{}·.,/\\\-_+~!?'\"]+")


def normalize(name: str) -> str:
    """매칭용 정규화: 소문자화 + 숫자/공백/구두점 제거."""
    s = (name or "").strip().lower()
    s = _DIGIT.sub("", s)
    s = _PUNCT.sub("", s)
    return s


def match_in_rows(rows, name: str):
    """정규화된 name 을 rows(각 원소는 .name_norm 속성 보유)에 매칭. 없으면 None."""
    q = normalize(name)
    if not q:
        return None

    # 1) 정확 일치
    for r in rows:
        if r.name_norm and r.name_norm == q:
            return r

    # 2) DB 음식명이 질의에 포함 → 가장 구체적인(긴) 이름
    contained = [r for r in rows if r.name_norm and r.name_norm in q]
    if contained:
        return max(contained, key=lambda r: len(r.name_norm))

    # 3) 질의가 정확히 하나의 DB 이름의 부분 → 유일할 때만
    containing = [r for r in rows if r.name_norm and q in r.name_norm]
    if len(containing) == 1:
        return containing[0]

    return None


def match_food(db, name: str):
    """food_nutrients 전건에 매칭(작은 참조표라 전건 로드로 충분 — 로드는 캐시된다)."""
    from app.services.nutrition.table import load_rows

    return match_in_rows(load_rows(db), name)
