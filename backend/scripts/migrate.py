"""
마이그레이션 직렬화 러너 — App Runner 등 다중 인스턴스가 동시에 기동해도
여러 인스턴스가 같은 DB 를 동시에 마이그레이션하지 않도록 PostgreSQL advisory lock
으로 직렬화한다(리뷰 재-#3).

한 인스턴스가 lock 을 잡고 `alembic upgrade head` 를 수행하는 동안 다른 인스턴스는
lock 획득에서 대기하다가, 앞 인스턴스가 끝나면 lock 을 잡고 alembic 을 실행한다
(이미 head 면 사실상 no-op). alembic 이 실패하면 비정상 종료해 서버 기동을 막는다.
"""
from __future__ import annotations

import os
import subprocess
import sys

import psycopg

# 마이그레이션 전용 고정 advisory lock 키(임의 상수). 다른 용도와 겹치지 않게.
_LOCK_KEY = 4815162342


def main() -> int:
    # DATABASE_URL 은 SQLAlchemy 형식(postgresql+psycopg://...) → psycopg 는 순수 postgresql://
    url = os.environ["DATABASE_URL"].replace("postgresql+psycopg://", "postgresql://")
    conn = psycopg.connect(url, autocommit=True)
    try:
        print(f"[migrate] acquiring advisory lock {_LOCK_KEY}", flush=True)
        conn.execute("SELECT pg_advisory_lock(%s)", (_LOCK_KEY,))
        print("[migrate] lock acquired -> alembic upgrade head", flush=True)
        subprocess.run(["alembic", "upgrade", "head"], check=True)
        print("[migrate] alembic upgrade head done", flush=True)
        return 0
    finally:
        conn.execute("SELECT pg_advisory_unlock(%s)", (_LOCK_KEY,))
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
