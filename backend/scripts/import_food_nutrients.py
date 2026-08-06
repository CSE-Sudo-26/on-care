"""공공 식품영양성분(음식) 표준데이터 → `app/data/food_nutrients_public.csv` 생성.

원본: 공공데이터포털 "전국통합식품영양성분정보(음식)표준데이터" CSV (cp949, 52컬럼).

사용법:
    python -m scripts.import_food_nutrients \\
        data/raw/전국통합식품영양성분정보_음식_표준데이터.csv

원본 CSV(5.9MB)는 저장소에 넣지 않는다(`backend/data/raw/` 는 gitignore).
이 스크립트가 만든 집계본만 커밋해, CI·팀원·배포가 같은 데이터를 쓴다.

## 왜 그냥 넣지 않는가

**1) 대표식품 단위로 집계한다.**
원본의 `식품명` 은 프랜차이즈 개별 상품이다(`피자_점보스테이크불갈비피자 (L)`).
인식기는 사진을 보고 그냥 "피자" 라고 하므로, 상품명 19,495건을 그대로 넣으면
질의 "피자" 가 수천 개 이름의 부분이 되어 매칭기 3단계에서 모호 판정 → 폴백한다.
데이터를 잔뜩 넣고도 흔한 음식이 하나도 안 잡힌다. `대표식품명`(1,178종)이
인식기가 말하는 층이다.

**2) 프랜차이즈 행을 제외한다.**
`식품중량` 이 프랜차이즈에서는 "판매 단위" 다 — 라지 피자 1,640g. 그대로
1인분으로 환산하면 피자 한 조각을 찍은 사용자에게 2,092kcal·나트륨 3,458mg 을
붙인다. 제외하면 200g·506kcal 로 실제 1인분이 된다. 제외해도 대표식품 종 수는
1,249 → 1,178 로 거의 줄지 않는다.

**3) 100g 기준을 1인분으로 환산한다.**
원본은 전부 `영양성분함량기준량` 이 100g/100ml 다. 이 테이블은 1인분 기준이라
`식품중량` 으로 환산해야 한다. 환산을 빠뜨리면 값이 통째로 어긋나는데 아무
오류도 나지 않는다.

**4) 중앙값으로 모은다.**
같은 대표식품에 여러 행이 있고(김치찌개 34건) 편차가 크다. 평균은 이상치에
끌려가므로 중앙값을 쓴다.

## 기존 큐레이션 40종과의 관계

이 파일은 `food_nutrients_seed.py`(손으로 정리한 40종)를 **대체하지 않는다**.
적재 시 큐레이션이 먼저 들어가고, 여기서 겹치는 이름은 건너뛴다. 큐레이션 값은
고혈압·당뇨 관점에서 따로 검증한 것이라 공식 중앙값보다 우선한다 — 예를 들어
라면 나트륨이 큐레이션 1,800mg vs 공식 중앙값 452mg 로 크게 다르다(공식 쪽은
급식 라면이 섞인 결과로 보인다).
"""
from __future__ import annotations

import argparse
import csv
import io
import pathlib
import re
import statistics
import sys

# 판매 단위(라지 피자 한 판 등)라 1인분 환산이 성립하지 않는다.
_FRANCHISE_PREFIX = "외식(프랜차이즈"

# "300g", "350ml", "201.7" 모두 앞쪽 숫자를 쓴다(단위는 기준량과 같이 움직인다).
_LEADING_NUMBER = re.compile(r"([\d.]+)")

_OUT_COLUMNS = [
    "name",
    "category",
    "serving_size_g",
    "calories",
    "sodium_mg",
    "sugar_g",
    "carbs_g",
    "protein_g",
    "fat_g",
    "sample_count",
]


def _weight_g(raw: str) -> float | None:
    """`식품중량` → 그램 수. 파싱 불가·0 이하는 None."""
    match = _LEADING_NUMBER.search(raw or "")
    if not match:
        return None
    try:
        value = float(match.group(1))
    except ValueError:
        return None
    return value if value > 0 else None


def _per_serving(row: dict[str, str], column: str, weight: float) -> float | None:
    """100g 기준 값을 1인분(=식품중량)으로 환산. 빈 칸은 None."""
    raw = (row.get(column) or "").strip()
    if not raw:
        return None
    try:
        return float(raw) * weight / 100.0
    except ValueError:
        return None


def _median(values: list[float]) -> float | None:
    return statistics.median(values) if values else None


def aggregate(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    """원본 행 → 대표식품 단위 1인분 집계."""
    groups: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        if row.get("식품기원명", "").startswith(_FRANCHISE_PREFIX):
            continue
        name = (row.get("대표식품명") or "").strip()
        if not name:
            continue
        groups.setdefault(name, []).append(row)

    out: list[dict[str, object]] = []
    for name, group in sorted(groups.items()):
        weights = [(r, _weight_g(r.get("식품중량", ""))) for r in group]
        usable = [(r, w) for r, w in weights if w is not None]
        if not usable:
            continue

        def med(column: str) -> float | None:
            return _median(
                [
                    v
                    for v in (_per_serving(r, column, w) for r, w in usable)
                    if v is not None
                ]
            )

        calories = med("에너지(kcal)")
        if calories is None:
            # 에너지조차 없으면 보정 값으로 쓸 수 없다.
            continue

        out.append(
            {
                "name": name,
                # 대분류는 그룹 안에서 갈릴 수 있어 최빈값을 쓴다.
                "category": statistics.mode(
                    [(r.get("식품대분류명") or "").strip() for r, _ in usable]
                ),
                "serving_size_g": round(_median([w for _, w in usable]) or 0, 1),
                "calories": round(calories, 1),
                "sodium_mg": _round_or_none(med("나트륨(mg)"), 1),
                "sugar_g": _round_or_none(med("당류(g)"), 2),
                "carbs_g": _round_or_none(med("탄수화물(g)"), 2),
                "protein_g": _round_or_none(med("단백질(g)"), 2),
                "fat_g": _round_or_none(med("지방(g)"), 2),
                "sample_count": len(usable),
            }
        )
    return out


def _round_or_none(value: float | None, digits: int) -> float | None:
    return None if value is None else round(value, digits)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=pathlib.Path, help="원본 CSV 경로")
    parser.add_argument(
        "--out",
        type=pathlib.Path,
        default=pathlib.Path("app/data/food_nutrients_public.csv"),
        help="생성할 집계 CSV 경로",
    )
    parser.add_argument("--encoding", default="cp949", help="원본 인코딩")
    args = parser.parse_args(argv)

    if not args.source.exists():
        print(f"원본을 찾을 수 없습니다: {args.source}", file=sys.stderr)
        return 1

    text = args.source.read_bytes().decode(args.encoding)
    rows = list(csv.DictReader(io.StringIO(text)))
    aggregated = aggregate(rows)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=_OUT_COLUMNS)
        writer.writeheader()
        writer.writerows(aggregated)

    print(f"원본 {len(rows)}행 → 대표식품 {len(aggregated)}종")
    print(f"기록: {args.out}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
