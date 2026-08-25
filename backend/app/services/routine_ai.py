"""AI 루틴 A/B 생성 — 순수 규칙형 로직.

회원의 실데이터 요약(나트륨/완료율/목표)과 트레이너가 조종하는 입력(가능 시간/강도/
메모)으로 두 계획을 만든다:
  * A안 — 짧고 지속하기 쉬운 회복 중심
  * B안 — 운동량/강도를 높인 루틴

LLM 생성과 이 규칙형 생성기로의 폴백은 `trainer_routine_options_service`가 담당한다.
이 모듈은 결정적인 규칙형 계획만 만들며, 의료 진단·치료 지시를 하지 않는다
(운동 구성과 근거만 제시).
"""
from __future__ import annotations

SODIUM_TARGET_MG = 2000

# 타입별 운동 라이브러리(부담 낮음 → 높음).
_CARDIO_EASY = ("저강도 걷기", "유산소")
_CARDIO_HARD = ("인터벌 러닝", "유산소")
_STRENGTH = ("스쿼트", "근력")
_STRENGTH2 = ("플랭크", "근력")
_STRETCH = ("코어 스트레칭", "스트레칭")
_STRETCH2 = ("목·어깨 스트레칭", "스트레칭")

_B_LABEL = {"low": "낮음", "moderate": "보통", "high": "높음"}

#: 반복 운동 이름으로 타입을 대략 짐작한다. 완료 기록엔 이름만 있고 타입이
#: 없어서, 화면에 보여줄 타입 하나는 정해야 한다(#776).
_STRETCH_KEYWORDS = ("스트레칭", "요가", "폼롤러")
_CARDIO_KEYWORDS = ("걷기", "러닝", "자전거", "유산소", "인터벌", "달리기")


def _guess_type(name: str) -> str:
    if any(keyword in name for keyword in _STRETCH_KEYWORDS):
        return "스트레칭"
    if any(keyword in name for keyword in _CARDIO_KEYWORDS):
        return "유산소"
    return "근력"


def _phase_of(name: str, type_: str, *, index: int, last: int) -> str:
    """이 줄이 속한 단계 — 준비운동 · 본운동 · 마무리. (#934)

    스트레칭·저강도 걷기는 몸을 푸는 데 쓰는 동작이라, 맨 앞이면 준비운동,
    맨 뒤면 마무리로 본다. 그 밖에는 본운동이다 — 없는 단계를 지어내지 않는다.
    """
    warmup_like = type_ == "스트레칭" or name == _CARDIO_EASY[0]
    if not warmup_like or last == 0:
        return "main"
    if index == 0:
        return "warmup"
    if index == last:
        return "cooldown"
    return "main"


def _compose(total: int, parts: list[tuple[str, str, int]]) -> list[dict]:
    """[(name, type, weight)] 를 total 분으로 가중 분배(각 ≥1, 반올림 오차는 마지막에).

    단계(`phase`)도 함께 매긴다 — 저장 계약이 그 칸을 갖게 됐고(#934), 규칙
    기반 폴백이 비워 두면 화면이 전부 본운동으로만 보인다.
    """
    total = max(len(parts), total)  # 각 운동 최소 1분 보장
    tw = sum(w for _, _, w in parts) or 1
    used = 0
    out: list[dict] = []
    last = len(parts) - 1
    for i, (name, type_, w) in enumerate(parts):
        if i == len(parts) - 1:
            m = max(1, total - used)
        else:
            m = max(1, round(total * w / tw))
            used += m
        out.append(
            {
                "name": name,
                "minutes": m,
                "type": type_,
                "phase": _phase_of(name, type_, index=i, last=last),
            }
        )
    return out


def _note_suffix(trainer_note: str) -> str:
    note = trainer_note.strip()
    return f" 트레이너 메모 반영: {note}." if note else ""


def rule_based_plans(
    *,
    goal: str,
    sodium_today_mg: int,
    avg_completion_rate: int,
    available_minutes: int,
    intensity_preference: str,
    trainer_note: str,
    frequent_exercises: list[str] | tuple[str, ...] = (),
) -> tuple[dict, dict]:
    """결정적 규칙형 A/B. 회원 수치를 근거 문구에 인용한다.

    `frequent_exercises` 가 있으면(#776, 개인화 가능한 회원) 고정 라이브러리
    대신 그 운동들로 A/B 를 구성한다 — 데이터가 없는 회원과 같은 함수를 쓰되
    인자 하나로 갈리므로, 개인화 여부에 따라 별도 함수를 유지·동기화할 필요가
    없다.
    """
    if frequent_exercises:
        return _pattern_based_plans(
            frequent_exercises=list(frequent_exercises),
            available_minutes=available_minutes,
            intensity_preference=intensity_preference,
            trainer_note=trainer_note,
        )

    over = sodium_today_mg > SODIUM_TARGET_MG
    low_adherence = avg_completion_rate < 50
    goal_label = goal.strip() or "설정된 목표"

    # A안 — 회복·지속: 가능 시간의 ~70%, 낮은 강도, 유산소+스트레칭 중심.
    total_a = min(available_minutes, max(5, round(available_minutes * 0.7)))
    parts_a = [(_CARDIO_EASY[0], _CARDIO_EASY[1], 3), (_STRETCH[0], _STRETCH[1], 2)]
    if over or low_adherence:
        # 부담을 더 낮추고 스트레칭 비중을 키운다.
        parts_a = [
            (_CARDIO_EASY[0], _CARDIO_EASY[1], 2),
            (_STRETCH[0], _STRETCH[1], 2),
            (_STRETCH2[0], _STRETCH2[1], 1),
        ]
    plan_a = {
        "key": "A",
        "label": "회복·지속 중심",
        "total_minutes": total_a,
        "intensity": "낮음",
        "exercises": _compose(total_a, parts_a),
        "reason": "짧고 지속하기 쉬운 회복 중심 루틴",
        "rationale": (
            f"오늘 나트륨 {sodium_today_mg}mg"
            f"{' (목표 초과)' if over else ''}, 최근 운동 완료율 "
            f"{avg_completion_rate}% → 부담이 적은 유산소·스트레칭으로 지속 가능성에 집중."
            + _note_suffix(trainer_note)
        ),
    }

    # B안 — 입력한 가능 시간 전부, 근력+유산소 중심. 강도 선호는 운동
    # 강도를 조절하는 값이지 트레이너가 입력한 시간 계약을 바꾸지 않는다.
    total_b = available_minutes
    # 몸을 풀고 → 본 운동 → 정리하는 차례로 짠다(#934). 준비·마무리는 짧게
    # 두어 본운동 시간을 잠식하지 않는다.
    parts_b = [
        (_CARDIO_EASY[0], _CARDIO_EASY[1], 1),
        (_CARDIO_HARD[0], _CARDIO_HARD[1], 3),
        (_STRENGTH[0], _STRENGTH[1], 2),
        (_STRENGTH2[0], _STRENGTH2[1], 1),
        (_STRETCH[0], _STRETCH[1], 1),
    ]
    plan_b = {
        "key": "B",
        "label": "강도·운동량 중심",
        "total_minutes": total_b,
        "intensity": _B_LABEL.get(intensity_preference, "높음"),
        "exercises": _compose(total_b, parts_b),
        "reason": "운동량과 강도를 높인 루틴",
        "rationale": (
            f"목표 '{goal_label}' 기준, 완료율 {avg_completion_rate}%로 "
            f"{'상향 여력이 있어' if avg_completion_rate >= 60 else '점진적으로'} "
            f"근력·유산소를 더해 운동량을 높임."
            + _note_suffix(trainer_note)
        ),
    }
    return plan_a, plan_b


def _pattern_based_plans(
    *,
    frequent_exercises: list[str],
    available_minutes: int,
    intensity_preference: str,
    trainer_note: str,
) -> tuple[dict, dict]:
    """반복 패턴이 확인된 회원용 A/B(#776).

    A안 — 기존 패턴 유지형: 반복 확인된 운동을 그대로 구성한다.
    B안 — 점진적 강화형: 같은 핵심 운동에 하나만 더해 운동량을 소폭 늘린다.
    두 안 모두 완전히 새로운 루틴을 만들지 않는다는 이슈의 요구를 반영한다.
    """
    core = frequent_exercises[:3]
    core_parts = [(name, _guess_type(name), 2) for name in core]
    core_label = ", ".join(core)
    intensity_label = _B_LABEL.get(intensity_preference, "보통")

    # A안은 요청 시간의 ~75%만 쓴다 — 기존 패턴 그대로이되, "유지"와 "확대"가
    # 시간상으로도 구분돼야 한다(전체 A/B 계약이 기대하는 a < b, #776).
    # B안은 요청 시간 전부를 쓴다.
    total_a = min(available_minutes, max(len(core_parts), round(available_minutes * 0.75)))
    plan_a = {
        "key": "A",
        "label": "기존 패턴 유지형",
        "total_minutes": total_a,
        "intensity": intensity_label,
        "exercises": _compose(total_a, core_parts),
        "reason": "최근 자주 수행한 운동을 그대로 유지",
        "rationale": (
            f"최근 기록에서 반복 확인된 운동({core_label})을 유지하고 "
            "부족한 부분만 보완." + _note_suffix(trainer_note)
        ),
    }

    # 이미 핵심으로 쓴 운동은 제외하고 라이브러리에서 하나만 더한다 — 셋 다
    # 겹치는 것은 사실상 없지만(반복 기록은 자유 텍스트, 라이브러리는 고정
    # 한국어 이름), 겹쳐도 첫 후보로 안전하게 넘어가게 기본값을 둔다.
    extra_pool = (_STRENGTH, _CARDIO_HARD, _STRENGTH2)
    extra_name, extra_type = next(
        ((name, type_) for name, type_ in extra_pool if name not in core),
        extra_pool[0],
    )
    total_b = available_minutes
    plan_b = {
        "key": "B",
        "label": "점진적 강화형",
        "total_minutes": total_b,
        "intensity": _B_LABEL.get(intensity_preference, "높음"),
        "exercises": _compose(total_b, [*core_parts, (extra_name, extra_type, 1)]),
        "reason": "기존 핵심 운동을 유지하며 운동량을 소폭 확대",
        "rationale": (
            f"기존 핵심 운동({core_label})은 유지하고 '{extra_name}'을(를) 더해 "
            "운동량을 점진적으로 늘림." + _note_suffix(trainer_note)
        ),
    }
    return plan_a, plan_b
