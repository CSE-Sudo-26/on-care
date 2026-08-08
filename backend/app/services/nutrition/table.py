"""`food_nutrients` 참조표 로딩 + 프로세스 캐시.

이 표는 시딩 후 읽기 전용이고 전체가 2천 행 남짓이라, 요청마다 다시 읽을
이유가 없다(#424). 전건 로드는 2,127행 기준 중앙값 21.5ms 로 `/diet/analyze`
한 건의 DB 시간을 사실상 전부 차지한다. 표가 커질수록 선형으로 늘어난다.

## ORM 인스턴스를 캐시하지 않는 이유

`FoodNutrient` 인스턴스는 세션에 묶여 있다. 커밋 시 만료(expire_on_commit)되고
세션이 닫히면 detached 라, 다음 요청에서 속성을 읽는 순간 터진다. 그래서
필요한 값만 복사한 불변 스냅샷(`NutrientRow`)을 캐시한다. 매칭기(`matcher`)는
`.name_norm` 만 보는 덕타이핑이라 이 교체에 영향받지 않는다.

## 무효화

`FoodNutrient` 를 건드린 세션이 커밋/롤백하면 자동으로 비운다(아래 이벤트 훅).
ORM 을 거치지 않는 변경(Core bulk insert, 마이그레이션, psql 직접 수정)은
훅이 잡지 못하므로, 그런 경로를 새로 만든다면 `invalidate()` 를 직접 부른다.
프로세스 밖의 변경(다른 워커·마이그레이션)은 재기동으로 반영된다 — 시딩 후
바뀌지 않는 표라는 전제가 깨지면 이 캐시 자체를 다시 따져야 한다.
"""
from __future__ import annotations

import threading
from dataclasses import dataclass, fields

from sqlalchemy import event, select
from sqlalchemy.orm import Session

from app.models.models import FoodNutrient


@dataclass(frozen=True, slots=True)
class NutrientRow:
    """세션에 묶이지 않은 `food_nutrients` 한 행. 값은 100g 기준."""

    id: int
    name: str
    name_norm: str
    category: str
    serving_size_g: float | None
    calories: float
    sodium_mg: float
    sugar_g: float
    carbs_g: float | None
    protein_g: float | None
    fat_g: float | None


_lock = threading.Lock()
_cache: tuple[NutrientRow, ...] | None = None
# 로드 중에 들어온 무효화를 놓치지 않기 위한 세대 번호. 쿼리 전후로 값이
# 달라졌으면 그 사이 표가 바뀐 것이므로 결과를 캐시하지 않는다.
_generation = 0


# 컬럼만 읽는다(엔티티 아님). 어차피 스냅샷으로 옮겨 담을 값이라 ORM 인스턴스
# 2,127개를 만들 이유가 없고, 세션 identity map 도 더럽히지 않는다.
# 조회 순서를 필드에서 파생시켜야 위치 기반 생성이 어긋날 수 없다 —
# 필드를 추가하면 컬럼도 같이 따라온다(없는 컬럼이면 import 시점에 터진다).
_COLUMNS = tuple(getattr(FoodNutrient, f.name) for f in fields(NutrientRow))


def load_rows(db: Session) -> tuple[NutrientRow, ...]:
    """참조표 전건. 캐시가 살아 있으면 DB 를 치지 않는다."""
    global _cache

    cached = _cache
    if cached is not None:
        return cached

    with _lock:
        generation = _generation
    rows = tuple(NutrientRow(*r) for r in db.execute(select(*_COLUMNS)))

    with _lock:
        if generation == _generation:
            _cache = rows
    return rows


def invalidate() -> None:
    """캐시를 비운다. 다음 `load_rows` 가 DB 에서 다시 읽는다."""
    global _cache, _generation
    with _lock:
        _cache = None
        _generation += 1


_DIRTY_KEY = "oncare_food_nutrients_dirty"


@event.listens_for(Session, "after_flush")
def _mark_dirty(session: Session, flush_context: object) -> None:
    if any(
        isinstance(obj, FoodNutrient)
        for obj in (*session.new, *session.dirty, *session.deleted)
    ):
        session.info[_DIRTY_KEY] = True


# 커밋뿐 아니라 롤백에서도 비운다. 커밋 전 같은 세션에서 캐시가 채워졌다면
# 아직 확정되지 않은 행이 들어갔을 수 있고, 그 트랜잭션이 되돌아가면 캐시만
# 남는다.
@event.listens_for(Session, "after_commit")
@event.listens_for(Session, "after_soft_rollback")
def _invalidate_if_dirty(session: Session, *_: object) -> None:
    if session.info.pop(_DIRTY_KEY, False):
        invalidate()
