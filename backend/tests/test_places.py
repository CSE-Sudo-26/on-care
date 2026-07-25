"""장소(O2O) — 카카오 실검색 + 시드 폴백(#255).

- docs_to_places 파싱 / _use_kakao 해석은 순수(로컬 실행).
- 엔드포인트(폴백·카카오 경로)는 DB 필요(로컬 skip, CI 실행).
"""
from __future__ import annotations


def test_kakao_docs_to_places_parsing():
    from app.services.places.kakao import docs_to_places

    docs = [
        {
            "id": "1", "place_name": "온케어짐", "x": "127.0", "y": "37.5",
            "distance": "120", "road_address_name": "서울 서대문구 신촌로 120",
        },
        {"id": "2", "place_name": "좌표없음"},  # x/y 없음 → 스킵
        {"id": "3", "place_name": "거리없음", "x": "127.1", "y": "37.6"},  # distance 없음 → 0
    ]
    out = docs_to_places(docs, "fitness")
    assert len(out) == 2
    assert out[0].name == "온케어짐"
    assert out[0].category == "fitness"
    assert out[0].distance_meters == 120
    assert out[0].lat == 37.5 and out[0].lng == 127.0
    assert out[1].distance_meters == 0


def test_use_kakao_resolution():
    from app.api.v1.places import _use_kakao
    from app.core.config import Settings

    seed_forced = Settings(_env_file=None, places_provider="seed", kakao_rest_api_key="k")
    kakao_forced = Settings(_env_file=None, places_provider="kakao")
    auto_with_key = Settings(_env_file=None, places_provider="auto", kakao_rest_api_key="k")
    auto_no_key = Settings(_env_file=None, places_provider="auto", kakao_rest_api_key="")
    assert _use_kakao(seed_forced) is False
    assert _use_kakao(kakao_forced) is True
    assert _use_kakao(auto_with_key) is True
    assert _use_kakao(auto_no_key) is False


def test_places_fallback_to_seed_without_key(client):
    # 기본 설정(키 없음, auto) → 시드 폴백
    r = client.get("/v1/places/nearby")
    assert r.status_code == 200, r.text
    data = r.json()
    assert len(data) >= 1
    assert all("category" in p and "distance_meters" in p for p in data)
    # 거리순 정렬
    dists = [p["distance_meters"] for p in data]
    assert dists == sorted(dists)


def test_places_category_filter_seed(client):
    r = client.get("/v1/places/nearby", params={"category": "fitness"})
    assert r.status_code == 200, r.text
    assert all(p["category"] == "fitness" for p in r.json())


def test_places_uses_kakao_when_configured(client, monkeypatch):
    """카카오 경로: search_nearby 를 가짜로 대체해 네트워크 없이 검증."""
    import app.api.v1.places as places_mod
    from app.core.config import get_settings
    from app.schemas.misc_api import PlaceOut

    async def fake_search(lat, lng, category, radius_m, api_key, timeout):
        assert api_key == "test-key"
        return [PlaceOut(
            id="kk1", name="카카오헬스장", category=category or "",
            address="서울 어딘가", distance_meters=50, lat=lat, lng=lng,
        )]

    monkeypatch.setattr(places_mod.kakao, "search_nearby", fake_search)
    s = get_settings()
    monkeypatch.setattr(s, "kakao_rest_api_key", "test-key")
    monkeypatch.setattr(s, "places_provider", "kakao")

    r = client.get("/v1/places/nearby", params={"category": "fitness", "lat": 37.5, "lng": 127.0})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body[0]["id"] == "kk1"
    assert body[0]["name"] == "카카오헬스장"


def test_places_falls_back_when_kakao_raises(client, monkeypatch):
    """카카오 호출이 실패해도 요청은 시드로 폴백해 성공한다."""
    import app.api.v1.places as places_mod
    from app.core.config import get_settings

    async def boom(*a, **k):
        raise RuntimeError("kakao down")

    monkeypatch.setattr(places_mod.kakao, "search_nearby", boom)
    s = get_settings()
    monkeypatch.setattr(s, "kakao_rest_api_key", "test-key")
    monkeypatch.setattr(s, "places_provider", "kakao")

    r = client.get("/v1/places/nearby")
    assert r.status_code == 200, r.text  # 폴백으로 200
