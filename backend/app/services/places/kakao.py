"""
카카오 Local(장소) 검색 프록시.

카카오 Local REST(키워드 검색)를 서버가 대신 호출해 결과를 PlaceOut 으로 변환한다.
키는 서버(설정/Secrets)에만 두므로 프론트로 노출되지 않고, 응답 형식은 기존 계약
(PlaceOut)과 동일해 프론트는 영향이 없다. 키가 없거나 호출이 실패하면 라우터가
시드 데이터로 폴백한다(recognizer 팩토리의 stub 폴백과 같은 철학).

카테고리→검색어 매핑: 카카오 카테고리 코드는 병원(HP8)·약국(PM9)만 있고 헬스장/건강식은
없으므로, 계약 카테고리 전부를 키워드 검색으로 일관 처리한다.
"""
from __future__ import annotations

import time

import httpx

from app.schemas.misc_api import PlaceOut

_KAKAO_KEYWORD_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"

# 간단한 인메모리 TTL 캐시 — 동일 위치·카테고리 반복 조회 시 카카오 호출을 줄여
# 요청 폭주/요금을 완화한다(운영은 인스턴스별 캐시라 근사적 완화). 좌표는 소수 3자리
# (~110m) 버킷으로 묶는다.
_CACHE_TTL_SECONDS = 60.0
_CACHE_MAX = 500
_cache: dict[tuple, tuple[float, list[PlaceOut]]] = {}


def _cache_key(lat: float, lng: float, category: str | None, radius_m: int) -> tuple:
    return (round(lat, 3), round(lng, 3), category or "", radius_m)

# 계약 카테고리 → 카카오 키워드
_CATEGORY_QUERY = {
    "medical": "병원",
    "fitness": "헬스장",
    "healthy_food": "샐러드",
    "pharmacy": "약국",
}


def _query_for(category: str | None) -> str:
    if not category:
        return "병원"
    return _CATEGORY_QUERY.get(category, category)


def docs_to_places(docs: list[dict], category: str | None) -> list[PlaceOut]:
    """카카오 documents → PlaceOut 목록(좌표 없는 항목은 스킵). 순수 함수(테스트 용이)."""
    out: list[PlaceOut] = []
    for d in docs:
        try:
            lat = float(d["y"])
            lng = float(d["x"])
        except (KeyError, TypeError, ValueError):
            continue
        try:
            dist = int(d.get("distance") or 0)
        except (TypeError, ValueError):
            dist = 0
        out.append(PlaceOut(
            id=str(d.get("id", "")),
            name=d.get("place_name", ""),
            category=category or "",
            address=d.get("road_address_name") or d.get("address_name") or "",
            distance_meters=dist,
            lat=lat,
            lng=lng,
        ))
    return out


async def search_nearby(
    lat: float, lng: float, category: str | None, radius_m: int,
    api_key: str, timeout: float = 3.0,
) -> list[PlaceOut]:
    """카카오 Local 키워드 검색으로 주변 장소를 거리순 조회. 실패 시 예외(라우터가 폴백).
    TTL 캐시 히트 시 호출을 건너뛴다."""
    key = _cache_key(lat, lng, category, radius_m)
    now = time.monotonic()
    hit = _cache.get(key)
    if hit is not None and hit[0] > now:
        return hit[1]

    params = {
        "query": _query_for(category),
        "x": str(lng),      # 카카오는 x=경도, y=위도
        "y": str(lat),
        "radius": min(max(radius_m, 1), 20000),
        "sort": "distance",
        "size": 15,
    }
    headers = {"Authorization": f"KakaoAK {api_key}"}
    async with httpx.AsyncClient(timeout=timeout) as client:
        resp = await client.get(_KAKAO_KEYWORD_URL, params=params, headers=headers)
        resp.raise_for_status()
        docs = resp.json().get("documents", [])
    result = docs_to_places(docs, category)

    if len(_cache) >= _CACHE_MAX:
        _cache.clear()  # 단순 상한 — 무한 증식 방지
    _cache[key] = (now + _CACHE_TTL_SECONDS, result)
    return result
