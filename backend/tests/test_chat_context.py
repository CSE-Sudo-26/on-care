"""트레이너↔회원 채팅이 AI 근거로 흘러가는 경로 (#580).

두 경로가 있고 서로 다른 방식이라 각각 검증한다:
  * 회원 앱 AI(피드백 카드·챗봇) — personal_ingest 로 개인 RAG 에 적재 → retrieve 가 찾음
  * 트레이너 루틴 생성 — RAG 를 안 쓰므로 chat_messages 를 직접 조회
"""
from __future__ import annotations

import pytest

from app.services import trainer_routine_options_service as options_service
from app.services.coach import personal_ingest, prompt_safety


# ---- 적재 필터 (순수) ----

@pytest.mark.parametrize(
    "text",
    ["네", "넵", "ㅇㅇ", "  ", "감사합니다", "알겠습니다", "확인했어요", "좋아요"],
)
def test_boilerplate_chat_is_not_ingested(text):
    """정형 응답은 임베딩 비용만 쓰고 검색 상위에 잡음으로 올라온다."""
    assert personal_ingest._chat_is_ingestable(text) is False


@pytest.mark.parametrize(
    "text",
    [
        "어제부터 무릎이 아파서 계단 오르기가 힘들어요",
        "요즘 아침에 어지러운 느낌이 있어요",
        "이번 주는 야근이 많아 저녁을 늦게 먹었습니다",
    ],
)
def test_substantive_chat_is_ingested(text):
    assert personal_ingest._chat_is_ingestable(text) is True


def test_ingested_chat_carries_speaker_label(monkeypatch):
    """검색 결과는 content 만 프롬프트로 나가므로 발화자가 본문에 박혀 있어야 한다."""
    captured: list[tuple[str, str, str]] = []
    monkeypatch.setattr(
        personal_ingest,
        "_safe",
        lambda db, user_id, text, *, domain, source, source_ref=None,
        replace=False: captured.append((user_id, text, domain)),
    )

    personal_ingest.record_chat(
        None, "member-1", sender="trainer", text="이번 주는 하체를 빼시죠",
        date="2026-08-10",
    )
    personal_ingest.record_chat(
        None, "member-1", sender="member", text="어제부터 무릎이 아픕니다",
        date="2026-08-10",
    )

    assert [c[0] for c in captured] == ["member-1", "member-1"]
    assert "트레이너: 이번 주는 하체를 빼시죠" in captured[0][1]
    assert "회원: 어제부터 무릎이 아픕니다" in captured[1][1]
    # 무릎 통증 한 마디는 식단 코치와 운동 코치 양쪽에서 검색돼야 한다.
    assert {c[2] for c in captured} == {"general"}


def test_chat_is_owned_by_the_member_even_when_the_trainer_speaks(monkeypatch):
    """회원 앱 AI 코치는 user_id 로만 검색한다 — 소유자가 트레이너면 안 보인다."""
    captured: list[str] = []
    monkeypatch.setattr(
        personal_ingest,
        "_safe",
        lambda db, user_id, text, *, domain, source, source_ref=None,
        replace=False: captured.append(user_id),
    )
    personal_ingest.record_chat(
        None, "member-1", sender="trainer", text="다음 주 강도를 올려 봅시다",
        date="2026-08-10",
    )
    assert captured == ["member-1"]


# ---- 프롬프트 신뢰 경계 (순수) ----

def test_every_chat_consuming_prompt_carries_the_trust_boundary():
    """경로 하나만 빠져도 티가 안 나므로 한꺼번에 확인한다."""
    from app.services.coach import chat as coach_chat
    from app.services.coach import domain_coaches

    guard = prompt_safety.UNTRUSTED_QUOTE_GUARD
    assert guard in options_service._SYSTEM_PROMPT
    assert guard in coach_chat._SYSTEM
    assert guard in domain_coaches._DIET_SYSTEM
    assert guard in domain_coaches._EXERCISE_SYSTEM


def test_routine_prompt_keeps_its_json_contract_after_the_guard():
    """경계 문구를 앞에 붙이면서 JSON 예시가 깨지지 않았는지."""
    prompt = options_service._SYSTEM_PROMPT
    assert '"plan_a"' in prompt
    assert '"plan_b"' in prompt
    assert "total_minutes" in prompt


# ---- 트레이너 루틴 경로: 직접 조회 (DB) ----

def _trainer_token(client) -> str:
    response = client.post(
        "/v1/auth/login",
        data={"username": "trainer@oncare.com", "password": "oncare123"},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_recent_chat_reaches_the_routine_analysis(client):
    """회원이 보낸 통증 호소가 분석에 실려 트레이너에게도 보인다."""
    token = _trainer_token(client)
    member_id = client.get("/v1/trainer/clients", headers=_headers(token)).json()[0]["id"]

    sent = client.post(
        f"/v1/trainer/clients/{member_id}/chat",
        headers=_headers(token),
        json={"text": "이번 주는 무릎에 부담 가는 동작을 빼겠습니다"},
    )
    assert sent.status_code == 201, sent.text

    response = client.post(
        f"/v1/trainer/clients/{member_id}/routine-options",
        headers=_headers(token),
        json={"available_minutes": 30},
    )

    assert response.status_code == 200, response.text
    messages = response.json()["analysis"]["recent_messages"]
    assert any("무릎에 부담" in m for m in messages)
    # 발화자 라벨이 없으면 모델이 트레이너 지시를 회원 증상으로 읽는다.
    assert all(m.startswith(("회원: ", "트레이너: ")) for m in messages)


def test_routine_analysis_never_exceeds_the_message_cap(client):
    token = _trainer_token(client)
    member_id = client.get("/v1/trainer/clients", headers=_headers(token)).json()[0]["id"]

    for i in range(options_service.CHAT_MAX_MESSAGES + 4):
        client.post(
            f"/v1/trainer/clients/{member_id}/chat",
            headers=_headers(token),
            json={"text": f"상한 확인용 메시지 {i} 입니다"},
        )

    response = client.post(
        f"/v1/trainer/clients/{member_id}/routine-options",
        headers=_headers(token),
        json={"available_minutes": 30},
    )

    messages = response.json()["analysis"]["recent_messages"]
    assert len(messages) <= options_service.CHAT_MAX_MESSAGES
    # 잘려 나가야 할 건 오래된 쪽 — 가장 최근 메시지는 반드시 남는다.
    last = options_service.CHAT_MAX_MESSAGES + 3
    assert any(f"메시지 {last} " in m for m in messages)


def test_another_members_chat_never_leaks_into_the_analysis(client):
    """분석은 (trainer_id, member_id) 스레드로만 좁혀져야 한다.

    같은 트레이너의 다른 고객에게 보낸 메시지가 이 고객의 근거로 새면, 트레이너는
    엉뚱한 사람의 통증을 근거로 만든 루틴을 받게 된다.
    """
    token = _trainer_token(client)
    roster = client.get("/v1/trainer/clients", headers=_headers(token)).json()
    if len(roster) < 2:
        pytest.skip("고객이 2명 미만이면 회원 간 격리를 검증할 수 없다.")
    first, second = roster[0]["id"], roster[1]["id"]

    marker = "격리검증용 두번째 고객 메시지입니다"
    sent = client.post(
        f"/v1/trainer/clients/{second}/chat",
        headers=_headers(token),
        json={"text": marker},
    )
    assert sent.status_code == 201, sent.text

    response = client.post(
        f"/v1/trainer/clients/{first}/routine-options",
        headers=_headers(token),
        json={"available_minutes": 30},
    )

    assert response.status_code == 200, response.text
    messages = response.json()["analysis"]["recent_messages"]
    assert all(marker not in line for line in messages)

    # 반대편에서는 보여야 한다 — 위 단언이 "그냥 아무것도 안 실림"으로 통과하지 않도록.
    other = client.post(
        f"/v1/trainer/clients/{second}/routine-options",
        headers=_headers(token),
        json={"available_minutes": 30},
    )
    assert any(marker in line for line in other.json()["analysis"]["recent_messages"])
