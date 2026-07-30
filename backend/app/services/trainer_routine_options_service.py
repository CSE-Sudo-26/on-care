"""회원 실데이터를 바탕으로 트레이너용 맞춤 루틴 후보를 생성한다.

설정된 코치 LLM(OpenAI/Gemini/LiteLLM)을 우선 호출하고, 키 미설정·네트워크
오류·잘못된 JSON 응답이면 결정론적인 규칙 기반 후보로 폴백한다.
"""
from __future__ import annotations

import json
import logging
from datetime import date, timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.models import DietEntry, RoutineHistory, TrainerClient, TrainerRoutine
from app.schemas.trainer_api import (
    RoutineOptionAnalysisOut,
    RoutineOptionExerciseOut,
    RoutineOptionPlanOut,
    RoutineOptionsOut,
    RoutineOptionsRequest,
)
from app.services.coach.llm import get_coach_llm

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """\
당신은 만성질환 위험군을 돕는 전문 운동 코치입니다.
제공된 회원 분석과 트레이너 조건만 사용해 서로 다른 맞춤 루틴 두 개를 만드세요.
의학적 진단이나 치료를 단정하지 말고, 통증·부상 메모가 있으면 저충격 대안을 우선하세요.

반드시 설명이나 마크다운 없이 아래 JSON 객체만 반환하세요.
{
  "plan_a": {
    "key": "A",
    "label": "짧고 직관적인 한국어 이름",
    "total_minutes": 30,
    "intensity": "낮음|보통|높음",
    "exercises": [
      {"name": "운동명", "minutes": 15, "type": "유산소|근력|스트레칭"}
    ],
    "reason": "회원에게 보여줄 짧은 추천 이유",
    "rationale": "트레이너가 확인할 데이터 근거"
  },
  "plan_b": {
    "key": "B",
    "label": "짧고 직관적인 한국어 이름",
    "total_minutes": 30,
    "intensity": "낮음|보통|높음",
    "exercises": [
      {"name": "운동명", "minutes": 15, "type": "유산소|근력|스트레칭"}
    ],
    "reason": "회원에게 보여줄 짧은 추천 이유",
    "rationale": "트레이너가 확인할 데이터 근거"
  }
}
각 plan의 total_minutes는 exercises의 minutes 합과 정확히 같아야 합니다.
"""


def build_member_analysis(
    db: Session,
    trainer_id: str,
    member_id: str,
    request: RoutineOptionsRequest,
) -> RoutineOptionAnalysisOut:
    """소유 링크와 회원의 최근 식단·운동·배정 데이터를 하나의 분석으로 집계."""
    link = db.scalar(
        select(TrainerClient).where(
            TrainerClient.trainer_id == trainer_id,
            TrainerClient.member_id == member_id,
        )
    )
    if link is None:
        raise ValueError("담당 고객을 찾을 수 없습니다.")

    today = date.today().isoformat()
    sodium = int(
        db.scalar(
            select(func.coalesce(func.sum(DietEntry.sodium_mg), 0)).where(
                DietEntry.user_id == member_id,
                DietEntry.date == today,
            )
        )
        or 0
    )

    since = (date.today() - timedelta(days=27)).isoformat()
    completion = db.scalar(
        select(func.avg(RoutineHistory.completion_rate)).where(
            RoutineHistory.member_id == member_id,
            RoutineHistory.date >= since,
            or_(
                RoutineHistory.trainer_id.is_(None),
                RoutineHistory.trainer_id == trainer_id,
            ),
        )
    )

    latest = db.scalar(
        select(TrainerRoutine)
        .where(
            TrainerRoutine.trainer_id == trainer_id,
            TrainerRoutine.member_id == member_id,
        )
        .order_by(TrainerRoutine.created_at.desc(), TrainerRoutine.id.desc())
        .limit(1)
    )

    return RoutineOptionAnalysisOut(
        goal=link.goal,
        sodium_today_mg=sodium,
        sodium_over_target=sodium > 2000,
        avg_completion_rate=round(float(completion or 0)),
        latest_routine=latest.name if latest is not None else "-",
        note=request.trainer_note.strip(),
    )


def _split_minutes(total: int, ratios: tuple[float, ...]) -> list[int]:
    """양수 분량으로 나누되 반올림 오차를 마지막 항목에 모은다."""
    parts: list[int] = []
    remaining = total
    for index, ratio in enumerate(ratios):
        slots_left = len(ratios) - index - 1
        if slots_left == 0:
            parts.append(remaining)
            break
        part = max(1, round(total * ratio))
        part = min(part, remaining - slots_left)
        parts.append(part)
        remaining -= part
    return parts


def build_rule_options(
    analysis: RoutineOptionAnalysisOut,
    request: RoutineOptionsRequest,
) -> RoutineOptionsOut:
    """LLM을 사용할 수 없을 때도 동일 계약으로 동작하는 안전한 폴백."""
    total_a = max(10, round(request.available_minutes * 0.7))
    total_a = min(total_a, request.available_minutes)
    total_b = request.available_minutes
    a_walk, a_stretch = _split_minutes(total_a, (0.65, 0.35))
    b_cardio, b_strength, b_cooldown = _split_minutes(
        total_b,
        (0.5, 0.35, 0.15),
    )
    note_suffix = (
        f" 트레이너 메모({analysis.note})를 반영했습니다." if analysis.note else ""
    )
    sodium_context = (
        f"오늘 나트륨 {analysis.sodium_today_mg}mg으로 목표를 초과해"
        if analysis.sodium_over_target
        else f"오늘 나트륨 {analysis.sodium_today_mg}mg과"
    )
    b_intensity = {
        "low": "낮음",
        "moderate": "보통",
        "high": "높음",
    }[request.intensity_preference]

    return RoutineOptionsOut(
        analysis=analysis,
        plan_a=RoutineOptionPlanOut(
            key="A",
            label="회복 중심",
            total_minutes=total_a,
            intensity="낮음",
            exercises=[
                RoutineOptionExerciseOut(
                    name="저강도 걷기",
                    minutes=a_walk,
                    type="유산소",
                ),
                RoutineOptionExerciseOut(
                    name="전신 스트레칭",
                    minutes=a_stretch,
                    type="스트레칭",
                ),
            ],
            reason="부담을 낮추고 꾸준히 이어가기 좋은 구성",
            rationale=(
                f"{sodium_context} 최근 완료율 {analysis.avg_completion_rate}%를 "
                f"함께 고려한 회복 중심 후보입니다.{note_suffix}"
            ),
        ),
        plan_b=RoutineOptionPlanOut(
            key="B",
            label="운동량 중심",
            total_minutes=total_b,
            intensity=b_intensity,
            exercises=[
                RoutineOptionExerciseOut(
                    name="인터벌 유산소",
                    minutes=b_cardio,
                    type="유산소",
                ),
                RoutineOptionExerciseOut(
                    name="전신 근력 운동",
                    minutes=b_strength,
                    type="근력",
                ),
                RoutineOptionExerciseOut(
                    name="쿨다운 스트레칭",
                    minutes=b_cooldown,
                    type="스트레칭",
                ),
            ],
            reason="설정한 시간 안에서 운동량을 충분히 확보한 구성",
            rationale=(
                f"목표({analysis.goal})와 희망 강도({b_intensity}), 최근 완료율 "
                f"{analysis.avg_completion_rate}%를 반영한 운동량 중심 후보입니다."
                f"{note_suffix}"
            ),
        ),
        generated_by="rule",
    )


def _decode_json_object(text: str) -> dict:
    """LLM이 실수로 붙인 코드펜스·설명 앞뒤를 제거하고 첫 JSON 객체만 읽는다."""
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        raise ValueError("LLM 응답에 JSON 객체가 없습니다.")
    parsed = json.loads(text[start : end + 1])
    if not isinstance(parsed, dict):
        raise ValueError("LLM 응답은 JSON 객체여야 합니다.")
    return parsed


def _generate_with_llm(
    analysis: RoutineOptionAnalysisOut,
    request: RoutineOptionsRequest,
) -> RoutineOptionsOut:
    prompt = json.dumps(
        {
            "member_analysis": analysis.model_dump(),
            "available_minutes": request.available_minutes,
            "intensity_preference": request.intensity_preference,
            "trainer_note": request.trainer_note.strip(),
        },
        ensure_ascii=False,
    )
    result = get_coach_llm().generate(_SYSTEM_PROMPT, prompt)
    payload = _decode_json_object(result.text)
    payload["analysis"] = analysis.model_dump()
    payload["generated_by"] = "ai"
    options = RoutineOptionsOut.model_validate(payload)
    if (
        options.plan_a.total_minutes > request.available_minutes
        or options.plan_b.total_minutes > request.available_minutes
    ):
        raise ValueError("LLM 루틴 시간이 요청 가능한 시간을 초과했습니다.")
    return options


def generate_routine_options(
    db: Session,
    trainer_id: str,
    member_id: str,
    request: RoutineOptionsRequest,
) -> RoutineOptionsOut:
    analysis = build_member_analysis(db, trainer_id, member_id, request)
    fallback = build_rule_options(analysis, request)
    try:
        return _generate_with_llm(analysis, request)
    except Exception:  # noqa: BLE001 — provider/network/JSON failures all fall back
        logger.warning(
            "맞춤 루틴 LLM 생성 실패 — 규칙 기반 폴백 사용 "
            "(trainer_id=%s, member_id=%s)",
            trainer_id,
            member_id,
            exc_info=True,
        )
        return fallback
