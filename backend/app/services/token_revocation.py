"""refresh 토큰 폐기 — 로그아웃과 회전이 세션을 실제로 끊는 자리.

JWT 는 서명만 맞으면 만료까지 유효하다. 서버가 "이 토큰은 끝났다"고 말할 곳이
없으면 로그아웃은 **그 기기의 저장소를 지우는 일**에 그치고, 이미 빠져나간
토큰에는 아무 영향도 없다. 여기서 폐기된 `jti` 를 들고, `/auth/refresh` 가
그것을 확인한다(#966).

토큰 문자열이 아니라 `jti` 만 담는다 — 표가 새어도 그것으로 인증할 수는 없다.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.models import RevokedRefreshToken


def is_revoked(db: Session, jti: str) -> bool:
    return (
        db.scalar(
            select(RevokedRefreshToken.jti).where(RevokedRefreshToken.jti == jti)
        )
        is not None
    )


def revoke(db: Session, *, jti: str, user_id: str, expires_at: datetime) -> bool:
    """`jti` 를 폐기한다. 처음 폐기하면 True, 이미 폐기돼 있었으면 False.

    두 번째 폐기가 실패가 아니라 **False** 인 것은 호출부의 판단이 갈리기 때문이다.
    로그아웃은 이미 끊긴 세션을 다시 끊는 것이라 그냥 성공이지만, 회전에서는 같은
    사건이 **이미 쓴 refresh 토큰이 다시 왔다**는 뜻이라 거부해야 한다.

    같은 토큰으로 동시에 두 요청이 들어오면 둘 다 빈 표를 보고 넣으려 할 수 있다.
    이때 지는 쪽을 유일 키(PK)가 잡아 주므로, 조회 결과가 아니라 **삽입 성공 여부**로
    판정한다.
    """
    if is_revoked(db, jti):
        return False
    db.add(
        RevokedRefreshToken(jti=jti, user_id=user_id, expires_at=expires_at)
    )
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        return False
    purge_expired(db)
    db.commit()
    return True


def purge_expired(db: Session, *, now: datetime | None = None) -> int:
    """만료된 폐기 기록을 지우고 지운 수를 돌려준다.

    만료된 토큰은 JWT 검증에서 이미 거부되므로 폐기 여부를 물을 이유가 없다.
    남겨 두면 표가 발급량만큼 무한히 자란다. 폐기가 생길 때마다 함께 도는 정리라
    별도 배치나 스케줄러가 필요 없다.

    커밋하지 않는다 — 폐기와 같은 트랜잭션에서 끝나야 정리만 남고 폐기가 사라지는
    조합이 생기지 않는다.
    """
    cutoff = now or datetime.now(timezone.utc)
    result = db.execute(
        delete(RevokedRefreshToken).where(RevokedRefreshToken.expires_at < cutoff)
    )
    return int(result.rowcount or 0)
