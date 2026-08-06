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
    # 값은 100g 기준이다(큐레이션 1,200mg/400g → 300). 1인분 절대값이 아니다.
    assert 100 < m.sodium_mg < 500
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


def _raw(name, rep, origin, weight, kcal, na, sugar, cat="찌개류"):
    return {
        "식품명": name, "대표식품명": rep, "식품기원명": origin,
        "식품중량": weight, "식품대분류명": cat,
        "에너지(kcal)": kcal, "나트륨(mg)": na, "당류(g)": sugar,
        "탄수화물(g)": "", "단백질(g)": "", "지방(g)": "",
    }


def test_import_keeps_the_100g_basis_untouched():
    """원본이 100g 기준이므로 환산하지 않는다 — 손실도 추측도 없다."""
    from scripts.import_food_nutrients import aggregate

    out = aggregate([_raw("김치찌개_돼지", "김치찌개", "가정식(분석 함량)", "300g", "31", "445", "0.04")], "음식")
    assert out[0]["calories"] == 31.0        # 300g 로 환산하지 않는다
    assert out[0]["sodium_mg"] == 445.0
    assert out[0]["sugar_g"] == 0.04         # 소수 보존


def test_import_keeps_franchise_rows_for_density():
    """포장 크기는 100g 당 값에 영향을 주지 않으므로 제외할 이유가 없다."""
    from scripts.import_food_nutrients import aggregate

    rows = [
        _raw("피자_라지", "피자", "외식(프랜차이즈 등 업체 제공 영양정", "1640g", "252", "416", "3.7"),
        _raw("피자_급식", "피자", "초등학교급식(재료량 기반 산출 함량)", "200g", "254", "420", "3.5"),
    ]
    out = aggregate(rows, "음식")
    assert out[0]["sample_count"] == 2       # 프랜차이즈도 표본에 든다
    assert out[0]["calories"] == 253.0       # 두 값의 중앙


def test_import_serving_hint_ignores_franchise_packaging():
    """1회 섭취량 힌트에는 판매 포장(라지 피자 한 판)을 쓰지 않는다."""
    from scripts.import_food_nutrients import aggregate

    rows = [
        _raw("피자_라지", "피자", "외식(프랜차이즈 등 업체 제공 영양정", "1640g", "252", "416", "3.7"),
        _raw("피자_급식", "피자", "초등학교급식(재료량 기반 산출 함량)", "200g", "254", "420", "3.5"),
    ]
    assert aggregate(rows, "음식")[0]["serving_size_g"] == 200.0


def test_import_leaves_serving_blank_when_unknown():
    """식품중량이 없는 데이터셋(원재료성식품)은 힌트를 비워 둔다 — 추측하지 않는다."""
    from scripts.import_food_nutrients import aggregate

    out = aggregate([_raw("사과", "사과", "원재료", "", "52", "1", "10.4")], "원재료성식품")
    assert out[0]["serving_size_g"] is None
    assert out[0]["calories"] == 52.0        # 100g 기준 값은 그대로 쓸 수 있다


def test_import_uses_median_not_mean():
    """이상치 한 건이 대표값을 끌고 가면 안 된다."""
    from scripts.import_food_nutrients import aggregate

    rows = [
        _raw(f"국_{i}", "된장국", "가정식(분석 함량)", "100g", kcal, "100", "1")
        for i, kcal in enumerate(["10", "20", "900"])
    ]
    assert aggregate(rows, "음식")[0]["calories"] == 20.0     # 평균이면 310


def test_import_skips_rows_without_energy():
    """보정 값으로 쓸 수 없는 행은 버린다."""
    from scripts.import_food_nutrients import aggregate

    assert aggregate([_raw("열량없음", "열량없음", "가정식(분석 함량)", "300g", "", "100", "1")], "음식") == []


# ---------- 양(g) 기반 보정 (DB) ----------

def test_enrich_scales_by_estimated_amount(db_session):
    """같은 음식이라도 사진에 담긴 양에 비례해야 한다."""
    from app.schemas.diet import DietAnalysis, RecognizedFood
    from app.services.nutrition.enrich import enrich_analysis

    def kcal_for(grams):
        a = DietAnalysis(engine="g", foods=[RecognizedFood(name="김치찌개", amount_g=grams)])
        enrich_analysis(db_session, a)
        return a.foods[0]

    small, large = kcal_for(200), kcal_for(800)
    assert small.source == "db" and large.source == "db"
    assert large.calories == small.calories * 4
    assert large.sodium_mg == small.sodium_mg * 4


def test_enrich_falls_back_to_known_serving_when_amount_missing(db_session):
    """양을 못 얻으면 알려진 1회 섭취량으로만 환산한다."""
    from app.schemas.diet import DietAnalysis, RecognizedFood
    from app.services.nutrition.enrich import enrich_analysis

    a = DietAnalysis(engine="g", foods=[RecognizedFood(name="김치찌개", calories=999)])
    enrich_analysis(db_session, a)
    assert a.foods[0].source == "db"
    assert a.foods[0].calories != 999


def test_enrich_keeps_estimate_when_amount_and_serving_unknown(db_session):
    """양도 1회 섭취량도 없으면 임의로 가정하지 않는다.

    틀린 양으로 환산한 값은 source="db" 로 표시돼 사용자에게 더 높은 신뢰
    신호를 준다 — 추정치를 그대로 두는 편이 낫다.
    """
    from app.models.models import FoodNutrient
    from app.schemas.diet import DietAnalysis, RecognizedFood
    from app.services.nutrition.enrich import enrich_analysis
    from app.services.nutrition.matcher import normalize

    db_session.add(FoodNutrient(
        name="양모르는음식", name_norm=normalize("양모르는음식"),
        calories=100, sodium_mg=10, sugar_g=1, serving_size_g=None,
    ))
    db_session.commit()

    a = DietAnalysis(engine="g", foods=[RecognizedFood(name="양모르는음식", calories=777)])
    enrich_analysis(db_session, a)
    assert a.foods[0].source == "estimate"
    assert a.foods[0].calories == 777


def test_enrich_keeps_fractional_sugar(db_session):
    """#296 회귀: 보정이 당류를 int 로 깎으면 안 된다."""
    from app.models.models import FoodNutrient
    from app.schemas.diet import DietAnalysis, RecognizedFood
    from app.services.nutrition.enrich import enrich_analysis
    from app.services.nutrition.matcher import normalize

    db_session.add(FoodNutrient(
        name="소수당류식품", name_norm=normalize("소수당류식품"),
        calories=100, sodium_mg=10, sugar_g=8.5, serving_size_g=100,
    ))
    db_session.commit()

    a = DietAnalysis(engine="g", foods=[RecognizedFood(name="소수당류식품", amount_g=100)])
    enrich_analysis(db_session, a)
    assert a.foods[0].sugar_g == 8.5      # 예전에는 round(8.5) → 8


def test_curated_seed_wins_over_public_data(db_session):
    """큐레이션 40종은 고혈압·당뇨 관점으로 따로 검증한 값이라 우선한다."""
    from app.services.nutrition.matcher import match_food

    ramen = match_food(db_session, "라면")
    assert ramen is not None
    # 큐레이션 1,800mg/550g → 100g 당 327.3
    assert round(ramen.sodium_mg, 1) == 327.3
    assert match_food(db_session, "가공우유") is not None   # 가공식품 데이터셋
