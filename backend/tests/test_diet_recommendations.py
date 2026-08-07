"""홈 AI 추천 식단(GET /diet/recommendations).

핵심 계약 세 가지를 고정한다:
1. 어떤 경우에도 카드 수가 줄지 않는다(화면이 흔들리면 안 된다).
2. 근거가 없으면 결과가 정확히 현재 홈 화면 순서(DEFAULT_ORDER)다.
3. 나트륨 과다 같은 신호가 있으면 그에 맞는 요리가 앞으로 온다.

LLM 은 붙이지 않고(=use_llm=False 또는 monkeypatch) 결정론적으로 검증한다. 실 Gemini
호출은 CI 에 키가 없어 재현이 안 되고, 여기서 보려는 건 LLM 품질이 아니라 계약이다.
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest
from sqlalchemy import delete

from app.data.meal_catalog import CATALOG, DEFAULT_ORDER, RECOMMENDATION_COUNT
from app.services import diet_recommendation_service as svc


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def member_token(client) -> str:
    """로그인 가능한 시드 회원.

    user-demo(minsu)는 hashed_password 가 빈 값이라 로그인 계정이 아니다(데모 폴백
    전용 신원). 시드가 비밀번호까지 만들어 주는 회원을 쓴다.
    """
    return client.post(
        "/v1/auth/login", data={"username": "sungho@oncare.com", "password": "oncare123"}
    ).json()["access_token"]


@pytest.fixture(autouse=True)
def _clear_cache():
    svc.clear_cache()
    yield
    svc.clear_cache()


# ─────────────────────────────────────────────────────── 순수 로직(DB 불필요) ──


def test_catalog_keys_are_unique_and_default_order_matches_catalog():
    keys = [i.key for i in CATALOG]
    assert len(keys) == len(set(keys))
    assert DEFAULT_ORDER == tuple(keys)
    assert RECOMMENDATION_COUNT == len(keys)


def test_rule_rank_without_signals_is_exactly_current_home_order():
    """근거가 없으면 지금 화면 그대로여야 한다 — 목업/신규 가입자 경로."""
    ctx = svc.NutritionContext(
        days_with_data=0, avg_sodium_mg=0, avg_sugar_g=0.0, avg_calories=0,
        avg_protein_g=0.0, sodium_limit_mg=2000, sugar_limit_g=50,
        calorie_limit=2000, conditions="", goals="", signals=(),
    )
    assert [i.key for i in svc._rule_rank(ctx)] == list(DEFAULT_ORDER)


def test_rule_rank_puts_low_sodium_dishes_first_when_sodium_is_high():
    ctx = svc.NutritionContext(
        days_with_data=3, avg_sodium_mg=2600, avg_sugar_g=10.0, avg_calories=1500,
        avg_protein_g=60.0, sodium_limit_mg=2000, sugar_limit_g=50,
        calorie_limit=2000, conditions="고혈압", goals="", signals=("sodium_high",),
    )
    ranked = [i.key for i in svc._rule_rank(ctx)]
    # good_for 에 sodium_high 가 있는 두 요리가 상위로 올라온다.
    assert set(ranked[:2]) == {"chicken_salad", "salmon"}
    assert len(ranked) == RECOMMENDATION_COUNT


def test_parse_llm_items_drops_hallucinated_keys_and_backfills():
    """카탈로그 밖 요리를 지어내도 버리고, 부족분은 규칙 순서로 채운다."""
    ctx = svc.NutritionContext(
        days_with_data=3, avg_sodium_mg=2600, avg_sugar_g=10.0, avg_calories=1500,
        avg_protein_g=60.0, sodium_limit_mg=2000, sugar_limit_g=50,
        calorie_limit=2000, conditions="", goals="", signals=("sodium_high",),
    )
    raw = """```json
    {"items": [
      {"key": "truffle_pasta", "reason_key": "sodium", "reason_text": "지어낸 요리"},
      {"key": "salmon", "reason_key": "omega", "reason_text": "나트륨 2,600mg"},
      {"key": "salmon", "reason_key": "omega"}
    ]}
    ```"""
    items = svc._parse_llm_items(raw, ctx)
    keys = [i.key for i in items]

    assert "truffle_pasta" not in keys           # 카탈로그 밖 → 폐기
    assert keys[0] == "salmon"                   # 유효한 선택은 순서 유지
    assert len(keys) == len(set(keys))           # 중복 제거
    assert len(keys) == RECOMMENDATION_COUNT     # 폴백으로 5장 채움
    assert items[0].reason_text == "나트륨 2,600mg"


def test_parse_llm_items_rejects_unusable_output():
    ctx = svc.NutritionContext(
        days_with_data=1, avg_sodium_mg=2600, avg_sugar_g=0.0, avg_calories=0,
        avg_protein_g=0.0, sodium_limit_mg=2000, sugar_limit_g=50,
        calorie_limit=2000, conditions="", goals="", signals=("sodium_high",),
    )
    with pytest.raises(Exception):
        svc._parse_llm_items('{"items": [{"key": "nope"}]}', ctx)
    with pytest.raises(Exception):
        svc._parse_llm_items("not json at all", ctx)


def test_reason_key_always_comes_from_catalog_not_the_llm():
    """LLM 이 이유 코드를 골라도 무시한다.

    실측에서 LLM 은 순서는 잘 잡으면서 reason_key 를 본문과 어긋나게 골랐다.
    reason_key 는 reason_text 가 없을 때 화면에 뜨는 값이라 틀리면 오답이 보인다.
    """
    ctx = svc.NutritionContext(
        days_with_data=1, avg_sodium_mg=2600, avg_sugar_g=0.0, avg_calories=0,
        avg_protein_g=0.0, sodium_limit_mg=2000, sugar_limit_g=50,
        calorie_limit=2000, conditions="", goals="", signals=("sodium_high",),
    )
    # 유효한 다른 코드를 줘도, 지어낸 코드를 줘도 결과는 카탈로그 기본값이다.
    for supplied in ("fiber", "made_up_reason"):
        items = svc._parse_llm_items(
            '{"items": [{"key": "tofu", "reason_key": "%s"}]}' % supplied, ctx
        )
        assert items[0].key == "tofu"
        assert items[0].reason_key == "low_cal"


# ─────────────────────────────────────────────────────────── 엔드포인트(DB) ──


def test_endpoint_follows_the_shared_demo_fallback(client):
    """개발/스테이징에선 토큰 없이도 데모 사용자로 폴백한다(deps.get_current_user).

    이 엔드포인트만 다르게 굴지 않는다는 걸 고정한다. 운영(is_prod)에서는
    demo_fallback_enabled 가 꺼져 401 이 되며, 그 경계는 test_security 가 다룬다.
    """
    res = client.get("/v1/diet/recommendations?use_llm=false")
    assert res.status_code == 200
    assert len(res.json()["items"]) == RECOMMENDATION_COUNT


def test_endpoint_always_returns_full_card_set(client, member_token):
    res = client.get("/v1/diet/recommendations?use_llm=false", headers=_h(member_token))
    assert res.status_code == 200
    body = res.json()
    assert len(body["items"]) == RECOMMENDATION_COUNT
    assert all(i["key"] in DEFAULT_ORDER for i in body["items"])
    assert all(i["reason_key"] for i in body["items"])


def test_user_without_diet_history_gets_current_home_order(client, db_session):
    """신규 가입자 — 실 모드여도 화면이 지금과 같아야 한다."""
    from app.models.models import User
    from app.core.security import hash_password

    email = f"rec-empty-{uuid.uuid4().hex[:8]}@example.com"
    user = User(
        id=f"user-{uuid.uuid4().hex[:12]}", email=email, name="추천 테스트",
        hashed_password=hash_password("pw!"), role="member",
    )
    db_session.add(user)
    db_session.commit()
    try:
        token = client.post(
            "/v1/auth/login", data={"username": email, "password": "pw!"}
        ).json()["access_token"]
        body = client.get(
            "/v1/diet/recommendations?use_llm=false", headers=_h(token)
        ).json()

        assert [i["key"] for i in body["items"]] == list(DEFAULT_ORDER)
        assert body["personalized"] is False
        assert body["basis"] is None
    finally:
        db_session.execute(delete(User).where(User.id == user.id))
        db_session.commit()


def test_high_sodium_history_surfaces_low_sodium_recommendation(client, db_session):
    """#275 수용 기준: 나트륨 과다 → 저염 추천이 근거와 함께 드러난다."""
    from app.models.models import DietEntry, User
    from app.core.security import hash_password

    email = f"rec-sodium-{uuid.uuid4().hex[:8]}@example.com"
    user = User(
        id=f"user-{uuid.uuid4().hex[:12]}", email=email, name="나트륨 과다",
        hashed_password=hash_password("pw!"), role="member",
    )
    db_session.add(user)
    db_session.commit()

    # 나트륨 신호만 뜨도록 나머지는 평범한 하루로 맞춘다. 칼로리를 너무 낮게 넣으면
    # calorie_low 신호가 같이 떠서 다른 요리가 끼어든다(그건 그것대로 옳은 동작).
    today = date.today()
    for offset in range(svc.LOOKBACK_DAYS):
        day = (today - timedelta(days=offset)).isoformat()
        for meal, cal, sodium in (
            ("breakfast", 450, 800), ("lunch", 700, 1100), ("dinner", 650, 950)
        ):
            db_session.add(
                DietEntry(
                    id=f"diet-{uuid.uuid4().hex[:12]}", user_id=user.id, date=day,
                    meal_type=meal, foods_json="[]", total_calories=cal,
                    sodium_mg=sodium, sugar_g=5.0, protein_g=25.0,
                )
            )
    db_session.commit()

    try:
        token = client.post(
            "/v1/auth/login", data={"username": email, "password": "pw!"}
        ).json()["access_token"]
        body = client.get(
            "/v1/diet/recommendations?use_llm=false", headers=_h(token)
        ).json()

        keys = [i["key"] for i in body["items"]]
        assert set(keys[:2]) == {"chicken_salad", "salmon"}
        assert body["personalized"] is True
        assert body["basis"] and "2,850mg" in body["basis"]  # 하루 합 800+1100+950
        assert "초과" in body["basis"]
        assert len(keys) == RECOMMENDATION_COUNT
    finally:
        db_session.execute(delete(DietEntry).where(DietEntry.user_id == user.id))
        db_session.execute(delete(User).where(User.id == user.id))
        db_session.commit()


def test_llm_failure_degrades_to_rule_recommendations(client, member_token, monkeypatch):
    """LLM 이 죽어도 화면은 그대로 뜬다 — graceful degrade."""
    def _boom(ctx):
        raise RuntimeError("Gemini down")

    monkeypatch.setattr(svc, "_llm_items", _boom)
    res = client.get("/v1/diet/recommendations", headers=_h(member_token))

    assert res.status_code == 200
    body = res.json()
    assert len(body["items"]) == RECOMMENDATION_COUNT
    assert body["source"] in {"rules", "fallback"}
