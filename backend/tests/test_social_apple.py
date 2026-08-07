"""Apple 로그인 검증 (#330).

Apple 은 토큰을 확인해 주는 조회 엔드포인트가 없어 서버가 JWT 를 직접 검증한다.
검증이 한 군데라도 비면 우회가 생기므로, **뚫리는 경우가 실제로 막히는지**를 본다:
만료·aud 불일치·iss 위조·서명 위조·alg 강등(none).

테스트용 RSA 키쌍을 만들어 JWKS 를 대신하므로 네트워크가 필요 없다(CI 에 Apple
자격증명이 없고, 있더라도 실제 Apple 토큰은 재현할 수 없다).
"""
from __future__ import annotations

import asyncio
import threading
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from app.services.social import apple as apple_mod
from app.services.social.apple import AppleVerifier
from app.services.social.base import SocialAuthError

_KID = "test-key-1"


@pytest.fixture(scope="module")
def keypair():
    """서명용 개인키와 검증용 공개키."""
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private, private.public_key()


@pytest.fixture(autouse=True)
def _apple_client_ids(monkeypatch):
    """허용 aud 를 고정한다(설정 파일·환경에 의존하지 않도록)."""
    monkeypatch.setattr(
        apple_mod, "_allowed_audiences", lambda: ["com.oncare.app", "com.oncare.web"]
    )


@pytest.fixture(autouse=True)
def _stub_jwks(monkeypatch, keypair):
    """JWKS 조회를 테스트 공개키로 대체 — 네트워크를 타지 않는다.

    조회가 **어느 스레드에서 실행됐는지**도 기록한다. 이벤트 루프를 막지 않는지
    검증하는 데 쓴다.
    """
    _, public = keypair

    class _Key:
        key = public

    class _Client:
        called_on: list[int] = []

        def get_signing_key_from_jwt(self, token):  # noqa: ANN001
            _Client.called_on.append(threading.get_ident())
            return _Key()

    _Client.called_on = []
    monkeypatch.setattr(apple_mod, "_jwk_client", lambda: _Client())
    return _Client


def _token(keypair, **overrides) -> str:
    private, _ = keypair
    now = datetime.now(tz=timezone.utc)
    claims = {
        "iss": apple_mod.APPLE_ISSUER,
        "aud": "com.oncare.app",
        "sub": "001234.abcdef.5678",
        "email": "user@privaterelay.appleid.com",
        "iat": now,
        "exp": now + timedelta(minutes=10),
    }
    claims.update(overrides)
    return jwt.encode(claims, private, algorithm="RS256", headers={"kid": _KID})


def _verify(token: str):
    """검증 실행.

    이 저장소엔 pytest-asyncio 가 없고 async 테스트도 이것뿐이라, 의존성을 늘리는
    대신 코루틴을 직접 돌린다.
    """
    return asyncio.run(AppleVerifier().verify(token))


def test_valid_token_returns_identity(keypair):
    identity = _verify(_token(keypair))

    assert identity.provider == "apple"
    assert identity.provider_user_id == "001234.abcdef.5678"
    assert identity.email == "user@privaterelay.appleid.com"
    # Apple 은 이름을 토큰에 담지 않는다(최초 로그인 때 클라이언트가 따로 받는다).
    assert identity.name == ""


def test_web_audience_is_also_accepted(keypair):
    """iOS 는 번들 ID, 웹은 Service ID 로 서로 다른 aud 를 받는다."""
    identity = _verify(_token(keypair, aud="com.oncare.web"))
    assert identity.provider_user_id


def test_token_for_another_app_is_rejected(keypair):
    """aud 를 확인하지 않으면 **다른 앱용 유효한 Apple 토큰**으로 로그인이 뚫린다."""
    with pytest.raises(SocialAuthError):
        _verify(_token(keypair, aud="com.someone-else.app"))


def test_expired_token_is_rejected(keypair):
    past = datetime.now(tz=timezone.utc) - timedelta(hours=1)
    with pytest.raises(SocialAuthError):
        _verify(_token(keypair, exp=past, iat=past - timedelta(minutes=10)))


def test_forged_issuer_is_rejected(keypair):
    with pytest.raises(SocialAuthError):
        _verify(_token(keypair, iss="https://evil.example.com"))


def test_token_signed_by_another_key_is_rejected(keypair):
    """서명 검증이 실제로 도는지 — 남의 키로 서명한 토큰은 통과하면 안 된다."""
    attacker = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    now = datetime.now(tz=timezone.utc)
    forged = jwt.encode(
        {
            "iss": apple_mod.APPLE_ISSUER,
            "aud": "com.oncare.app",
            "sub": "001234.abcdef.5678",
            "iat": now,
            "exp": now + timedelta(minutes=10),
        },
        attacker,
        algorithm="RS256",
        headers={"kid": _KID},
    )
    with pytest.raises(SocialAuthError):
        _verify(forged)


def test_unsigned_token_is_rejected(keypair):
    """alg=none 강등 — 서명 없는 토큰을 받아 주면 아무나 로그인할 수 있다."""
    now = datetime.now(tz=timezone.utc)
    unsigned = jwt.encode(
        {
            "iss": apple_mod.APPLE_ISSUER,
            "aud": "com.oncare.app",
            "sub": "001234.abcdef.5678",
            "iat": now,
            "exp": now + timedelta(minutes=10),
        },
        key="",
        algorithm="none",
    )
    with pytest.raises(SocialAuthError):
        _verify(unsigned)


def test_token_without_sub_is_rejected(keypair):
    with pytest.raises(SocialAuthError):
        _verify(_token(keypair, sub=""))


def test_missing_client_id_config_refuses_instead_of_skipping(
    monkeypatch, keypair
):
    """설정이 없으면 **검증을 건너뛰지 않고 거부**한다.

    다른 provider 는 키가 없으면 폴백하지만 인증은 폴백 대상이 아니다. aud 확인을
    생략하는 순간 다른 앱용 토큰으로 로그인이 뚫린다.
    """
    monkeypatch.setattr(apple_mod, "_allowed_audiences", list)

    with pytest.raises(SocialAuthError):
        _verify(_token(keypair))


# ───────────────────────────────────────────────────────── 엔드포인트(DB) ──


def test_endpoint_no_longer_returns_501(client):
    """`POST /auth/social/apple` 이 더 이상 "미지원(501)"이 아니다.

    이 이슈의 출발점이 501 이었다. 이제 검증을 실제로 수행하므로, 잘못된 토큰은
    다른 provider 와 똑같이 401 로 거절돼야 한다(구현 여부가 응답으로 드러나면
    안 된다).
    """
    res = client.post("/v1/auth/social/apple", json={"token": "not-a-real-token"})

    assert res.status_code != 501
    assert res.status_code == 401


def test_endpoint_rejection_matches_other_providers(client):
    """apple 이 kakao/google 과 같은 형태로 거절되는지 — 응답만 보고 어떤 provider 가
    구현됐는지 알 수 없어야 한다."""
    apple = client.post("/v1/auth/social/apple", json={"token": "bad"})
    google = client.post("/v1/auth/social/google", json={"token": "bad"})

    assert apple.status_code == google.status_code == 401
    assert apple.json()["detail"] == google.json()["detail"]


def test_jwks_lookup_runs_off_the_event_loop(keypair, _stub_jwks):
    """JWKS 조회는 이벤트 루프 밖(다른 스레드)에서 실행돼야 한다.

    PyJWKClient 는 urllib 기반이라 동기 블로킹이다. 캐시가 비었거나 Apple 이 키를
    회전한 직후에는 실제 HTTP 요청이 나가는데, async 핸들러에서 그대로 호출하면
    그동안 이벤트 루프가 멈춰 **무관한 요청까지 함께 지연된다.**
    """
    main_thread = threading.get_ident()

    async def _run():
        await AppleVerifier().verify(_token(keypair))
        return threading.get_ident()

    loop_thread = asyncio.run(_run())

    assert _stub_jwks.called_on, "JWKS 조회가 호출되지 않았다"
    # 코루틴이 도는 스레드와 JWKS 조회가 실행된 스레드가 달라야 한다.
    assert _stub_jwks.called_on[0] != loop_thread
    assert _stub_jwks.called_on[0] != main_thread
