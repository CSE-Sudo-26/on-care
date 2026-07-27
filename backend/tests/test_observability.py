"""관측성 하드닝(#288) — request-id 생성/검증/전달, 전역 500, DB readiness."""
from __future__ import annotations

import re

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core import observability

_HEX32 = re.compile(r"^[0-9a-f]{32}$")


def test_request_id_generated_when_absent(client):
    r = client.get("/v1/healthz")
    rid = r.headers.get("X-Request-ID")
    assert rid and _HEX32.match(rid)  # 헤더 없으면 새 UUID 생성


def test_request_id_passed_through_when_valid(client):
    r = client.get("/v1/healthz", headers={"X-Request-ID": "abc-123_XYZ.v1"})
    assert r.headers.get("X-Request-ID") == "abc-123_XYZ.v1"


def test_request_id_replaced_when_invalid(client):
    # 형식 위반(공백·특수문자) → 신뢰하지 않고 새로 생성(로그 인젝션 방지)
    bad = "bad id; drop table\nX-Injected: 1"
    r = client.get("/v1/healthz", headers={"X-Request-ID": bad})
    rid = r.headers.get("X-Request-ID")
    assert rid != bad and _HEX32.match(rid)
    # 길이 초과(>64)도 거부
    r2 = client.get("/v1/healthz", headers={"X-Request-ID": "a" * 65})
    assert r2.headers.get("X-Request-ID") != "a" * 65


def test_global_500_hides_detail_and_carries_request_id():
    app = FastAPI()
    observability.install(app)

    @app.get("/boom")
    def boom():
        raise RuntimeError("SECRET: db password = hunter2")

    c = TestClient(app, raise_server_exceptions=False)
    r = c.get("/boom", headers={"X-Request-ID": "trace-abc"})
    assert r.status_code == 500
    assert "SECRET" not in r.text and "hunter2" not in r.text  # 내부 상세 미노출
    body = r.json()
    assert body["detail"] == "내부 서버 오류가 발생했습니다."
    assert body["request_id"] == "trace-abc"
    assert r.headers.get("X-Request-ID") == "trace-abc"


def test_readyz_ok(client):
    r = client.get("/v1/readyz")
    assert r.status_code == 200
    assert r.json()["status"] == "ready"


def test_readyz_503_on_db_failure(client):
    """DB 장애 시 /readyz 는 내부 상세를 숨긴 503. (/healthz 는 liveness 라 영향 없음)"""
    from app.db.session import get_db
    from app.main import app

    class _BoomSession:
        def execute(self, *a, **k):
            raise RuntimeError("connection refused to 10.0.0.5:5432")

    def _boom_db():
        yield _BoomSession()

    app.dependency_overrides[get_db] = _boom_db
    try:
        r = client.get("/v1/readyz")
        assert r.status_code == 503
        assert "connection refused" not in r.text  # 원인 미노출
        # liveness 는 DB 와 무관하게 여전히 200
        assert client.get("/v1/healthz").status_code == 200
    finally:
        app.dependency_overrides.pop(get_db, None)
