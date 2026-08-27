"""응답하지 않는 임베딩 provider 가 DB 잠금까지 묶지 않는다 (#1545).

개인 RAG 문서 교체는 기록 하나를 직렬화하려고 advisory transaction lock 을 잡은
**뒤에** 임베딩 API 를 부른다. 그 호출에 상한이 없으면 provider 지연이 요청 하나로
끝나지 않는다 — 잠금과 connection 이 함께 묶여, 같은 기록의 후속 갱신이 줄줄이
쌓이고 pool 이 마른다. 여기서 두 가지를 고정한다.

1. 임베딩 client 에 유한한 timeout 이 걸려 있다.
2. 임베딩이 실패하면 트랜잭션이 끝나 잠금·connection 이 돌아가고, 기존 문서는
   그대로 남는다.
"""
from __future__ import annotations

import pytest
from sqlalchemy import select
from sqlalchemy import text as sa_text

from app.models.models import CoachDocument
from app.services.coach import rag

_USER = "user-7d4e9a2c5f18"
_REF = "ref-embed-timeout"


class _HangingEmbedder:
    """timeout 으로 끊긴 provider — client 가 예외를 올려 주는 모습 그대로."""

    dim = 768

    def embed(self, texts: list[str]) -> list[list[float]]:
        raise TimeoutError("embedding provider did not respond")

    def embed_one(self, text: str) -> list[float]:
        return self.embed([text])[0]


def _docs(db_session) -> list[CoachDocument]:
    return list(
        db_session.scalars(
            select(CoachDocument).where(CoachDocument.source_ref == _REF)
        ).all()
    )


def _advisory_lock_is_free(db_session, key: str) -> bool:
    """다른 connection 이 같은 잠금을 바로 잡을 수 있는가."""
    engine = db_session.get_bind()
    with engine.connect() as conn:
        taken = conn.execute(
            sa_text("SELECT pg_try_advisory_xact_lock(hashtext(:key))"), {"key": key}
        ).scalar()
        conn.rollback()
    return bool(taken)


@pytest.fixture
def existing_doc(client, db_session):
    """교체 대상이 이미 적재되어 있는 상태."""
    rag.purge_personal(db_session, _USER, _REF)
    rag.ingest_personal_text(
        db_session, _USER, "2026-08-20 운동 — 걷기 30분", domain="exercise",
        source="exercise", source_ref=_REF,
    )
    assert _docs(db_session)
    yield
    rag.purge_personal(db_session, _USER, _REF)


def test_replace_keeps_documents_and_releases_lock_on_timeout(
    db_session, existing_doc, monkeypatch
):
    """임베딩이 응답하지 않으면 아무것도 지우지 않고 잠금을 즉시 돌려준다."""
    monkeypatch.setattr(rag, "get_embedder", lambda: _HangingEmbedder())

    with pytest.raises(TimeoutError):
        rag.replace_personal_text(
            db_session, _USER, domain="exercise", source="exercise",
            source_ref=_REF, load_text=lambda: "2026-08-20 운동 — 걷기 45분",
        )

    # 트랜잭션이 끝나야 advisory lock 과 connection 이 돌아간다. (조회를 먼저 하면
    # 세션이 새 트랜잭션을 열어 이 판정이 무의미해지므로 순서를 지킨다.)
    assert not db_session.in_transaction()
    assert _advisory_lock_is_free(db_session, f"coach_doc:{_USER}:{_REF}")
    # 교체는 삭제보다 임베딩을 먼저 한다 — 실패해도 기존 근거가 남아야 코치가
    # 근거 없는 상태로 떨어지지 않는다.
    assert _docs(db_session)


def test_ensure_releases_lock_on_timeout(client, db_session, monkeypatch):
    """최초 적재(ensure) 경로도 같은 보장을 받는다."""
    ref = "ref-embed-timeout-ensure"
    rag.purge_personal(db_session, _USER, ref)
    monkeypatch.setattr(rag, "get_embedder", lambda: _HangingEmbedder())

    with pytest.raises(TimeoutError):
        rag.ensure_personal_text(
            db_session, _USER, "2026-08-21 운동 — 달리기 20분", domain="exercise",
            source="exercise", source_ref=ref,
        )

    assert not db_session.in_transaction()
    assert _advisory_lock_is_free(db_session, f"coach_doc:{_USER}:{ref}")


def test_gemini_embedder_applies_configured_timeout(monkeypatch):
    """임베딩 client 에도 챗·인식과 같은 설정값의 timeout 이 걸린다."""
    from google import genai

    from app.services.embedder import gemini_embedder

    captured: dict = {}

    class _FakeClient:
        def __init__(self, **kwargs):
            captured.update(kwargs)

    monkeypatch.setattr(genai, "Client", _FakeClient)

    class _Settings:
        gemini_api_key = "test-key"
        gemini_timeout_seconds = 12.5
        embed_dim = 768

    monkeypatch.setattr(gemini_embedder, "get_settings", lambda: _Settings())

    embedder = gemini_embedder.GeminiEmbedder()

    assert embedder.dim == 768
    http_options = captured["http_options"]
    assert http_options.timeout == 12_500  # SDK 는 밀리초
