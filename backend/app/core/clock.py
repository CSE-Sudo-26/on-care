"""서비스 기준 시각 — 항상 KST(Asia/Seoul).

`datetime.now()` 나 `date.today()`, 인자 없는 `astimezone()` 은 **서버 로컬
타임존**을 따른다. 배포 이미지(`python:3.12-slim`)의 기본 타임존은 UTC 라,
이 호출들을 그대로 쓰면 KST 00:00~09:00 사이에 서비스가 판단하는 "오늘"이
하루 전이 된다 — 아침에 기록한 식사가 전날 식단으로 들어가고, '오늘/어제'
라벨이 밀리고, 오늘 잡힌 세션이 '미래 세션'으로 거부된다(#557).

컨테이너에 `TZ` 를 걸어 맞추는 방법도 있지만, 그러면 **정확성이 배포 설정에
의존**한다. 설정을 빠뜨린 환경(로컬 도커 실행, 다른 호스팅)에서 조용히 어긋나므로
코드에서 기준 시각을 고정한다.

DB 의 `created_at` 은 UTC 로 저장된다. 저장값을 화면용 날짜/시각으로 바꿀 때는
[to_seoul] 을 거친다.
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo

#: 서비스 기준 타임존. 단일 지역 서비스라 사용자별 타임존은 두지 않는다.
SEOUL = ZoneInfo("Asia/Seoul")


def now() -> datetime:
    """KST 기준 현재 시각(tz-aware)."""
    return datetime.now(SEOUL)


def today() -> date:
    """KST 기준 오늘 날짜."""
    return now().date()


def today_iso() -> str:
    """KST 기준 오늘 날짜 `YYYY-MM-DD`. DB 의 `date` 컬럼과 같은 표기."""
    return today().isoformat()


def to_seoul(ts: datetime) -> datetime:
    """저장된 시각을 KST 로 변환한다.

    naive 는 UTC 로 간주한다 — `created_at` 이 UTC naive 로 들어오기 때문이다.
    """
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    return ts.astimezone(SEOUL)
