"""업로드 요청 본문 크기 제한 미들웨어 (413).

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
_PROTECTED = "/v1/diet/analyze"
_UNPROTECTED = "/v1/coach-docs"


@pytest.fixture
def entered() -> list[str]:
    """핸들러 진입/본문 읽기 완료를 기록한다."""
    return []


@pytest.fixture
def client(entered: list[str]) -> Iterator[TestClient]:
    """보호 경로와 비보호 경로를 하나씩 가진 최소 앱."""
    app = FastAPI()
    app.add_middleware(
        RequestBodySizeLimitMiddleware,
        max_bytes=_LIMIT,
        protected_paths=(_PROTECTED,),
    )

    # /diet/analyze 와 같은 모양 — 핸들러가 본문을 실제로 메모리에 올린다.
    async def _handle(request: Request) -> dict[str, int]:
        entered.append("handler")
        body = await request.body()
        entered.append("read")
        return {"len": len(body)}

    app.post(_PROTECTED)(_handle)
    app.post(_UNPROTECTED)(_handle)

    with TestClient(app) as c:
        yield c


def test_under_the_limit_passes_through(client: TestClient, entered: list[str]):
    """상한 이하 업로드는 기존과 똑같이 처리된다."""
    r = client.post(_PROTECTED, content=b"x" * (_LIMIT - 1))

    assert r.status_code == 200
    assert r.json() == {"len": _LIMIT - 1}
    assert entered == ["handler", "read"]


def test_exactly_at_the_limit_is_allowed(client: TestClient):
    """상한은 '초과' 기준 — 경계값이 억울하게 막히면 안 된다."""
    r = client.post(_PROTECTED, content=b"x" * _LIMIT)

    assert r.status_code == 200


def test_declared_content_length_over_the_limit_is_rejected_before_routing(
    client: TestClient, entered: list[str]
):
    """Content-Length 만으로 초과가 확정되면 본문을 읽기 전에 끊는다."""
    r = client.post(_PROTECTED, content=b"x" * (_LIMIT + 1))

    assert r.status_code == 413
    assert "detail" in r.json()
    # 핸들러에 닿지도 않아야 한다 — 본문을 메모리에 올린 뒤 재는 것이면
    # 막으려던 적재가 그대로 일어나 미들웨어를 둔 의미가 없다.
    assert entered == []


def test_chunked_body_without_content_length_is_still_rejected(
    client: TestClient, entered: list[str]
):
    """Content-Length 가 없어도 누적 크기로 막는다."""
    # httpx 는 제너레이터 본문을 Transfer-Encoding: chunked 로 보낸다 →
    # Content-Length 가 없다. 헤더만 믿으면 이 경로로 상한이 통째로 우회된다.
    def chunks() -> Iterator[bytes]:
        for _ in range(4):
            yield b"y" * 512

    r = client.post(_PROTECTED, content=chunks())

    assert r.status_code == 413
    # 헤더 검사에서 걸린 게 아니라 **누적 검사**로 막혔음을 확인한다.
    # 핸들러까지는 들어가고, 본문을 다 읽기 전에 끊긴다.
    assert entered == ["handler"]


def test_unparseable_content_length_falls_back_to_counting(
    client: TestClient, entered: list[str]
):
    """신뢰할 수 없는 헤더는 무시하고 누적 검사로 넘긴다."""
    r = client.post(
        _PROTECTED,
        content=b"z" * (_LIMIT + 1),
        headers={"Content-Length": "not-a-number"},
    )

    assert r.status_code == 413
    assert entered == ["handler"]


def test_other_paths_keep_their_existing_behaviour(
    client: TestClient, entered: list[str]
):
    """보호 경로가 아니면 상한을 넘겨도 그대로 통과한다.

    이 상한은 업로드를 겨냥한 값이라, 대량 텍스트를 JSON 본문으로 받는
    엔드포인트(coach-docs 문서 적재 등)까지 묶으면 기능을 자른다.
    """
    oversized = b"x" * (_LIMIT * 4)

    r = client.post(_UNPROTECTED, content=oversized)

    assert r.status_code == 200
    assert r.json() == {"len": len(oversized)}
    assert entered == ["handler", "read"]
