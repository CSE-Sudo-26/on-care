"""식단 사진분석(/diet/analyze) — DB 필요(로컬 skip, CI 실행).

CI 엔 GEMINI_API_KEY 가 없으므로 오프라인 스텁 인식기 경로를 검증한다
(이미지 내용과 무관하게 결정론적 식단 → 공공 영양 DB 매핑 → 저장).
"""
from __future__ import annotations

import json
import math
import uuid
from uuid import uuid4

import pytest
from pydantic import ValidationError
from sqlalchemy import delete, select

_JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF fake-image-bytes"


def test_macro_percentages_use_449_and_always_sum_correctly():
    from app.schemas.diet_api import calculate_macros

    equal_energy = calculate_macros(9.0, 9.0, 4.0)
    assert (equal_energy.carbs_pct, equal_energy.protein_pct, equal_energy.fat_pct) == (
        33, 33, 34,
    )
    assert equal_energy.carbs_pct + equal_energy.protein_pct + equal_energy.fat_pct == 100

    regular = calculate_macros(25.0, 12.5, 5.0)
    assert (regular.carbs_pct, regular.protein_pct, regular.fat_pct) == (51, 26, 23)
    assert regular.carbs_pct + regular.protein_pct + regular.fat_pct == 100

    zero = calculate_macros(0.0, 0.0, 0.0)
    assert (zero.carbs_pct, zero.protein_pct, zero.fat_pct) == (0, 0, 0)
    assert zero.carbs_pct + zero.protein_pct + zero.fat_pct == 0


@pytest.mark.parametrize("field", ["carbs_g", "protein_g", "fat_g"])
@pytest.mark.parametrize("value", [-0.1, math.nan, math.inf, -math.inf])
def test_recognized_food_rejects_invalid_macros(field, value):
    from app.schemas.diet import RecognizedFood

    with pytest.raises(ValidationError):
        RecognizedFood(name="test", **{field: value})


@pytest.mark.parametrize("field", ["carbs_g", "protein_g", "fat_g"])
def test_recognized_food_allows_optional_and_positive_macros(field):
    from app.schemas.diet import RecognizedFood

    assert getattr(RecognizedFood(name="test", **{field: None}), field) is None
    assert getattr(RecognizedFood(name="test", **{field: 1.25}), field) == 1.25


def test_gemini_parser_sanitizes_and_totals_optional_macros():
    from app.services.recognizer.gemini import GeminiVisionRecognizer

    raw = json.dumps({
        "foods": [
            {
                "name": "비빔밥",
                "carbs_g": 68.5,
                "protein_g": 18,
                "fat_g": 12.25,
            },
            {
                "name": "김치",
                "carbs_g": None,
                "protein_g": 2.5,
                "fat_g": None,
            },
            {
                "name": "잘못된 값",
                "carbs_g": -1,
                "protein_g": "NaN",
                "fat_g": "Infinity",
            },
            {
                "name": "일부 정상 값",
                "carbs_g": "-Infinity",
                "protein_g": 3,
                "fat_g": 1,
            },
        ],
    })

    analysis = GeminiVisionRecognizer.__new__(GeminiVisionRecognizer)._parse(raw, 10)

    assert (analysis.foods[0].carbs_g, analysis.foods[0].protein_g, analysis.foods[0].fat_g) == (
        68.5, 18.0, 12.25,
    )
    assert (analysis.foods[1].carbs_g, analysis.foods[1].protein_g, analysis.foods[1].fat_g) == (
        None, 2.5, None,
    )
    assert (analysis.foods[2].carbs_g, analysis.foods[2].protein_g, analysis.foods[2].fat_g) == (
        None, None, None,
    )
    assert (analysis.foods[3].carbs_g, analysis.foods[3].protein_g, analysis.foods[3].fat_g) == (
        None, 3.0, 1.0,
    )
    assert (analysis.total_carbs_g, analysis.total_protein_g, analysis.total_fat_g) == (
        68.5, 23.5, 13.25,
    )


def test_litellm_parser_sanitizes_and_totals_optional_macros():
    from app.services.recognizer.litellm_vision import LiteLLMVisionRecognizer

    raw = """```json
{"foods":[
  {"name":"비빔밥","carbs_g":68.5,"protein_g":18,"fat_g":12.25},
  {"name":"김치","carbs_g":null,"protein_g":2.5,"fat_g":null},
  {"name":"잘못된 값","carbs_g":-1,"protein_g":"NaN","fat_g":"Infinity"},
  {"name":"일부 정상 값","carbs_g":"-Infinity","protein_g":3,"fat_g":1}
]}
```"""

    analysis = LiteLLMVisionRecognizer.__new__(LiteLLMVisionRecognizer)._parse(raw, 10)

    assert (analysis.foods[0].carbs_g, analysis.foods[0].protein_g, analysis.foods[0].fat_g) == (
        68.5, 18.0, 12.25,
    )
    assert (analysis.foods[1].carbs_g, analysis.foods[1].protein_g, analysis.foods[1].fat_g) == (
        None, 2.5, None,
    )
    assert (analysis.foods[2].carbs_g, analysis.foods[2].protein_g, analysis.foods[2].fat_g) == (
        None, None, None,
    )
    assert (analysis.foods[3].carbs_g, analysis.foods[3].protein_g, analysis.foods[3].fat_g) == (
        None, 3.0, 1.0,
    )
    assert (analysis.total_carbs_g, analysis.total_protein_g, analysis.total_fat_g) == (
        68.5, 23.5, 13.25,
    )


@pytest.mark.parametrize("field", ["carbs_g", "protein_g", "fat_g"])
@pytest.mark.parametrize("value", [math.nan, math.inf, -math.inf])
def test_entry_update_rejects_non_finite_macros(field, value):
    from app.schemas.diet_api import DietEntryUpdate

    with pytest.raises(ValidationError):
        DietEntryUpdate(**{field: value})


def test_analyze_offline_saves_and_reflects_macros_in_today(client, db_session):
    from app.services.diet_service import today_str as _today_str
    from app.db.init_db import DEMO_USER_ID
    from app.models.models import DietEntry, FoodNutrient

    # Isolate exact daily totals, then give the two stub-recognized foods DB macros.
    db_session.execute(
        delete(DietEntry).where(
            DietEntry.user_id == DEMO_USER_ID,
            DietEntry.date == _today_str(),
        )
    )
    bibimbap = db_session.scalar(select(FoodNutrient).where(FoodNutrient.name == "비빔밥"))
    kimchi = db_session.scalar(select(FoodNutrient).where(FoodNutrient.name == "김치"))
    assert bibimbap is not None and kimchi is not None
    bibimbap.carbs_g, bibimbap.protein_g, bibimbap.fat_g = 40.0, 20.0, 8.0
    kimchi.carbs_g, kimchi.protein_g, kimchi.fat_g = 5.0, 2.5, 2.0
    db_session.commit()

    r = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["entry_id"]
    foods = body["analysis"]["foods"]
    assert foods  # 인식된 음식이 있어야
    # 공공 영양 DB 매핑으로 신뢰 수치가 채워짐(비빔밥/김치는 시드에 존재)
    assert body["analysis"]["total_calories"] > 0
    assert any(f["source"] == "db" for f in foods)
    assert body["analysis"]["total_carbs_g"] == 45.0
    assert body["analysis"]["total_protein_g"] == 22.5
    assert body["analysis"]["total_fat_g"] == 10.0
    assert all({"carbs_g", "protein_g", "fat_g"} <= f.keys() for f in foods)

    stored = db_session.get(DietEntry, body["entry_id"])
    assert stored is not None
    assert (stored.carbs_g, stored.protein_g, stored.fat_g) == (45.0, 22.5, 10.0)
    stored_foods = json.loads(stored.foods_json)
    assert all(not {"carbs_g", "protein_g", "fat_g"} & food.keys() for food in stored_foods)

    second = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "dinner"},
    )
    assert second.status_code == 200, second.text

    today = client.get("/v1/diet/days/today")
    assert today.status_code == 200
    today_body = today.json()
    assert today_body["total_calories"] > 0
    assert len(today_body["entries"]) == 2
    assert all(entry["carbs_g"] == 45.0 for entry in today_body["entries"])
    assert all(entry["protein_g"] == 22.5 for entry in today_body["entries"])
    assert all(entry["fat_g"] == 10.0 for entry in today_body["entries"])
    assert all(
        not {"carbs_g", "protein_g", "fat_g"} & food.keys()
        for entry in today_body["entries"]
        for food in entry["foods"]
    )
    assert today_body["macros"] == {
        "carbs_g": 90.0,
        "protein_g": 45.0,
        "fat_g": 20.0,
        "carbs_pct": 50,
        "protein_pct": 25,
        "fat_pct": 25,
    }


def test_analyze_succeeds_when_personal_rag_ingest_fails(
    client, db_session, monkeypatch
):
    """보조 RAG 적재 실패가 이미 저장된 식단의 성공 응답을 500으로 바꾸지 않는다."""
    from app.models.models import DietEntry
    from app.services import diet_service

    def fail_record_diet(*args, **kwargs):
        raise RuntimeError("embedding unavailable")

    monkeypatch.setattr(diet_service, "record_diet", fail_record_diet)

    response = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch"},
    )

    assert response.status_code == 200, response.text
    entry_id = response.json()["entry_id"]
    db_session.expire_all()
    assert db_session.get(DietEntry, entry_id) is not None


def test_save_analyzed_entry_isolates_rag_failure_without_database(monkeypatch):
    """서비스 경계의 best-effort 처리를 DB 없이도 빠르게 검증한다."""
    from unittest.mock import MagicMock

    from app.schemas.diet import DietAnalysis
    from app.services import diet_service

    db = MagicMock()

    def fail_record_diet(*args, **kwargs):
        raise RuntimeError("embedding unavailable")

    monkeypatch.setattr(diet_service, "record_diet", fail_record_diet)
    entry, is_new = diet_service.save_analyzed_entry(
        db,
        "user-test",
        "lunch",
        DietAnalysis(engine="stub"),
        None,
    )

    assert is_new is True
    assert entry.user_id == "user-test"
    db.commit.assert_called_once()
    db.refresh.assert_called_once_with(entry)
    db.rollback.assert_called_once()


def test_analyze_idempotency_key_dedupes_retry(client):
    key = f"idem-{uuid4().hex}"
    first = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch", "idempotency_key": key},
    )
    assert first.status_code == 200, first.text
    eid = first.json()["entry_id"]

    # 응답 유실 후 재시도를 흉내 — 같은 키로 재요청하면 새 저장 없이 기존 entry 반환.
    second = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch", "idempotency_key": key},
    )
    assert second.status_code == 200, second.text
    assert second.json()["entry_id"] == eid

    today = client.get("/v1/diet/days/today").json()["entries"]
    assert sum(1 for e in today if e["id"] == eid) == 1


def test_analyze_rejects_overlong_idempotency_key(client):
    # DB 컬럼(String(64))을 넘는 키는 DB 도달 전 API 경계(max_length=64)에서
    # 422 로 거부되어야 한다(초과 시 PostgreSQL DataError→500 방지).
    overlong = "x" * 65
    r = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch", "idempotency_key": overlong},
    )
    assert r.status_code == 422, r.text

    # 경계값(정확히 64자)은 정상 처리되어야 한다.
    ok = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch", "idempotency_key": "y" * 64},
    )
    assert ok.status_code == 200, ok.text


def test_analyze_without_key_creates_distinct_entries(client):
    a = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch"},
    ).json()["entry_id"]
    b = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch"},
    ).json()["entry_id"]
    assert a != b


def test_analyze_rejects_unsupported_mime(client):
    r = client.post(
        "/v1/diet/analyze",
        files={"image": ("note.txt", b"hello", "text/plain")},
        data={"meal_type": "lunch"},
    )
    assert r.status_code == 415


def test_analyze_rejects_empty_file(client):
    r = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", b"", "image/jpeg")},
        data={"meal_type": "lunch"},
    )
    assert r.status_code == 400


def test_enrich_marks_db_mixed_and_estimate_sources(db_session):
    from app.models.models import FoodNutrient
    from app.schemas.diet import DietAnalysis, RecognizedFood
    from app.services.nutrition.enrich import enrich_analysis

    bibimbap = db_session.scalar(select(FoodNutrient).where(FoodNutrient.name == "비빔밥"))
    assert bibimbap is not None
    bibimbap.carbs_g, bibimbap.protein_g, bibimbap.fat_g = 40.0, 20.0, 8.0
    db_session.commit()

    db_only = DietAnalysis(engine="test", foods=[
        RecognizedFood(name="비빔밥", carbs_g=1.0, protein_g=2.0, fat_g=3.0),
    ])
    enrich_analysis(db_session, db_only)
    assert db_only.foods[0].source == "db"
    assert (db_only.foods[0].carbs_g, db_only.foods[0].protein_g, db_only.foods[0].fat_g) == (
        40.0, 20.0, 8.0,
    )

    bibimbap.protein_g = None
    db_session.commit()
    mixed = DietAnalysis(engine="test", foods=[
        RecognizedFood(name="비빔밥", carbs_g=1.0, protein_g=2.0, fat_g=3.0),
        RecognizedFood(name="없는음식", carbs_g=4.0, protein_g=5.0, fat_g=6.0),
    ])
    enrich_analysis(db_session, mixed)
    assert mixed.foods[0].source == "mixed"
    assert mixed.foods[0].protein_g == 2.0
    assert mixed.foods[1].source == "estimate"

    no_recognizer_fallback = DietAnalysis(engine="test", foods=[
        RecognizedFood(name="비빔밥", carbs_g=1.0, protein_g=None, fat_g=3.0),
    ])
    enrich_analysis(db_session, no_recognizer_fallback)
    assert no_recognizer_fallback.foods[0].source == "db"
    assert no_recognizer_fallback.foods[0].protein_g is None

    bibimbap.protein_g = 20.0
    db_session.commit()


def test_delete_entry_removes_from_today(client):
    # diet 테스트는 데모 사용자를 공유하므로(무인증) 전역 합계 대신
    # 이 엔트리 id 의 유무로 검증한다.
    entry_id = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch"},
    ).json()["entry_id"]

    before = client.get("/v1/diet/days/today").json()["entries"]
    assert any(e["id"] == entry_id for e in before)

    d = client.delete(f"/v1/diet/entries/{entry_id}")
    assert d.status_code == 200, d.text
    assert d.json()["status"] == "deleted"

    after = client.get("/v1/diet/days/today").json()["entries"]
    assert all(e["id"] != entry_id for e in after)


def test_delete_entry_404_when_missing(client):
    r = client.delete("/v1/diet/entries/diet-nope")
    assert r.status_code == 404


def test_update_entry_changes_meal_type(client):
    entry_id = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch"},
    ).json()["entry_id"]

    r = client.put(
        f"/v1/diet/entries/{entry_id}",
        json={"meal_type": "dinner", "time_label": "19:30"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["meal_type"] == "dinner"
    assert r.json()["time_label"] == "19:30"

    # 공유 데모 사용자라 전역 합계 대신 id 로 확인.
    today = client.get("/v1/diet/days/today").json()["entries"]
    mine = next(e for e in today if e["id"] == entry_id)
    assert mine["meal_type"] == "dinner"


def test_update_entry_changes_nutrition_and_today_totals(client, db_session):
    from app.services.diet_service import today_str as _today_str
    from app.db.init_db import DEMO_USER_ID
    from app.models.models import DietEntry

    db_session.execute(
        delete(DietEntry).where(
            DietEntry.user_id == DEMO_USER_ID,
            DietEntry.date == _today_str(),
        )
    )
    db_session.commit()
    entry_id = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch"},
    ).json()["entry_id"]

    # Legacy per-food macro keys are ignored; meal-level DietEntry macros stay authoritative.
    row = db_session.get(DietEntry, entry_id)
    assert row is not None
    row.foods_json = json.dumps([{
        "name": "legacy food", "calories": 100, "sodium_mg": 10, "sugar_g": 2,
        "source": "estimate", "carbs_g": 99, "protein_g": 99, "fat_g": 99,
    }])
    db_session.commit()

    r = client.put(
        f"/v1/diet/entries/{entry_id}",
        json={
            "total_calories": 333,
            "carbs_g": 25.0,
            "protein_g": 12.5,
            "fat_g": 5.0,
            "sodium_mg": 444,
            "sugar_g": 7,
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["total_calories"] == 333
    assert r.json()["sodium_mg"] == 444
    assert r.json()["sugar_g"] == 7
    assert (r.json()["carbs_g"], r.json()["protein_g"], r.json()["fat_g"]) == (
        25.0, 12.5, 5.0,
    )
    assert not {"carbs_g", "protein_g", "fat_g"} & r.json()["foods"][0].keys()

    today = client.get("/v1/diet/days/today").json()
    assert today["total_calories"] == 333
    assert today["total_sodium_mg"] == 444
    assert today["total_sugar_g"] == 7
    assert today["macros"] == {
        "carbs_g": 25.0,
        "protein_g": 12.5,
        "fat_g": 5.0,
        "carbs_pct": 51,
        "protein_pct": 26,
        "fat_pct": 23,
    }

    zeroed = client.put(
        f"/v1/diet/entries/{entry_id}",
        json={"carbs_g": 0, "protein_g": 0, "fat_g": 0},
    )
    assert zeroed.status_code == 200
    assert client.get("/v1/diet/days/today").json()["macros"] == {
        "carbs_g": 0.0,
        "protein_g": 0.0,
        "fat_g": 0.0,
        "carbs_pct": 0,
        "protein_pct": 0,
        "fat_pct": 0,
    }


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("total_calories", -1),
        ("sodium_mg", -1),
        ("sugar_g", -1),
        ("carbs_g", -0.1),
        ("protein_g", -0.1),
        ("fat_g", -0.1),
    ],
)
def test_update_entry_rejects_negative_nutrition(client, field, value):
    entry_id = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch"},
    ).json()["entry_id"]

    r = client.put(f"/v1/diet/entries/{entry_id}", json={field: value})
    assert r.status_code == 422


def test_update_entry_hides_other_users_record(client, db_session):
    from app.services.diet_service import today_str as _today_str
    from app.models.models import DietEntry, User

    suffix = uuid.uuid4().hex[:12]
    other_user_id = f"diet-owner-{suffix}"
    other_entry_id = f"diet-other-{suffix}"
    db_session.add(User(
        id=other_user_id,
        email=f"{other_user_id}@example.com",
        name="Other User",
        hashed_password="",
    ))
    db_session.flush()
    db_session.add(DietEntry(
        id=other_entry_id,
        user_id=other_user_id,
        date=_today_str(),
        meal_type="lunch",
    ))
    db_session.commit()

    r = client.put(f"/v1/diet/entries/{other_entry_id}", json={"carbs_g": 10})
    assert r.status_code == 404


def test_update_entry_404_when_missing(client):
    r = client.put("/v1/diet/entries/diet-nope", json={"meal_type": "dinner"})
    assert r.status_code == 404


def test_update_entry_keeps_fractional_sugar(client, db_session):
    """#296 회귀: 항목 당류가 Integer 라 소수가 절삭·거부되던 문제.

    프론트는 항목 당류를 double 로 다루고 음식 단위(food_nutrients.sugar_g)도
    이미 Float 이었는데, 항목 단위만 Integer 로 남아 `sugar_g=8.5` 가 실서버
    경로에서 깨졌다.
    """
    from app.services.diet_service import today_str as _today_str
    from app.db.init_db import DEMO_USER_ID
    from app.models.models import DietEntry

    db_session.execute(
        delete(DietEntry).where(
            DietEntry.user_id == DEMO_USER_ID,
            DietEntry.date == _today_str(),
        )
    )
    db_session.commit()
    entry_id = client.post(
        "/v1/diet/analyze",
        files={"image": ("food.jpg", _JPEG, "image/jpeg")},
        data={"meal_type": "lunch"},
    ).json()["entry_id"]

    r = client.put(f"/v1/diet/entries/{entry_id}", json={"sugar_g": 8.5})
    assert r.status_code == 200, r.text
    # 예전엔 Pydantic int 검증에서 422 로 거부되거나 8 로 절삭됐다.
    assert r.json()["sugar_g"] == 8.5

    # DB 컬럼도 소수를 보존해야 한다(왕복 후 재조회).
    db_session.expire_all()
    assert db_session.get(DietEntry, entry_id).sugar_g == 8.5
    assert client.get("/v1/diet/days/today").json()["total_sugar_g"] == 8.5


def test_fractional_sugar_sums_without_truncation(client, db_session):
    """#296 회귀: 6.3 + 8.5 가 14 나 15 가 아니라 14.8 이어야 한다."""
    from app.services.diet_service import today_str as _today_str
    from app.db.init_db import DEMO_USER_ID
    from app.models.models import DietEntry

    db_session.execute(
        delete(DietEntry).where(
            DietEntry.user_id == DEMO_USER_ID,
            DietEntry.date == _today_str(),
        )
    )
    db_session.commit()
    for meal, sugar in (("lunch", 6.3), ("dinner", 8.5)):
        entry_id = client.post(
            "/v1/diet/analyze",
            files={"image": ("food.jpg", _JPEG, "image/jpeg")},
            data={"meal_type": meal},
        ).json()["entry_id"]
        assert client.put(
            f"/v1/diet/entries/{entry_id}", json={"sugar_g": sugar}
        ).status_code == 200

    assert client.get("/v1/diet/days/today").json()["total_sugar_g"] == pytest.approx(14.8)

    # 홈 지표 카드도 같은 소수를 봐야 한다(반올림 18 로 굳으면 회귀).
    summary = client.get("/v1/dashboard/summary").json()
    sugar = next(i for i in summary["indicators"] if i["label"] == "당류")
    assert sugar["current"] == pytest.approx(14.8)


def test_entry_update_rejects_non_finite_sugar():
    """float 로 넓힌 뒤 NaN/inf 가 새어 들어오지 않는지."""
    from app.schemas.diet_api import DietEntryUpdate

    for value in (math.nan, math.inf, -math.inf):
        with pytest.raises(ValidationError):
            DietEntryUpdate(sugar_g=value)
