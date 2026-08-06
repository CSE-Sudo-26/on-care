"""공공 식품영양성분 표준데이터 → `app/data/food_nutrients_public.csv` 생성.

원본(공공데이터포털 / 식약처):
  data/raw/음식.csv           전국통합식품영양성분정보(음식)          19,495행
  data/raw/가공식품.csv        식품의약품안전처 통합식품영양성분(가공식품) 306,293행
  data/raw/원재료성식품.csv     전국통합식품영양성분정보(원재료성식품)      3,704행

사용법:
    python -m scripts.import_food_nutrients            # data/raw 전체
    python -m scripts.import_food_nutrients --only 음식

원본(총 130MB)은 저장소에 넣지 않는다(`backend/data/raw/` 는 gitignore).
이 스크립트가 만든 집계본만 커밋해 CI·팀원·배포가 같은 데이터를 쓴다.

## 값은 100g 기준으로 넣는다

원본은 **전 데이터셋이 100% `100g`/`100ml` 기준**이다. 예전에는 이를
`식품중량` 으로 1인분 환산해서 넣었는데, 그게 문제의 근원이었다.

`식품중량` 은 "판매 포장 단위" 다 — 라지 피자 1,640g, 우유 1L 팩. 환산하면
피자 한 조각을 찍은 사용자에게 2,092kcal 이 붙는다. 실제로 1인분 환산 후
분산을 재보면 대표식품 안에서 3사분위가 중앙값의 3~5배까지 벌어졌다.

같은 항목을 **100g 기준 그대로** 재보면:

    피자    n=4692   232 / 252 / 274 kcal/100g   3Q÷중앙 1.09
    케이크  n= 657   271 / 307 / 352             3Q÷중앙 1.15
    김치찌개 n=  34    37 /  42 /  48             3Q÷중앙 1.16

분산은 음식이 아니라 포장 단위에 있었다. 100g 기준이면 프랜차이즈 4,692건도
서로 ±10% 안에서 일치한다. 그래서:

  - **환산하지 않는다** — 원본 형태 그대로라 손실도 추측도 없다
  - **프랜차이즈를 제외할 이유가 없다** — 포장 크기가 값에 영향을 주지 않는다
  - **`식품중량` 이 없는 데이터셋(원재료성식품)도 쓸 수 있다**

양(g)은 사진에서 인식기가 추정한다(`RecognizedFood.amount_g`). 밀도는 공공
DB 가, 양은 비전 모델이 대는 역할 분담이다.

## 대표식품 단위로 모으는 이유

원본 `식품명` 은 개별 상품이다(`피자_점보스테이크불갈비피자 (L)`). 인식기는
"피자" 라고만 하므로 상품명을 그대로 넣으면 질의가 수천 개 이름의 부분이 되어
매칭기 3단계에서 모호 판정 → 폴백한다. 데이터를 잔뜩 넣고도 흔한 음식이
안 잡힌다. `대표식품명` 이 인식기가 말하는 층이다.

같은 대표식품에 여러 행이 있고 편차가 있으므로 **중앙값**으로 모은다(평균은
이상치에 끌려간다).
"""
from __future__ import annotations

import argparse
import csv
import io
import pathlib
import re
import statistics
import sys

# 1인분 힌트로만 쓴다(값 환산에는 쓰지 않는다). 프랜차이즈 포장은 판매 단위라
# 1인분 대표값으로 부적절해 힌트 계산에서만 제외한다.
_FRANCHISE_PREFIX = "외식(프랜차이즈"

# "300g", "350ml", "1000m"(ml 절단), "201.7"(무단위) 를 모두 받는다.
_WEIGHT = re.compile(r"^\s*([\d.]+)\s*([a-zA-Z]*)")

# 단위 → 그램 환산 계수. ml·L 은 밀도 1.0 을 가정한다 — 이 데이터의 액체는
# 국·찌개 국물과 음료라 대부분 물이고(오차 수 %), 제외하면 김치찌개처럼
# 100ml 기준으로 등록된 한식이 1회 섭취량 힌트를 통째로 잃는다.
# "1000m" 은 원본에 실재하는 ml 절단 표기다(65건).
_UNIT_TO_G = {"": 1.0, "g": 1.0, "kg": 1000.0, "ml": 1.0, "m": 1.0, "l": 1000.0}

_SOURCES = ("음식", "가공식품", "원재료성식품")

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
    "source_dataset",
]


def _read(path: pathlib.Path) -> list[dict[str, str]]:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "cp949", "utf-8"):
        try:
            return list(csv.DictReader(io.StringIO(raw.decode(encoding))))
        except UnicodeDecodeError:
            continue
    raise ValueError(f"인코딩을 판별하지 못했습니다: {path}")


def _number(raw: str) -> float | None:
    raw = (raw or "").strip()
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError:
        return None


def _weight_g(raw: str) -> float | None:
    """`식품중량` → 그램 수. 1인분 힌트로만 쓴다.

    단위를 **명시적으로** 읽는다. 예전에는 앞 숫자만 취해 단위를 무시했는데,
    그러면 알 수 없는 단위가 조용히 그램으로 쓰인다. 모르는 단위는 None 이다.
    """
    match = _WEIGHT.match(raw or "")
    if not match:
        return None
    try:
        value = float(match.group(1))
    except ValueError:
        return None
    factor = _UNIT_TO_G.get(match.group(2).lower())
    if factor is None:
        return None
    grams = value * factor
    # 5kg 넘는 값은 대형 포장(선물세트 등)이라 1인분 힌트가 못 된다.
    return grams if 0 < grams <= 5000 else None


def _median(values: list[float]) -> float | None:
    return statistics.median(values) if values else None


def aggregate(rows: list[dict[str, str]], dataset: str) -> list[dict[str, object]]:
    """원본 행 → 대표식품 단위 **100g 기준** 집계."""
    groups: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        name = (row.get("대표식품명") or "").strip()
        if name:
            groups.setdefault(name, []).append(row)

    out: list[dict[str, object]] = []
    for name, group in sorted(groups.items()):

        def med(column: str) -> float | None:
            return _median(
                [v for v in (_number(r.get(column, "")) for r in group) if v is not None]
            )

        calories = med("에너지(kcal)")
        if calories is None:
            # 열량조차 없으면 보정 값으로 쓸 수 없다.
            continue

        # 1인분 힌트: 인식기가 양을 못 줬을 때만 쓰는 폴백. 프랜차이즈 포장은
        # 판매 단위라 제외하고, 없으면 비워 둔다(추측하지 않는다).
        serving_candidates = [
            w
            for w in (
                _weight_g(r.get("식품중량", ""))
                for r in group
                if not (r.get("식품기원명") or "").startswith(_FRANCHISE_PREFIX)
            )
            if w is not None
        ]
        serving = _median(serving_candidates)

        out.append(
            {
                "name": name,
                "category": _mode([(r.get("식품대분류명") or "").strip() for r in group]),
                "serving_size_g": None if serving is None else round(serving, 1),
                "calories": round(calories, 1),
                "sodium_mg": _round_or_none(med("나트륨(mg)"), 1),
                "sugar_g": _round_or_none(med("당류(g)"), 2),
                "carbs_g": _round_or_none(med("탄수화물(g)"), 2),
                "protein_g": _round_or_none(med("단백질(g)"), 2),
                "fat_g": _round_or_none(med("지방(g)"), 2),
                "sample_count": len(group),
                "source_dataset": dataset,
            }
        )
    return out


def _mode(values: list[str]) -> str:
    values = [v for v in values if v]
    return statistics.mode(values) if values else ""


def _round_or_none(value: float | None, digits: int) -> float | None:
    return None if value is None else round(value, digits)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--raw-dir", type=pathlib.Path, default=pathlib.Path("data/raw")
    )
    parser.add_argument(
        "--out",
        type=pathlib.Path,
        default=pathlib.Path("app/data/food_nutrients_public.csv"),
    )
    parser.add_argument("--only", choices=_SOURCES, help="한 데이터셋만 처리")
    args = parser.parse_args(argv)

    wanted = (args.only,) if args.only else _SOURCES
    merged: dict[str, dict[str, object]] = {}
    for dataset in wanted:
        path = args.raw_dir / f"{dataset}.csv"
        if not path.exists():
            print(f"건너뜀(파일 없음): {path}", file=sys.stderr)
            continue
        rows = _read(path)
        aggregated = aggregate(rows, dataset)
        # 앞선 데이터셋이 우선한다(음식 > 가공식품 > 원재료성식품). 사용자가
        # 사진으로 찍는 것에 가까운 순서다.
        added = 0
        for item in aggregated:
            if item["name"] not in merged:
                merged[item["name"]] = item
                added += 1
        print(f"{dataset}: {len(rows)}행 → 대표식품 {len(aggregated)}종 (신규 {added})")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=_OUT_COLUMNS)
        writer.writeheader()
        writer.writerows(merged[name] for name in sorted(merged))

    print(f"합계 {len(merged)}종 → {args.out}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
