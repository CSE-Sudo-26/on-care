"""AI 루틴 A/B 생성 — 순수 규칙형 로직 + 엔드포인트(소유권/역할/검증/폴백)."""
from __future__ import annotations

from uuid import uuid4
import pytest
from pydantic import ValidationError

from app.services import routine_ai
from app.schemas.trainer_api import RoutineOptionsOut


def _trainer_token(client) -> str:
    return client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]


def _member_token(client) -> str:
    email = f"member-{uuid4().hex[:8]}@oncare.com"
    client.post("/v1/auth/register", json={"email": email, "password": "pw!", "name": "u"})
    return client.post(
        "/v1/auth/login", data={"username": email, "password": "pw!"}
    ).json()["access_token"]


# ---- pure rule-based generator (no DB) ----

def test_rule_based_plans_differ_and_respect_available_minutes():
    a, b = routine_ai.rule_based_plans(
        goal="체중 감량",
        sodium_today_mg=1800,
        avg_completion_rate=70,
        available_minutes=40,
        intensity_preference="moderate",
        trainer_note="",
    )
    assert a["key"] == "A" and b["key"] == "B"
    # A(회복)는 B(강도)보다 짧고 낮은 강도.
    assert a["total_minutes"] < b["total_minutes"]
    assert a["intensity"] == "낮음"
    # 각 계획의 운동 시간 합 == total_minutes, 모든 타입 허용값.
    for plan in (a, b):
        assert sum(e["minutes"] for e in plan["exercises"]) == plan["total_minutes"]
        assert all(e["type"] in {"유산소", "근력", "스트레칭"} for e in plan["exercises"])
        assert all(e["minutes"] >= 1 for e in plan["exercises"])


@pytest.mark.parametrize("minutes", [10, 180])
def test_rule_based_plans_never_exceed_requested_time(minutes):
    a, b = routine_ai.rule_based_plans(
        goal="체중 감량",
        sodium_today_mg=1800,
        avg_completion_rate=50,
        available_minutes=minutes,
        intensity_preference="low",
        trainer_note="",
    )
    assert a["total_minutes"] <= minutes
    assert b["total_minutes"] <= minutes
    assert sum(e["minutes"] for e in a["exercises"]) == a["total_minutes"]
    assert sum(e["minutes"] for e in b["exercises"]) == b["total_minutes"]


def test_options_schema_rejects_a_total_that_does_not_match_exercises():
    plan = {
        "key": "A",
        "label": "회복",
        "total_minutes": 20,
        "intensity": "낮음",
        "exercises": [{"name": "걷기", "minutes": 10, "type": "유산소"}],
        "reason": "이유",
        "rationale": "근거",
    }
    with pytest.raises(ValidationError):
        RoutineOptionsOut.model_validate(
            {
                "analysis": {
                    "goal": "체중 감량",
                    "sodium_today_mg": 1000,
                    "sodium_over_target": False,
                    "avg_completion_rate": 50,
                    "latest_routine": "-",
                    "note": "",
                },
                "plan_a": plan,
                "plan_b": {**plan, "key": "B"},
                "generated_by": "rule",
            }
        )


def test_rule_based_rationale_cites_member_numbers_and_over_target():
    a, b = routine_ai.rule_based_plans(
        goal="혈압 관리",
        sodium_today_mg=2400,  # over 2000 target
        avg_completion_rate=40,
        available_minutes=30,
        intensity_preference="low",
        trainer_note="무릎 부담 낮게",
    )
    assert "2400mg" in a["rationale"] and "목표 초과" in a["rationale"]
    assert "40%" in a["rationale"]
    assert "무릎 부담 낮게" in a["rationale"]  # trainer note reflected
    # low preference is preserved in the generated plan.
    assert b["intensity"] == "낮음"


def test_maybe_llm_plans_returns_none_so_service_falls_back_to_rules():
    assert routine_ai.maybe_llm_plans(
        goal="", sodium_today_mg=0, avg_completion_rate=0,
        available_minutes=30, intensity_preference="moderate", trainer_note="",
    ) is None


# ---- endpoint (DB) ----

def _first_client_id(client, token: str) -> str | None:
    r = client.get("/v1/trainer/clients", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200, r.text
    roster = r.json()
    return roster[0]["id"] if roster else None


def test_routine_options_generates_ab_for_owned_member(client):
    token = _trainer_token(client)
    member_id = _first_client_id(client, token)
    assert member_id, "demo trainer should own at least one seeded client"

    r = client.post(
        f"/v1/trainer/clients/{member_id}/routine-options",
        headers={"Authorization": f"Bearer {token}"},
        json={"available_minutes": 40, "intensity_preference": "moderate", "trainer_note": "테스트"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["generated_by"] == "rule"
    assert body["plan_a"]["key"] == "A" and body["plan_b"]["key"] == "B"
    assert body["plan_a"]["total_minutes"] < body["plan_b"]["total_minutes"]
    assert body["plan_a"]["exercises"], "plan A must have exercises"
    # analysis reflects the member + echoes the trainer note.
    assert body["analysis"]["note"] == "테스트"
    assert isinstance(body["analysis"]["sodium_over_target"], bool)


@pytest.mark.parametrize(
    "llm_result",
    [RuntimeError("provider unavailable"), ({"key": "A"}, {"key": "B"})],
)
def test_routine_options_falls_back_when_llm_fails_or_is_malformed(
    client, monkeypatch, llm_result
):
    token = _trainer_token(client)
    member_id = _first_client_id(client, token)
    assert member_id

    def fake_llm(**_kwargs):
        if isinstance(llm_result, Exception):
            raise llm_result
        return llm_result

    monkeypatch.setattr(routine_ai, "maybe_llm_plans", fake_llm)
    response = client.post(
        f"/v1/trainer/clients/{member_id}/routine-options",
        headers={"Authorization": f"Bearer {token}"},
        json={"available_minutes": 30},
    )

    assert response.status_code == 200, response.text
    assert response.json()["generated_by"] == "rule"


def test_routine_options_rejects_a_member_not_owned_by_this_trainer(client):
    token = _trainer_token(client)
    r = client.post(
        "/v1/trainer/clients/not-my-member/routine-options",
        headers={"Authorization": f"Bearer {token}"},
        json={"available_minutes": 30},
    )
    assert r.status_code == 404


def test_routine_options_forbidden_for_a_member_account(client):
    token = _member_token(client)
    r = client.post(
        "/v1/trainer/clients/anyone/routine-options",
        headers={"Authorization": f"Bearer {token}"},
        json={"available_minutes": 30},
    )
    assert r.status_code == 403


def test_routine_options_validates_available_minutes(client):
    token = _trainer_token(client)
    member_id = _first_client_id(client, token) or "x"
    r = client.post(
        f"/v1/trainer/clients/{member_id}/routine-options",
        headers={"Authorization": f"Bearer {token}"},
        json={"available_minutes": 9},  # below the ge=10 bound
    )
    assert r.status_code == 422
