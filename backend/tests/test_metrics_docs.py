"""README 의 지표 표가 실제로 나오는 키와 일치하는가 (#615).

표는 "`counters` 에 들어오는 키" 를 전부 적는다고 선언한다. 그런데 #584 가 사유
둘(busy·timeout)을 추가하면서 표는 그대로였고, 지표를 보다 문서에 없는 값을 만나면
"이상 동작" 으로 읽혀 원인 파악이 늦어졌다.

사람이 매번 맞추는 대신 여기서 잡는다 — 사유가 늘면 이 테스트가 먼저 깨진다.
"""
from __future__ import annotations

import pathlib
import re

import pytest

_README = pathlib.Path(__file__).resolve().parents[1] / "README.md"
_SOURCES = [
    pathlib.Path(__file__).resolve().parents[1]
    / "app" / "services" / "trainer_routine_options_service.py",
    pathlib.Path(__file__).resolve().parents[1]
    / "app" / "services" / "diet_recommendation_service.py",
]

#: `metrics.incr("name", label="value")` 와 `_record(..., reason="value")` 를 모두 잡는다.
_INCR = re.compile(r'metrics\.incr\(\s*"([\w.]+)"(?:\s*,\s*(\w+)="([\w]+)")?')
_RECORD_REASON = re.compile(r'_record\([^)]*reason="(\w+)"')


def _emitted_keys() -> set[str]:
    """코드가 실제로 올리는 카운터 키를 모은다."""
    labelled: set[str] = set()
    bare: set[str] = set()
    reasons: set[str] = set()
    for path in _SOURCES:
        src = path.read_text(encoding="utf-8")
        for name, label, value in _INCR.findall(src):
            if label:
                labelled.add(f"{name}{{{label}={value}}}")
            else:
                bare.add(name)
        reasons.update(_RECORD_REASON.findall(src))

    # `_record` 는 사유를 받아 routine_options.fallback 으로 올린다.
    labelled.update(f"routine_options.fallback{{reason={r}}}" for r in reasons)

    # 라벨 값이 변수인 호출(`reason=reason`)은 정규식이 이름만 잡는다. 같은 이름의
    # 라벨 키가 이미 있으면 그 bare 항목은 파싱 부산물이므로 버린다.
    named = {key.split("{", 1)[0] for key in labelled}
    return labelled | {name for name in bare if name not in named}


def _documented_keys() -> set[str]:
    """README 표의 첫 칸에서 백틱으로 감싼 키를 뽑는다."""
    documented: set[str] = set()
    for line in _README.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| `"):
            continue
        # 셀 구분은 **이스케이프되지 않은** 파이프다. 표 안의 `reason=a\|b` 를
        # 그냥 split 하면 키가 중간에서 잘린다.
        key = re.split(r"(?<!\\)\|", line)[1].strip().strip("`")
        # `reason=busy|timeout|error` 처럼 한 행이 여러 값을 묶은 경우를 펼친다.
        match = re.match(r"^([\w.]+)\{(\w+)=([\w\\|]+)\}$", key)
        if match:
            name, label, values = match.groups()
            for value in values.replace("\\", "").split("|"):
                documented.add(f"{name}{{{label}={value}}}")
        else:
            documented.add(key)
    return documented


def test_every_emitted_counter_is_documented():
    missing = _emitted_keys() - _documented_keys()

    assert not missing, f"README 지표 표에 없는 카운터: {sorted(missing)}"


def test_the_table_does_not_document_counters_that_no_longer_exist():
    """지워진 지표가 표에 남으면 없는 값을 찾게 만든다."""
    stale = {
        key for key in _documented_keys() - _emitted_keys()
        if key.startswith(("routine_options.", "diet_recommendations."))
    }

    assert not stale, f"코드에 없는데 표에 남은 카운터: {sorted(stale)}"


@pytest.mark.parametrize("reason", ["busy", "timeout", "contract", "infra"])
def test_the_routine_fallback_reasons_are_all_listed(reason):
    """사유마다 볼 곳이 달라서, 하나라도 빠지면 그 경로만 진단이 막힌다."""
    assert f"routine_options.fallback{{reason={reason}}}" in _documented_keys()
