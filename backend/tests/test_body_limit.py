"""요청 본문 크기 제한 미들웨어 (413).

DB 가 필요 없다 — 본문이 라우터에 닿기 전에 잘리는지가 요점이라, 최소 앱 위에서
미들웨어만 세워 검증한다.
"""
from __future__ import annotations

from typing import Iterator

import pytest
from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

from app.core.body_limit import RequestBodySizeLimitMiddleware

_LIMIT = 1024


@pytest.fixture
def entered() -> list[str]:
    """핸들러 진입/본문 읽기 완료를 기록한다."""
    return []


@pytest.fixture
def client(entered: list[str]) -> Iterator[TestClient]:
    app = FastAPI()
    app.add_middleware(RequestBodySizeLimitMiddleware, max_bytes=_LIMIT)

    # /diet/analyze 와 같은 모양 — 핸들러가 본문을 실제로 메모리에 올린다.
    @app.post("/upload")
    async def upload(request: Request) -> dict[str, int]:
        entered.append("handler")
        body = await request.body()
        entered.append("read")
        return {"len": len(body)}

    with TestClient(app) as c:
        yield c


def test_under_the_limit_passes_through(client: TestClient, entered: list[str]):
    r = client.post("/upload", content=b"x" * (_LIMIT - 1))

    assert r.status_code == 200
    assert r.json() == {"len": _LIMIT - 1}
    assert entered == ["handler", "read"]


def test_exactly_at_the_limit_is_allowed(client: TestClient):
    # 상한은 '초과' 기준이다. 경계값이 억울하게 막히면 안 된다.
    r = client.post("/upload", content=b"x" * _LIMIT)

    assert r.status_code == 200


def test_declared_content_length_over_the_limit_is_rejected_before_routing(
    client: TestClient, entered: list[str]
):
    r = client.post("/upload", content=b"x" * (_LIMIT + 1))

    assert r.status_code == 413
    assert "detail" in r.json()
    # 핸들러에 닿지도 않아야 한다 — 본문을 메모리에 올린 뒤 재는 것이면
    # 막으려던 적재가 그대로 일어나 미들웨어를 둔 의미가 없다.
    assert entered == []


def test_chunked_body_without_content_length_is_still_rejected(
    client: TestClient, entered: list[str]
):
    # httpx 는 제너레이터 본문을 Transfer-Encoding: chunked 로 보낸다 →
    # Content-Length 가 없다. 헤더만 믿으면 이 경로로 상한이 통째로 우회된다.
    def chunks() -> Iterator[bytes]:
        for _ in range(4):
            yield b"y" * 512

    r = client.post("/upload", content=chunks())

    assert r.status_code == 413
    # 헤더가 없으니 핸들러에는 들어가지만, 본문을 다 읽기 전에 끊긴다.
    assert "read" not in entered


def test_unparseable_content_length_falls_back_to_counting(
    client: TestClient, entered: list[str]
):
    r = client.post(
        "/upload",
        content=b"z" * (_LIMIT + 1),
        headers={"Content-Length": "not-a-number"},
    )

    assert r.status_code == 413
    assert "read" not in entered
