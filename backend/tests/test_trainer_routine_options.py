"""Trainer routine-options endpoint and LLM fallback contract."""
from __future__ import annotations

from dataclasses import dataclass

import pytest
from pydantic import ValidationError

from app.schemas.trainer_api import (
    RoutineOptionAnalysisOut,
    RoutineOptionExerciseOut,
    RoutineOptionsRequest,
)
from app.services import trainer_routine_options_service


def _trainer_token(client) -> str:
    response = client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _first_client_id(client, token: str) -> str:
    response = client.get("/v1/trainer/clients", headers=_headers(token))
    assert response.status_code == 200, response.text
    return response.json()[0]["id"]


@dataclass
class _Result:
    text: str


class _FakeLlm:
    def __init__(self, text: str) -> None:
        self._text = text

    def generate(self, system_prompt: str, user_prompt: str) -> _Result:
        assert "member_analysis" in user_prompt
        assert "JSON" in system_prompt
        return _Result(self._text)


def _analysis() -> RoutineOptionAnalysisOut:
    return RoutineOptionAnalysisOut(
        goal="체중 감량",
        sodium_today_mg=2200,
        sodium_over_target=True,
        avg_completion_rate=65,
        latest_routine="걷기",
        note="무릎 부담 낮게",
    )


def test_routine_categories_match_the_member_app():
    categories = ("걷기", "유산소", "근력", "요가", "스트레칭", "기타")
    for category in categories:
        exercise = RoutineOptionExerciseOut(
            name="테스트 운동", minutes=10, type=category
        )
        assert exercise.type == category

    with pytest.raises(ValidationError):
        RoutineOptionExerciseOut(name="테스트 운동", minutes=10, type="미지원")


def test_rule_fallback_respects_requested_minutes():
    request = RoutineOptionsRequest(
        available_minutes=40,
        intensity_preference="high",
        trainer_note="무릎 부담 낮게",
    )

    result = trainer_routine_options_service.build_rule_options(
        _analysis(),
        request,
    )

    assert result.generated_by == "rule"
    assert result.plan_a.total_minutes <= 40
    assert result.plan_b.total_minutes == 40
    assert sum(item.minutes for item in result.plan_b.exercises) == 40
    assert "무릎 부담 낮게" in result.plan_b.rationale


def test_public_generator_falls_back_for_malformed_llm(monkeypatch):
    request = RoutineOptionsRequest(available_minutes=30)
    monkeypatch.setattr(
        trainer_routine_options_service,
        "build_member_analysis",
        lambda *_: _analysis(),
    )
    monkeypatch.setattr(
        trainer_routine_options_service,
        "get_coach_llm",
        lambda: _FakeLlm('{"plan_a": {"key": "A"}}'),
    )

    result = trainer_routine_options_service.generate_routine_options(
        object(),
        "trainer",
        "member",
        request,
    )

    assert result.generated_by == "rule"


def test_routine_options_uses_valid_llm_json(client, monkeypatch):
    token = _trainer_token(client)
    member_id = _first_client_id(client, token)
    payload = """
    {
      "plan_a": {
        "key": "A",
        "label": "관절 회복형",
        "total_minutes": 20,
        "intensity": "낮음",
        "exercises": [
          {"name": "저강도 걷기", "minutes": 20, "type": "유산소"}
        ],
        "reason": "부담을 낮춘 구성",
        "rationale": "최근 기록과 메모를 반영"
      },
      "plan_b": {
        "key": "B",
        "label": "근력 강화형",
        "total_minutes": 30,
        "intensity": "보통",
        "exercises": [
          {"name": "스쿼트", "minutes": 15, "type": "근력"},
          {"name": "실내 자전거", "minutes": 15, "type": "유산소"}
        ],
        "reason": "운동량을 높인 구성",
        "rationale": "목표와 완료율을 반영"
      }
    }
    """
    monkeypatch.setattr(
        trainer_routine_options_service,
        "get_coach_llm",
        lambda: _FakeLlm(payload),
    )

    response = client.post(
        f"/v1/trainer/clients/{member_id}/routine-options",
        headers=_headers(token),
        json={
            "available_minutes": 30,
            "intensity_preference": "moderate",
            "trainer_note": "무릎 부담 낮게",
        },
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["generated_by"] == "ai"
    assert body["plan_a"]["label"] == "관절 회복형"
    assert body["plan_b"]["total_minutes"] == 30
    assert body["analysis"]["note"] == "무릎 부담 낮게"


def test_routine_options_falls_back_when_llm_contract_is_invalid(
    client,
    monkeypatch,
):
    token = _trainer_token(client)
    member_id = _first_client_id(client, token)
    monkeypatch.setattr(
        trainer_routine_options_service,
        "get_coach_llm",
        lambda: _FakeLlm('{"plan_a": {"key": "A"}}'),
    )

    response = client.post(
        f"/v1/trainer/clients/{member_id}/routine-options",
        headers=_headers(token),
        json={"available_minutes": 40, "intensity_preference": "high"},
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["generated_by"] == "rule"
    assert body["plan_a"]["total_minutes"] <= 40
    assert body["plan_b"]["total_minutes"] == 40


def test_routine_options_rejects_unowned_member_before_ai_call(
    client,
    monkeypatch,
):
    token = _trainer_token(client)

    def _unexpected_llm():
        raise AssertionError("LLM must not run for an unowned member")

    monkeypatch.setattr(
        trainer_routine_options_service,
        "get_coach_llm",
        _unexpected_llm,
    )
    response = client.post(
        "/v1/trainer/clients/not-owned/routine-options",
        headers=_headers(token),
        json={"available_minutes": 30},
    )

    assert response.status_code == 404
