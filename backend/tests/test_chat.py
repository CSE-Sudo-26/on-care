"""AI 코치 챗봇 (/ai-coach/chat) — DB 필요(로컬 skip, CI 실행).

LLM 을 스텁으로 막아 **검색 기반 폴백 경로**를 결정적으로 검증한다.
막지 않으면 키가 설정된 환경(개발자 로컬)에서는 실제 Gemini 를 호출해
느려지고 비용이 들며, 정작 이 파일이 검증한다고 적어 둔 폴백 경로는
한 번도 실행되지 않는다.
"""
from __future__ import annotations

import pytest

from app.services.coach.llm_base import LLMResult


def _stub_chat_llm(monkeypatch, behaviour):
    """`chat.answer` 가 부르는 `get_coach_llm` 을 갈아끼운다.

    `chat.py` 가 `from ... import get_coach_llm` 으로 이름을 바인딩하므로
    원본 모듈이 아니라 chat 모듈의 이름을 바꿔야 한다.
    """
    from app.services.coach import chat as chat_service

    class _StubLLM:
        def generate(self, system_prompt: str, user_prompt: str) -> LLMResult:
            if isinstance(behaviour, Exception):
                raise behaviour
            return LLMResult(text=behaviour, model="stub")

    monkeypatch.setattr(chat_service, "get_coach_llm", lambda *a, **k: _StubLLM())


@pytest.fixture
def no_llm(monkeypatch):
    """LLM 미설정 환경을 재현 — 검색 기반 폴백이 답한다."""
    _stub_chat_llm(monkeypatch, RuntimeError("LLM 미설정"))


def test_chat_returns_grounded_reply(client, no_llm):
    r = client.post("/v1/ai-coach/chat", json={"message": "나트륨을 줄이려면 어떻게 해야 하나요?"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["reply"].strip()          # 답변이 비어있지 않음
    assert isinstance(body["sources"], list)


def test_chat_accepts_history(client, no_llm):
    r = client.post(
        "/v1/ai-coach/chat",
        json={
            "message": "그럼 운동은 어떻게 할까요?",
            "history": [
                {"role": "user", "content": "혈압이 높아요"},
                {"role": "coach", "content": "저염 식단이 도움이 됩니다."},
            ],
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["reply"].strip()


def test_chat_empty_message_400(client):
    r = client.post("/v1/ai-coach/chat", json={"message": "   "})
    assert r.status_code == 400


def test_chat_uses_llm_reply_when_available(client, monkeypatch):
    """LLM 이 답하면 그 텍스트가 그대로 나간다(폴백 문구가 아니라)."""
    _stub_chat_llm(monkeypatch, "물을 충분히 드시고 국물은 남기세요.")

    r = client.post("/v1/ai-coach/chat", json={"message": "나트륨을 줄이려면?"})
    assert r.status_code == 200, r.text
    assert r.json()["reply"] == "물을 충분히 드시고 국물은 남기세요."


def test_chat_falls_back_when_llm_returns_blank(client, monkeypatch):
    """빈 응답은 답이 아니다 — 검색 기반 폴백으로 넘어가야 한다."""
    _stub_chat_llm(monkeypatch, "   ")

    r = client.post("/v1/ai-coach/chat", json={"message": "나트륨을 줄이려면?"})
    assert r.status_code == 200, r.text
    assert r.json()["reply"].strip()
