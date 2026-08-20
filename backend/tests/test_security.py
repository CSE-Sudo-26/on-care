"""보안 유틸(비밀번호 해싱 · JWT) 검증 — DB 불필요."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import jwt
import pytest

from app.core.security import (
    _encode,
    create_access_token,
    create_refresh_token,
    decode_access_token,
    decode_refresh_claims,
    hash_password,
    verify_password,
)


def test_password_hash_roundtrip():
    hashed = hash_password("s3cret!")
    assert hashed and hashed != "s3cret!"
    assert verify_password("s3cret!", hashed) is True
    assert verify_password("wrong-password", hashed) is False


def test_verify_empty_hash_is_false():
    assert verify_password("anything", "") is False


def test_jwt_roundtrip():
    token = create_access_token("user-123")
    assert decode_access_token(token) == "user-123"


def test_jwt_invalid_token_raises():
    with pytest.raises(jwt.InvalidTokenError):
        decode_access_token("not-a-valid-token")


def test_refresh_token_roundtrip():
    token = create_refresh_token("user-9")
    assert decode_refresh_claims(token).subject == "user-9"


def test_access_token_rejected_as_refresh():
    """액세스 토큰을 refresh 로 쓰면 거부."""
    with pytest.raises(jwt.InvalidTokenError):
        decode_refresh_claims(create_access_token("user-9"))


def test_refresh_token_rejected_as_access():
    """refresh 토큰을 액세스로 쓰면 거부(토큰 혼용 방지)."""
    with pytest.raises(jwt.InvalidTokenError):
        decode_access_token(create_refresh_token("user-9"))


def test_refresh_token_carries_unique_jti():
    """폐기하려면 토큰마다 이름이 달라야 한다 — 두 장이 같은 jti 면 한쪽을 끊을 때
    다른 쪽까지 끊긴다(#966)."""
    first = decode_refresh_claims(create_refresh_token("user-9"))
    second = decode_refresh_claims(create_refresh_token("user-9"))
    assert first.jti and second.jti
    assert first.jti != second.jti
    assert first.expires_at > datetime.now(timezone.utc)


def test_refresh_token_without_jti_rejected():
    """#966 이전에 발급된 토큰 — 폐기할 이름이 없어 일회용으로 만들 수 없다."""
    legacy = _encode("user-9", "refresh", timedelta(days=1))
    with pytest.raises(jwt.InvalidTokenError):
        decode_refresh_claims(legacy)
