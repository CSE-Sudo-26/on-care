"""
MY 탭 설정 메뉴 서비스.

/users/me/health 의 settings 목록을 제공합니다. (프론트 MY 탭과 동일)
"""
from __future__ import annotations

# 프론트 mock 과 동일한 설정 메뉴
DEMO_SETTINGS = [
    {"label": "내 프로필", "icon": "👤", "kind": "my-profile"},
    {"label": "알림 설정", "icon": "🔔", "kind": "notification"},
    {"label": "고객 지원", "icon": "💬", "kind": "support"},
]
