"""
AI 코치 서비스.

설계(사용자 요구사항 반영):
- 코칭을 '식단 코치'와 '운동 코치'로 도메인 분리해서 각각 생성한 뒤 합친다.
- STEP 7에서 각 도메인 코치를 RAG 기반으로 교체한다:
    * 검색 자료 = 개인 문서(환자 데이터, user_id=본인) + 공공 문서(user_id=NULL)
    * 식단 코치는 domain='diet' 자료를, 운동 코치는 domain='exercise' 자료를 위주로 검색
    * 다른 사용자의 개인 문서는 절대 섞이지 않음 (user_id 격리)

현재(STEP 6)는 RAG 전이라, 사용자의 실제 식단·운동 데이터를 읽어
'규칙 기반'으로 제안을 생성한다. 구조(도메인 분리)는 STEP 7과 동일하게 유지하므로
나중에 내부 구현만 LLM 호출로 바꾸면 된다.
"""
from __future__ import annotations

from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.models import DietEntry, ExerciseSession
from app.schemas.misc_api import AiCoachFeedback, CoachSuggestion
from app.services.exercise_service import monday_of_this_week_str


def _diet_suggestion(db: Session, user_id: str) -> CoachSuggestion:
    """식단 도메인 코치 (STEP 7에서 RAG+LLM 으로 교체)."""
    today = datetime.now().strftime("%Y-%m-%d")
    rows = db.scalars(
        select(DietEntry).where(DietEntry.user_id == user_id).where(DietEntry.date == today)
    ).all()
    total_na = sum(r.sodium_mg for r in rows)

    if not rows:
        return CoachSuggestion(
            tag="diet", title="오늘 식단을 기록해 보세요",
            body="사진 한 장이면 칼로리와 나트륨을 분석해 드려요. 첫 끼니부터 시작해 볼까요?",
        )
    if total_na > 2000:
        return CoachSuggestion(
            tag="diet", title="나트륨 섭취가 많아요",
            body=f"오늘 나트륨이 약 {total_na}mg 으로 권장량을 넘었어요. "
                 "저녁은 국물을 남기고 채소를 늘려 DASH 식단에 가깝게 맞춰봐요.",
        )
    return CoachSuggestion(
        tag="diet", title="식단 균형이 좋아요",
        body="오늘 나트륨 섭취가 안정적이에요. 이대로 꾸준히 유지해봐요!",
    )


def _exercise_suggestion(db: Session, user_id: str) -> CoachSuggestion:
    """운동 도메인 코치 (STEP 7에서 RAG+LLM 으로 교체)."""
    week = monday_of_this_week_str()
    rows = db.scalars(
        select(ExerciseSession)
        .where(ExerciseSession.user_id == user_id)
        .where(ExerciseSession.week_start == week)
    ).all()
    total_min = sum(r.minutes for r in rows)

    if total_min == 0:
        return CoachSuggestion(
            tag="exercise", title="이번 주 운동을 시작해 보세요",
            body="가벼운 30분 걷기부터 시작하면 혈압·혈당 관리에 도움이 돼요.",
        )
    if total_min < 150:
        return CoachSuggestion(
            tag="exercise", title="조금만 더 움직여봐요",
            body=f"이번 주 {total_min}분 운동했어요. 주 150분을 목표로 가볍게 더해봐요.",
        )
    return CoachSuggestion(
        tag="exercise", title="운동량이 충분해요",
        body=f"이번 주 {total_min}분! 권장 운동량을 잘 채우고 있어요. 멋져요!",
    )


def _hydration_suggestion(db: Session, user_id: str) -> CoachSuggestion:
    """수분 제안 — 오늘 나트륨/시간대 기반 간단 규칙(고정 문구 대체).

    RAG/LLM 전까지 규칙 기반으로 개인화한다: 나트륨이 높으면 배출을 위해 물을
    더 권하고, 그렇지 않으면 시간대에 맞춰 다르게 안내한다.
    """
    today = datetime.now().strftime("%Y-%m-%d")
    total_na = sum(
        r.sodium_mg for r in db.scalars(
            select(DietEntry).where(DietEntry.user_id == user_id)
            .where(DietEntry.date == today)
        ).all()
    )
    if total_na > 2000:
        return CoachSuggestion(
            tag="hydration", title="물을 더 챙기세요",
            body=(
                f"오늘 나트륨이 {total_na}mg으로 높아요. "
                "물을 충분히 마시면 나트륨 배출에 도움이 됩니다."
            ),
        )
    hour = datetime.now().hour
    if hour < 11:
        body = "아침 물 한 잔으로 하루를 시작해 보세요. 하루 6~8잔이 목표예요."
    elif hour < 18:
        body = "지금까지 물을 얼마나 드셨나요? 틈틈이 마셔 6~8잔을 채워요."
    else:
        body = "오늘 물 6~8잔을 채웠는지 확인해요. 자기 전 과한 수분은 피하세요."
    return CoachSuggestion(
        tag="hydration", title="수분 섭취 잊지 마세요", body=body,
    )


def build_feedback(db: Session, user_id: str, user_name: str) -> AiCoachFeedback:
    """
    도메인별 코치를 각각 호출해 합친다.

    STEP 7: 식단·운동 코치는 RAG 기반(domain_coaches)으로 동작.
    RAG 가 불가(키 미설정/자료 없음)하면 내부에서 STEP 6 규칙 기반으로 자동 폴백.
    """
    hour = datetime.now().hour
    if hour < 11:
        greeting = f"{user_name}님, 좋은 아침이에요! 오늘도 건강하게 시작해봐요."
    elif hour < 18:
        greeting = f"{user_name}님, 오늘 하루도 잘 보내고 계신가요?"
    else:
        greeting = f"{user_name}님, 오늘 하루 어떠셨나요? 마무리도 건강하게요."

    # 지연 import (순환 참조 방지: domain_coaches 가 coach_service 를 import)
    from app.services.coach.domain_coaches import diet_coach, exercise_coach

    suggestions = [
        diet_coach(db, user_id),       # 식단 RAG 코치 (실패 시 규칙 폴백)
        exercise_coach(db, user_id),   # 운동 RAG 코치 (실패 시 규칙 폴백)
        _hydration_suggestion(db, user_id),  # 나트륨/시간대 기반 수분 제안
    ]
    return AiCoachFeedback(greeting=greeting, suggestions=suggestions)
