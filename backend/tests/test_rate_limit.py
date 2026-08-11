"""인증 엔드포인트 rate limit.

fastapi 가 필요하므로 로컬(venv, fastapi 미설치)에서는 이 모듈을 통째로 skip 하고,
CI(전체 의존성)에서 실행한다. 엔드포인트 테스트는 추가로 DB(client)가 필요하다.
"""
from __future__ import annotations

from uuid import uuid4

import pytest

pytest.importorskip("fastapi")


def test_rate_limiter_unit_blocks_over_limit():
    from fastapi import HTTPException

    from app.core.rate_limit import RateLimiter

    rl = RateLimiter()
    for _ in range(3):
        rl.check("k", 3, 60.0)  # 3회 허용
    with pytest.raises(HTTPException):
        rl.check("k", 3, 60.0)  # 4회째 429
    rl.clear()
    rl.check("k", 3, 60.0)  # clear 후 다시 허용


def test_register_is_rate_limited(client):
    # 기본 한도 10/분 → 11번째 요청은 429 (per-test 로 limiter 초기화됨)
    last = None
    for _ in range(11):
        last = client.post(
            "/v1/auth/register",
            json={"email": f"rl-{uuid4().hex[:10]}@oncare.com", "password": "pw!", "name": "u"},
        )
    assert last.status_code == 429, last.text
    assert "Retry-After" in last.headers


def test_routine_options_is_rate_limited(client, monkeypatch):
    """LLM 을 부르는 루틴 생성도 한도를 넘기면 429 (#582).

    한도가 없으면 슬라이더·강도·메모를 바꿔 가며 "생성"을 연타하는 UI 특성상
    그대로 공급자 비용이 된다. 생성이 규칙형으로 폴백해도 호출 비용은 이미 나간
    뒤라, 가드는 엔드포인트 앞단에 있어야 한다.
    """
    from app.core.config import get_settings
    from app.services import trainer_routine_options_service

    # 실제 LLM 을 부르지 않는다 — 여기서 보는 것은 한도이지 생성 품질이 아니다.
    monkeypatch.setattr(
        trainer_routine_options_service,
        "get_coach_llm",
        lambda *a, **k: (_ for _ in ()).throw(RuntimeError("provider off")),
    )

    token = client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    ).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    member_id = client.get("/v1/trainer/clients", headers=headers).json()[0]["id"]

    limit = get_settings().routine_options_per_minute
    last = None
    for _ in range(limit + 1):
        last = client.post(
            f"/v1/trainer/clients/{member_id}/routine-options",
            headers=headers,
            json={"available_minutes": 30},
        )

    assert last.status_code == 429, last.text
    assert "Retry-After" in last.headers


def test_routine_options_limit_is_lower_than_coach_chat():
    """루틴 생성 한도가 채팅보다 낮게 유지되는지 고정한다 (#582).

    같은 LLM 비용에 회원 분석 쿼리가 더 얹히고 연타가 쉬운 UI 라, 채팅과 같거나
    더 높은 값으로 되돌아가면 가드의 의미가 옅어진다.
    """
    from app.core.config import get_settings

    settings = get_settings()
    assert settings.routine_options_per_minute < settings.coach_chat_per_minute
