"""AI 루틴 A/B 생성 — 순수 로직(규칙형 폴백).

회원의 실데이터 요약(나트륨/완료율/목표)과 트레이너가 조종하는 입력(가능 시간/강도/
메모)으로 두 계획을 만든다:
  * A안 — 짧고 지속하기 쉬운 회복 중심
  * B안 — 운동량/강도를 높인 루틴

외부 LLM(Gemini 등)이 붙으면 `maybe_llm_plans` 가 계획을 반환하고, 실패/미설정이면
여기 규칙형(`rule_based_plans`)으로 폴백한다. 규칙형은 결정적이라 테스트가 쉽고,
의료 진단·치료 지시를 하지 않는다(운동 구성과 근거만 제시).
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

_INTENSITY_KR = {"low": "낮음", "moderate": "보통", "high": "높음"}
_B_SCALE = {"low": 0.85, "moderate": 1.0, "high": 1.0}
_B_LABEL = {"low": "보통", "moderate": "높음", "high": "높음"}


def _compose(total: int, parts: list[tuple[str, str, int]]) -> list[dict]:
    """[(name, type, weight)] 를 total 분으로 가중 분배(각 ≥1, 반올림 오차는 마지막에)."""
    total = max(len(parts), total)  # 각 운동 최소 1분 보장
    tw = sum(w for _, _, w in parts) or 1
    used = 0
    out: list[dict] = []
    for i, (name, type_, w) in enumerate(parts):
        if i == len(parts) - 1:
            m = max(1, total - used)
        else:
            m = max(1, round(total * w / tw))
            used += m
        out.append({"name": name, "minutes": m, "type": type_})
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
) -> tuple[dict, dict]:
    """결정적 규칙형 A/B. 회원 수치를 근거 문구에 인용한다."""
    over = sodium_today_mg > SODIUM_TARGET_MG
    low_adherence = avg_completion_rate < 50
    goal_label = goal.strip() or "설정된 목표"

    # A안 — 회복·지속: 가능 시간의 ~70%, 낮은 강도, 유산소+스트레칭 중심.
    total_a = max(10, round(available_minutes * 0.7))
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

    # B안 — 강도·운동량: 가능 시간 전부(강도 선호로 스케일), 근력+유산소 중심.
    total_b = max(total_a + 5, round(available_minutes * _B_SCALE.get(intensity_preference, 1.0)))
    parts_b = [
        (_CARDIO_HARD[0], _CARDIO_HARD[1], 3),
        (_STRENGTH[0], _STRENGTH[1], 2),
        (_STRENGTH2[0], _STRENGTH2[1], 1),
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


def maybe_llm_plans(**kwargs) -> tuple[dict, dict] | None:
    """LLM(Gemini 등) 연동 지점. 미설정/실패 시 None → 규칙형 폴백.

    아직 외부 LLM 키를 두지 않았으므로 항상 None 을 반환한다. 연동 시 여기서
    프롬프트를 구성해 A/B(JSON)를 받아 검증 후 반환하고, 예외/스키마 불일치는
    삼켜 None 을 돌려 규칙형으로 안전하게 폴백한다.
    """
    return None
