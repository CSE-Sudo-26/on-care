"""간단한 인메모리 rate limiter (브루트포스 방어).

인증 엔드포인트(로그인/회원가입/refresh/소셜)에 IP·엔드포인트별 슬라이딩 윈도우로
분당 시도 횟수를 제한한다. 단일 인스턴스/데모에 충분하며, 다중 인스턴스 운영에서는
Redis 백엔드로 교체(같은 check() 인터페이스 유지)하면 된다.

RATE_LIMIT_ENABLED=false 로 끌 수 있고, RATE_LIMIT_AUTH_PER_MINUTE 로 한도를 조정한다.
"""
from __future__ import annotations

import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

from app.core.config import get_settings


class RateLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def clear(self) -> None:
        """상태 초기화(테스트 격리용)."""
        self._hits.clear()

    def check(self, key: str, limit: int, window: float) -> None:
        """key 에 대해 window(초) 동안 limit 회 초과 시 429."""
        now = time.monotonic()
        dq = self._hits[key]
        cutoff = now - window
        while dq and dq[0] <= cutoff:
            dq.popleft()
        if len(dq) >= limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.",
                headers={"Retry-After": str(int(window))},
            )
        dq.append(now)


limiter = RateLimiter()


def rate_limit(bucket: str, per_minute: int | None = None):
    """엔드포인트에 붙일 의존성 팩토리. bucket 은 엔드포인트 구분자.

    `per_minute` 를 주면 그 한도를, 안 주면 인증용 기본 한도를 쓴다. LLM 호출처럼
    실패해도 비용이 나가는 엔드포인트는 브루트포스 방어와 목적이 달라 한도를 따로
    잡는다.
    """

    def _dep(request: Request) -> None:
        settings = get_settings()
        if not settings.rate_limit_enabled:
            return
        ip = request.client.host if request.client else "unknown"
        limit = per_minute or settings.rate_limit_auth_per_minute
        limiter.check(f"{bucket}:{ip}", limit, 60.0)

    return _dep
