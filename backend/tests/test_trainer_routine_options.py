"""Trainer routine-options endpoint and LLM fallback contract."""
from __future__ import annotations

import threading
import time
from concurrent.futures import TimeoutError as FutureTimeout
from dataclasses import dataclass

import pytest
from pydantic import ValidationError

from app.schemas.trainer_api import (
    RoutineOptionAnalysisOut,
    RoutineOptionExerciseOut,
    RoutineOptionsRequest,
)
from app.core import metrics
from app.services import trainer_routine_options_service
from app.services.coach.llm import DEFAULT_THINKING_BUDGET

#: 계약을 만족하는 LLM 응답. 여러 테스트가 같은 페이로드를 쓴다.
_VALID_LLM_JSON = """
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
        #: 마지막 호출에 넘어온 생성 옵션. 사고 예산이 빠지면 상시 폴백으로
        #: 떨어지므로(#579) 테스트가 이 값을 직접 확인한다.
        self.last_kwargs: dict[str, object] = {}

    def generate(
        self, system_prompt: str, user_prompt: str, **kwargs: object
    ) -> _Result:
        assert "member_analysis" in user_prompt
        assert "JSON" in system_prompt
        self.last_kwargs = kwargs
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
    monkeypatch.setattr(
        trainer_routine_options_service,
        "get_coach_llm",
        lambda: _FakeLlm(_VALID_LLM_JSON),
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


def test_llm_is_called_with_json_mode_and_thinking_budget(monkeypatch):
    """루틴 생성이 사고 예산과 json_mode 를 **함께** 넘긴다 (#579).

    이 옵션이 빠지면 `gemini-flash-latest` 는 짧은 JSON 하나에도 10초 이상 걸려
    (실측 10.9~12.8초) 클라이언트가 먼저 끊고, 트레이너는 AI 결과 대신 규칙형만
    보게 된다. 옵션을 주면 4.0~6.4초로 떨어진다.

    json_mode 만 켜면 오히려 크게 느려지므로 둘을 함께 확인한다.
    """
    fake = _FakeLlm(_VALID_LLM_JSON)
    monkeypatch.setattr(
        trainer_routine_options_service, "get_coach_llm", lambda: fake
    )

    result = trainer_routine_options_service._generate_with_llm(
        _analysis(),
        RoutineOptionsRequest(
            available_minutes=30, intensity_preference="moderate", trainer_note=""
        ),
    )

    assert result.generated_by == "ai"
    assert fake.last_kwargs.get("json_mode") is True
    assert fake.last_kwargs.get("thinking_budget") == DEFAULT_THINKING_BUDGET
    assert fake.last_kwargs["thinking_budget"], "budget=0 은 모델이 400 으로 거부한다"


def test_routine_and_diet_paths_share_one_thinking_budget():
    """두 LLM 경로가 같은 상수를 본다 — 한쪽만 누락되는 것이 #579 의 원인이었다."""
    from app.services import diet_recommendation_service

    assert diet_recommendation_service.LLM_THINKING_BUDGET == DEFAULT_THINKING_BUDGET
    assert (
        trainer_routine_options_service.LLM_THINKING_BUDGET
        == DEFAULT_THINKING_BUDGET
    )


# ---- LLM 타임아웃·동시성 가드 (#584) ----
#
# 이 절의 테스트는 모두 `_call_llm` 을 직접 부른다. 엔드포인트를 거치면 느린
# LLM 을 흉내내는 동안 DB 세션까지 물고 있어야 해서, 정작 검증하려는 성질
# (요청 스레드가 언제 풀려나는가)이 다른 대기에 묻힌다.


class _BlockingLlm:
    """호출부가 풀어 줄 때까지 응답하지 않는 LLM — 죽지도 않고 답도 없는 상태."""

    def __init__(self) -> None:
        self.released = threading.Event()
        self.entered = threading.Event()

    def generate(self, system_prompt: str, user_prompt: str, **kwargs: object):
        self.entered.set()
        self.released.wait(timeout=30)
        return _Result(_VALID_LLM_JSON)


@pytest.fixture
def blocking_llm(monkeypatch):
    """응답하지 않는 LLM 을 물리고, 테스트가 끝나면 반드시 풀어 준다.

    풀어 주지 않으면 워커가 남은 채 다음 테스트로 넘어가 뒤에서 엉뚱한 포화가 난다.
    """
    fake = _BlockingLlm()
    monkeypatch.setattr(
        trainer_routine_options_service, "get_coach_llm", lambda: fake
    )
    try:
        yield fake
    finally:
        fake.released.set()


def test_unresponsive_llm_gives_up_within_the_timeout(monkeypatch, blocking_llm):
    """응답하지 않는 LLM 에서도 요청이 정해진 시간 안에 끝난다 (#584).

    이 가드가 없으면 끊어 주는 건 SDK 의 HTTP 타임아웃뿐이라 Gemini 30초,
    OpenAI/LiteLLM 60초 동안 워커 하나가 통째로 묶인다.
    """
    monkeypatch.setattr(trainer_routine_options_service, "LLM_TIMEOUT_SEC", 0.3)

    started = time.monotonic()
    with pytest.raises(FutureTimeout):
        trainer_routine_options_service._call_llm("prompt")
    elapsed = time.monotonic() - started

    assert blocking_llm.entered.is_set(), "LLM 을 부르지도 않아 타임아웃이 검증되지 않았다"
    # 상한을 **설정값 기준**으로 잡는다. 고정 상수로 두면 타임아웃이 그 아래
    # 아무 값으로 회귀해도(예: 설정을 무시하고 4초) 테스트가 그대로 통과한다.
    # 여유 2초는 CI 러너에서 스레드가 뜨는 시간 몫이다.
    limit = trainer_routine_options_service.LLM_TIMEOUT_SEC + 2.0
    assert elapsed < limit, f"타임아웃이 걸리지 않았다({elapsed:.1f}s > {limit:.1f}s)"


def test_saturated_pool_falls_back_without_waiting(monkeypatch, blocking_llm):
    """빈 자리가 없으면 큐에서 기다리지 않고 즉시 포화로 알린다 (#584).

    기다려 봐야 타임아웃인데 그동안 요청 스레드만 붙잡힌다.
    """
    monkeypatch.setattr(
        trainer_routine_options_service, "_llm_slots", threading.BoundedSemaphore(1)
    )
    trainer_routine_options_service._llm_slots.acquire()  # 유일한 자리를 미리 점유

    started = time.monotonic()
    with pytest.raises(trainer_routine_options_service.LLMBusyError):
        trainer_routine_options_service._call_llm("prompt")
    elapsed = time.monotonic() - started

    assert elapsed < trainer_routine_options_service.LLM_TIMEOUT_SEC
    assert not blocking_llm.entered.is_set(), "포화 상태인데 LLM 을 불렀다"


def test_concurrent_requests_do_not_exhaust_the_worker_pool(monkeypatch, blocking_llm):
    """동시 요청이 한도를 넘겨도 초과분은 큐에 쌓이지 않고 곧장 폴백으로 내려간다.

    쌓이게 두면 워커가 전부 묶인 뒤 새 요청이 LLM 을 불러 보지도 못한 채 큐에서
    타임아웃까지 기다린다 — 규칙형만 나오면서 응답만 느려지는 최악의 조합이다.
    """
    limit = 2
    monkeypatch.setattr(
        trainer_routine_options_service,
        "_llm_slots",
        threading.BoundedSemaphore(limit),
    )
    monkeypatch.setattr(trainer_routine_options_service, "LLM_TIMEOUT_SEC", 0.3)

    outcomes: list[str] = []
    lock = threading.Lock()

    def _attempt() -> None:
        try:
            trainer_routine_options_service._call_llm("prompt")
            result = "ok"
        except trainer_routine_options_service.LLMBusyError:
            result = "busy"
        except FutureTimeout:
            result = "timeout"
        with lock:
            outcomes.append(result)

    threads = [threading.Thread(target=_attempt) for _ in range(6)]
    started = time.monotonic()
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=10)
    elapsed = time.monotonic() - started

    assert not any(t.is_alive() for t in threads), "요청 스레드가 풀려나지 못했다"
    assert len(outcomes) == 6
    # 자리를 잡은 쪽은 타임아웃까지 가고, 초과분은 기다리지 않고 즉시 포화로 끝난다.
    assert outcomes.count("busy") == 6 - limit
    assert outcomes.count("timeout") == limit
    # 초과분이 큐에서 순서를 기다렸다면 타임아웃이 직렬로 누적됐을 것이다.
    assert elapsed < 5.0, f"초과 요청이 큐에서 기다렸다({elapsed:.1f}s)"


def test_slots_are_returned_after_a_timeout(monkeypatch, blocking_llm):
    """타임아웃으로 호출부가 떠난 뒤에도 작업이 끝나면 자리를 돌려준다.

    `future.result(timeout=...)` 은 기다리기를 포기할 뿐 작업을 취소하지 않는다.
    돌려주지 않으면 타임아웃 한 번마다 동시성 한도가 영구히 1씩 줄어, 결국 모든
    요청이 포화로 떨어진다.
    """
    slots = threading.BoundedSemaphore(1)
    monkeypatch.setattr(trainer_routine_options_service, "_llm_slots", slots)
    monkeypatch.setattr(trainer_routine_options_service, "LLM_TIMEOUT_SEC", 0.3)

    with pytest.raises(FutureTimeout):
        trainer_routine_options_service._call_llm("prompt")

    blocking_llm.released.set()  # 버려진 작업을 끝내 준다
    assert slots.acquire(timeout=5), "타임아웃 뒤 자리가 반환되지 않았다"


@pytest.mark.parametrize(
    ("failure", "reason"),
    [
        (lambda: trainer_routine_options_service.LLMBusyError("포화"), "busy"),
        (lambda: FutureTimeout(), "timeout"),
    ],
)
def test_guard_failures_return_a_rule_fallback_and_are_counted_apart(
    client, monkeypatch, failure, reason,
):
    """포화·타임아웃도 200 + 규칙 폴백으로 끝나고, 사유는 따로 센다 (#584).

    사유를 나누는 이유는 대응이 다르기 때문이다 — `busy` 는 동시성 한도를,
    `timeout` 은 공급자·모델 옵션을, `contract` 은 프롬프트를 보라는 신호다.
    한 칸에 몰아 세면 이 셋이 지표에서 구분되지 않는다.
    """
    def _raise(*args, **kwargs):
        raise failure()

    monkeypatch.setattr(
        trainer_routine_options_service, "_generate_with_llm", _raise
    )
    token = _trainer_token(client)
    member_id = _first_client_id(client, token)
    metrics.reset()

    response = client.post(
        f"/v1/trainer/clients/{member_id}/routine-options",
        headers=_headers(token),
        json={"available_minutes": 40, "intensity_preference": "high"},
    )

    assert response.status_code == 200, response.text
    assert response.json()["generated_by"] == "rule"

    counters = metrics.snapshot()["counters"]
    assert counters[f"routine_options.fallback{{reason={reason}}}"] == 1
    assert counters["routine_options.generated{by=rule}"] == 1
    other_reasons = [
        k for k in counters
        if k.startswith("routine_options.fallback")
        and k != f"routine_options.fallback{{reason={reason}}}"
    ]
    assert not other_reasons, f"사유가 섞였다: {other_reasons}"


def test_slot_is_returned_to_the_semaphore_it_was_taken_from(monkeypatch, blocking_llm):
    """워커는 자리를 딴 그 인스턴스에 돌려준다 — 전역이 바뀌어도.

    워커가 `_llm_slots` 전역을 다시 읽으면, 그 사이 전역이 교체됐을 때 잡지도 않은
    세마포어를 풀어 준다. 원래 자리는 영영 안 돌아오고, 교체된 쪽은 초기값을 넘겨
    `BoundedSemaphore` 가 ValueError 를 던진다.
    """
    original = threading.BoundedSemaphore(1)
    replacement = threading.BoundedSemaphore(1)
    monkeypatch.setattr(trainer_routine_options_service, "_llm_slots", original)
    monkeypatch.setattr(trainer_routine_options_service, "LLM_TIMEOUT_SEC", 0.3)

    with pytest.raises(FutureTimeout):
        trainer_routine_options_service._call_llm("prompt")

    # 호출부가 떠난 뒤 전역이 갈린다. 아직 워커는 블로킹 중이다.
    monkeypatch.setattr(trainer_routine_options_service, "_llm_slots", replacement)
    blocking_llm.released.set()

    assert original.acquire(timeout=5), "자리를 딴 세마포어에 돌려주지 않았다"
    # 교체본은 건드리지 않았어야 한다. 건드렸다면 초과 release 로 이미 깨졌다.
    assert replacement.acquire(blocking=False), "엉뚱한 세마포어를 풀어 줬다"


def test_slot_is_returned_when_scheduling_fails(monkeypatch):
    """`submit()` 이 실패하면 워커가 돌지 않으므로 자리를 여기서 돌려줘야 한다.

    돌려주지 않으면 실패 한 번마다 동시 호출 한도가 영구히 1씩 줄어, 끝내 모든
    요청이 포화로 떨어진다.
    """
    slots = threading.BoundedSemaphore(1)
    monkeypatch.setattr(trainer_routine_options_service, "_llm_slots", slots)

    class _DeadExecutor:
        def submit(self, fn):
            raise RuntimeError("cannot schedule new futures after shutdown")

    monkeypatch.setattr(trainer_routine_options_service, "_executor", _DeadExecutor())

    with pytest.raises(RuntimeError):
        trainer_routine_options_service._call_llm("prompt")

    assert slots.acquire(blocking=False), "스케줄링 실패로 자리가 누수됐다"
