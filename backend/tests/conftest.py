"""pytest 공통 설정.

- 순수 유닛 테스트(test_config, test_security)는 DB 없이 실행됩니다.
- DB/엔드포인트 테스트는 `client` 픽스처를 쓰며, DB 연결이 안 되면 자동 skip 됩니다
  (로컬은 skip, CI 의 Postgres(pgvector) 서비스에서 실행).
- 테스트는 **개발·데모 DB 가 아니라 전용 DB** 에 씁니다(아래 참고).
"""
from __future__ import annotations

import os

import pytest
from sqlalchemy import create_engine, text

#: 테스트 전용 DB. 예전에는 기본값이 개발 DB 라, 한 번 돌릴 때마다 테스트가 만든
#: 계정이 데모 DB 에 그대로 쌓였다(회원 수천 명·감사 로그 수만 행). 중단된 실행이
#: 남긴 행 때문에 다음 실행이 중복 키로 깨지기도 했다.
#:
#: 최초 1회만 만들어 두면 된다 — 스키마와 데모 시드는 앱 기동(lifespan)이 채운다.
#:
#:     createdb -h 127.0.0.1 -U oncare oncare_test
#:     psql -h 127.0.0.1 -d oncare_test -c 'CREATE EXTENSION IF NOT EXISTS vector'
#:
#: (확장 생성은 superuser 권한이 필요해 `oncare` 로는 안 된다. 한 번 만들어 두면
#: 앱의 `CREATE EXTENSION IF NOT EXISTS` 는 그냥 통과한다.)
DEFAULT_TEST_DATABASE_URL = (
    "postgresql+psycopg://oncare:oncare@localhost:5432/oncare_test"
)

#: 앱 엔진(`app.db.session`)은 설정에서 URL 을 읽고, 설정은 환경변수를 `.env` 보다
#: 먼저 본다. 그래서 **여기서 환경변수를 심어야** 테스트 클라이언트가 만드는 데이터도
#: 전용 DB 로 간다 — 이 파일 안의 상수만 바꾸면 픽스처만 옮겨 가고 앱은 개발 DB 에
#: 계속 쓴다. `setdefault` 라 CI 처럼 이미 지정된 값은 그대로 둔다.
os.environ.setdefault("DATABASE_URL", DEFAULT_TEST_DATABASE_URL)

DATABASE_URL = os.environ["DATABASE_URL"]


def _db_available() -> bool:
    try:
        engine = create_engine(DATABASE_URL, pool_pre_ping=True)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        engine.dispose()
        return True
    except Exception:
        return False


@pytest.fixture(scope="session")
def client():
    """FastAPI TestClient. DB 가 없으면 skip."""
    if not _db_available():
        pytest.skip("DB 연결 불가 — CI(Postgres 서비스)에서 실행됩니다.")
    from fastapi.testclient import TestClient

    from app.main import app

    with TestClient(app) as c:  # lifespan → init_db (vector extension / create_all / seed)
        yield c


@pytest.fixture(autouse=True)
def _reset_rate_limiter():
    """각 테스트 전 rate limiter 상태 초기화(테스트 간 누적 방지).
    fastapi 미설치 로컬 환경에서는 조용히 건너뛴다(순수 테스트에 무영향)."""
    try:
        from app.core.rate_limit import limiter
        limiter.clear()
    except Exception:  # noqa: BLE001
        pass
    yield


@pytest.fixture(autouse=True)
def _force_stub_recognizer(monkeypatch):
    """테스트는 결정론적 오프라인 인식기(stub)를 사용한다.

    로컬 .env 에 실제 GEMINI_API_KEY 가 있으면 팩토리가 gemini 인식기를 골라,
    가짜 테스트 이미지가 실제 Vision API 로 나가 400(Unable to process image)을
    유발한다. CI(키 없음→stub)와 동일 경로로 고정해 테스트를 .env 독립적으로 만든다."""
    try:
        from app.core.config import get_settings
        monkeypatch.setattr(get_settings(), "recognizer", "stub")
    except Exception:  # noqa: BLE001, S110
        import warnings
        warnings.warn(
            "recognizer 를 stub 으로 강제하지 못했습니다 — 테스트가 실제 Gemini Vision API 를 호출할 수 있습니다.",
            stacklevel=2,
        )
    yield


@pytest.fixture
def db_session(client):
    """시드까지 끝난 DB 세션. client 픽스처가 먼저 init_db(시드)를 돌린다."""
    from app.db.session import SessionLocal

    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
