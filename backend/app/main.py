"""
FastAPI 진입점 (STEP 1: 골격 재구성).

프론트 계약에 맞춰 /v1 prefix 로 라우터를 마운트합니다.
실행: uvicorn app.main:app --reload
문서: http://localhost:8000/docs
"""
from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import (
    ai_coach, coach_docs, dashboard, diet, exercise, member_coach, notifications, places, schedule, social, system, trainer, users, vitals,
)
from app.core.config import get_settings
from app.db.init_db import init_db

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="On-Care Backend",
    description="만성질환(고혈압·당뇨) 위험군 헬스케어 플랫폼 — 프론트 계약 정렬판",
    version=settings.app_version,
    lifespan=lifespan,
)

# HTTPS 강제(운영). 프록시 뒤면 X-Forwarded-Proto 를 신뢰(uvicorn --proxy-headers).
if settings.force_https:
    from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware

    app.add_middleware(HTTPSRedirectMiddleware)

# CORS: 와일드카드('*')면 자격증명(쿠키) 불가 → allow_credentials=False.
# 명시 출처면 자격증명 허용. (앱은 Bearer 토큰이라 와일드카드+무자격증명으로 충분.)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=not settings.is_cors_wildcard,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 보안 응답 헤더(운영/HTTPS 에서는 HSTS 포함).
if settings.security_headers:

    @app.middleware("http")
    async def _security_headers(request: Request, call_next):
        response = await call_next(request)
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "no-referrer")
        if settings.is_prod or settings.force_https:
            response.headers.setdefault(
                "Strict-Transport-Security", "max-age=63072000; includeSubDomains"
            )
        return response

# /v1 prefix 로 마운트 (프론트 base URL 이 /v1 을 포함하는 계약)
app.include_router(system.router, prefix=settings.api_v1_prefix)
app.include_router(users.router, prefix=settings.api_v1_prefix)
app.include_router(social.router, prefix=settings.api_v1_prefix)
app.include_router(dashboard.router, prefix=settings.api_v1_prefix)
app.include_router(diet.router, prefix=settings.api_v1_prefix)
app.include_router(exercise.router, prefix=settings.api_v1_prefix)
app.include_router(vitals.router, prefix=settings.api_v1_prefix)
app.include_router(schedule.router, prefix=settings.api_v1_prefix)
app.include_router(notifications.router, prefix=settings.api_v1_prefix)
app.include_router(places.router, prefix=settings.api_v1_prefix)
app.include_router(ai_coach.router, prefix=settings.api_v1_prefix)
app.include_router(coach_docs.router, prefix=settings.api_v1_prefix)
app.include_router(trainer.router, prefix=settings.api_v1_prefix)
app.include_router(member_coach.router, prefix=settings.api_v1_prefix)
