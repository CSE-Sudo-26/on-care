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


# ---------- 공공 표준데이터 임포터 (순수) ----------

def _raw(name, rep, origin, weight, kcal, na, sugar, cat="찌개류"):
    return {
        "식품명": name, "대표식품명": rep, "식품기원명": origin,
        "식품중량": weight, "식품대분류명": cat,
        "에너지(kcal)": kcal, "나트륨(mg)": na, "당류(g)": sugar,
        "탄수화물(g)": "", "단백질(g)": "", "지방(g)": "",
    }


def test_import_excludes_franchise_rows():
    """판매 단위(라지 피자 한 판)를 1인분으로 환산하면 안 된다."""
    from scripts.import_food_nutrients import aggregate

    rows = [
        _raw("피자_라지", "피자", "외식(프랜차이즈 등 업체 제공 영양정", "1640g", "252", "416", "3.7"),
        _raw("피자_급식", "피자", "초등학교급식(재료량 기반 산출 함량)", "200g", "253", "441", "3.4"),
    ]
    out = aggregate(rows)
    assert len(out) == 1
    # 프랜차이즈 1,640g 행이 섞였다면 1인분이 900g 대로 튄다.
    assert out[0]["serving_size_g"] == 200.0


def test_import_converts_100g_basis_to_one_serving():
    """원본은 전부 100g 기준 — 식품중량으로 환산해야 한다."""
    from scripts.import_food_nutrients import aggregate

    out = aggregate([_raw("김치찌개_돼지", "김치찌개", "가정식(분석 함량)", "300g", "31", "445", "0.04")])
    assert out[0]["calories"] == 93.0        # 31 * 300/100
    assert out[0]["sodium_mg"] == 1335.0     # 445 * 300/100
    assert out[0]["sugar_g"] == 0.12         # 0.04 * 3 — 소수 보존


def test_import_uses_median_not_mean():
    """이상치 한 건이 대표값을 끌고 가면 안 된다."""
    from scripts.import_food_nutrients import aggregate

    rows = [
        _raw(f"국_{i}", "된장국", "가정식(분석 함량)", "100g", kcal, "100", "1")
        for i, kcal in enumerate(["10", "20", "900"])
    ]
    out = aggregate(rows)
    assert out[0]["calories"] == 20.0        # 평균이면 310


def test_import_parses_weight_without_unit():
    """식품중량은 '300g' 도 있고 단위 없는 '201.7' 도 있다."""
    from scripts.import_food_nutrients import aggregate

    out = aggregate([_raw("찌개", "찌개", "가정식(분석 함량)", "201.7", "50", "100", "1")])
    assert out[0]["serving_size_g"] == 201.7


def test_import_skips_rows_without_energy_or_weight():
    """보정 값으로 쓸 수 없는 행은 버린다."""
    from scripts.import_food_nutrients import aggregate

    rows = [
        _raw("무게없음", "무게없음", "가정식(분석 함량)", "", "50", "100", "1"),
        _raw("열량없음", "열량없음", "가정식(분석 함량)", "300g", "", "100", "1"),
    ]
    assert aggregate(rows) == []


# ---------- 시드 우선순위 (DB) ----------

def test_curated_seed_wins_over_public_data(db_session):
    """큐레이션 40종은 고혈압·당뇨 관점으로 따로 검증한 값이라 우선한다."""
    from app.services.nutrition.matcher import match_food

    # 라면: 큐레이션 1,800mg vs 공공 중앙값 452mg(급식 라면이 섞인 결과)
    ramen = match_food(db_session, "라면")
    assert ramen is not None
    assert ramen.sodium_mg == 1800

    # 공공 데이터에만 있는 항목도 조회된다.
    assert match_food(db_session, "가오리찜") is not None

