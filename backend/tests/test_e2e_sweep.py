"""AI 루틴 E2E 스윕의 응답 계약 판정."""
from __future__ import annotations

import pytest

from scripts import e2e_sweep


class _RoutineApi:
    def __init__(self, options: dict) -> None:
        self.options = options

    def post(self, path: str, **kwargs):
        if path.endswith("/routine-options"):
            return 200, self.options
        if path.endswith("/routines"):
            return 201, {"id": "routine-1"}
        raise AssertionError(f"unexpected POST {path}")

    def get(self, path: str, **kwargs):
        assert path == "/me/coach/routines"
        return 200, [{"name": e2e_sweep._MARKER + " 편집한 루틴"}]

    def delete(self, path: str, **kwargs):
        assert path.endswith("/routines/routine-1")
        return 204, None


def _options(*, total_a=20, recent_messages=None) -> dict:
    return {
        "plan_a": {
            "key": "A",
            "total_minutes": total_a,
            "exercises": [{"name": "걷기", "minutes": 20, "type": "유산소"}],
        },
        "plan_b": {
            "key": "B",
            "total_minutes": 40,
            "exercises": [{"name": "근력", "minutes": 40, "type": "근력"}],
        },
        "analysis": {"recent_messages": recent_messages},
        "generated_by": "rule",
    }


def _run(options: dict) -> dict[str, e2e_sweep.Result]:
    results: list[e2e_sweep.Result] = []
    e2e_sweep.scenario_ai_routine(
        _RoutineApi(options), "member-token", "trainer-token", results
    )
    return {result.name: result for result in results}


@pytest.mark.parametrize("invalid_total", [None, "20", True, 41])
def test_available_time_rejects_missing_or_invalid_totals(invalid_total):
    result = _run(
        _options(
            total_a=invalid_total,
            recent_messages=["회원: " + e2e_sweep._MARKER],
        )
    )["가능 시간 상한"]

    assert result.status == "FAIL"
    assert repr(invalid_total) in result.detail


def test_available_time_accepts_integer_totals_at_or_below_the_limit():
    result = _run(
        _options(recent_messages=["회원: " + e2e_sweep._MARKER])
    )["가능 시간 상한"]

    assert result.status == "PASS"


@pytest.mark.parametrize("recent", [None, [], ["회원: 이전 실행 메시지"]])
def test_chat_evidence_requires_the_current_run_marker(recent):
    result = _run(_options(recent_messages=recent))["채팅 근거 반영(#580)"]

    assert result.status == "FAIL"


def test_chat_evidence_accepts_the_current_run_marker():
    recent = ["회원: 무릎이 아파요 " + e2e_sweep._MARKER]

    result = _run(_options(recent_messages=recent))["채팅 근거 반영(#580)"]

    assert result.status == "PASS"
