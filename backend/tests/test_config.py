"""설정(Settings) 검증 — DB 불필요."""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.core.config import DEFAULT_JWT_SECRET, Settings


def test_dev_defaults():
    s = Settings(_env_file=None)
    assert s.env == "dev"
    assert s.is_prod is False
    assert s.auto_create_tables is True
    assert s.api_v1_prefix == "/v1"


def test_prod_blocks_default_secret():
    """운영에서 기본 JWT_SECRET 을 쓰면 기동이 막혀야 한다(fail-fast)."""
    with pytest.raises(ValidationError):
        Settings(_env_file=None, env="prod", jwt_secret=DEFAULT_JWT_SECRET)


def test_prod_ok_with_real_secret():
    s = Settings(
        _env_file=None, env="prod",
        jwt_secret="a-strong-random-secret-value",
        cors_allow_origins="https://app.oncare.com",
        seed_demo_data=False,  # 운영 권장: 데모 시드 끔(켜려면 DEMO_LOGIN_PASSWORD 강제)
    )
    assert s.is_prod is True


def test_demo_fallback_gated_by_env():
    # 개발: 기본 허용
    assert Settings(_env_file=None).demo_fallback_enabled is True
    # 운영: 설정과 무관하게 비활성
    prod = Settings(
        _env_file=None, env="prod", jwt_secret="strong",
        cors_allow_origins="https://app.oncare.com", allow_demo_fallback=True,
        seed_demo_data=False,
    )
    assert prod.demo_fallback_enabled is False
    # 명시적으로 끄면 개발에서도 비활성
    assert Settings(_env_file=None, allow_demo_fallback=False).demo_fallback_enabled is False
