"""공공 식품영양성분 DB 매핑.

- 정규화/후보 매칭은 순수(로컬 실행).
- 시드 조회 + 보강(enrich)은 DB 필요(로컬 skip, CI 실행).
"""
from __future__ import annotations

from types import SimpleNamespace

from app.services.nutrition.matcher import match_in_rows, normalize


# ---------- 순수 유닛 ----------

def test_normalize_strips_space_punct_digits():
    assert normalize("김치  찌개!!") == "김치찌개"
    assert normalize("공기밥 1") == "공기밥"
    assert normalize("후라이드 치킨 (1개)") == "후라이드치킨개"  # 숫자만 제거, 단위어는 남음
    assert normalize("   ") == ""


def _rows(*names):
    return [SimpleNamespace(name_norm=normalize(n)) for n in names]


def test_match_exact_and_contained():
    rows = _rows("김치찌개", "김치", "된장찌개")
    # 정확 일치
    assert match_in_rows(rows, "김치찌개").name_norm == "김치찌개"
    # 서술형 질의에 음식명 포함 → 가장 긴 이름(김치찌개 > 김치)
    assert match_in_rows(rows, "점심에 먹은 김치찌개 1인분").name_norm == "김치찌개"
    # '김치'는 정확 일치가 우선
    assert match_in_rows(rows, "김치").name_norm == "김치"


def test_match_none_when_unknown_or_ambiguous():
    rows = _rows("된장찌개", "된장국")
    assert match_in_rows(rows, "외계인 수프") is None          # 미매칭
    assert match_in_rows(rows, "된장") is None                 # 여러 이름의 부분 → 모호 → 폴백


# ---------- DB (CI) ----------

def test_food_nutrients_seeded_and_lookup(db_session):
    from app.services.nutrition.matcher import match_food

    m = match_food(db_session, "김치찌개")
    assert m is not None
    assert m.sodium_mg > 500  # 시드의 신뢰 나트륨 값
    # 서술형 이름도 매칭
    assert match_food(db_session, "오늘 저녁 김치찌개").name_norm == "김치찌개"


def test_enrich_overrides_matched_keeps_unmatched(db_session):
    from app.schemas.diet import DietAnalysis, RecognizedFood
    from app.services.nutrition.enrich import enrich_analysis

    analysis = DietAnalysis(engine="gemini", foods=[
        RecognizedFood(name="김치찌개", calories=999, sodium_mg=50, sugar_g=99),  # LLM 엉터리 추정
        RecognizedFood(name="외계인수프", calories=123, sodium_mg=45, sugar_g=6),  # 미매칭
    ])
    enrich_analysis(db_session, analysis)

    matched, unmatched = analysis.foods
    assert matched.source == "db" and matched.sodium_mg > 500      # DB 신뢰값으로 교체
    assert matched.calories != 999
    assert unmatched.source == "estimate" and unmatched.sodium_mg == 45  # 추정 유지
    # 합계 재계산
    assert analysis.total_sodium_mg == matched.sodium_mg + unmatched.sodium_mg
    assert analysis.total_calories == matched.calories + unmatched.calories


def test_enrich_keeps_fractional_sugar_from_the_public_db(db_session):
    """#296 회귀: 보정 단계가 당류를 int 로 깎으면 안 된다.

    컬럼·스키마·클라이언트를 전부 소수로 통일했는데(#362, #368) 보정이
    `int(round(...))` 로 되돌리고 있었다. 시드가 마침 정수뿐이라 드러나지
    않았을 뿐, 식약처 실데이터는 8.5g 같은 소수가 정상이다.
    """
    from app.models.models import FoodNutrient
    from app.schemas.diet import DietAnalysis, RecognizedFood
    from app.services.nutrition.enrich import enrich_analysis
    from app.services.nutrition.matcher import normalize

    db_session.add(
        FoodNutrient(
            name="소수당류식품",
            name_norm=normalize("소수당류식품"),
            calories=100,
            sodium_mg=10,
            sugar_g=8.5,
        )
    )
    db_session.commit()

    analysis = DietAnalysis(
        engine="gemini",
        foods=[RecognizedFood(name="소수당류식품", calories=1, sodium_mg=1, sugar_g=1)],
    )
    enrich_analysis(db_session, analysis)

    food = analysis.foods[0]
    assert food.source == "db"
    # 예전에는 round(8.5) → 8 (은행가 반올림) 이었다.
    assert food.sugar_g == 8.5
    assert analysis.total_sugar_g == 8.5

