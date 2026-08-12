"""
ORM 모델 — 프론트 계약(LocalApiInterceptor + drift 스키마)에 맞춤.

핵심 정렬 사항:
- 사용자 id 는 문자열(예: 'user-demo')
- 식단은 나트륨(sodium_mg)·당류(sugar_g)를 1급 지표로 (고혈압·당뇨 특화)
- drift 테이블(diet_entries, exercise_sessions, schedule_events, notifications)과 1:1 대응

이번 STEP 1 에서는 테이블 생성만 검증하고, 살은 이후 STEP 에서 채웁니다.
"""

from __future__ import annotations

from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    false,
    func,
    text,
    true,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.config import get_settings
from app.db.session import Base

# 임베딩 차원은 설정값에서. 모델 교체 시 .env(EMBED_DIM)만 바꾸고 재임베딩.
EMBED_DIM = get_settings().embed_dim


class User(Base):
    __tablename__ = "users"

    # 계약상 문자열 id
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100), default="")
    hashed_password: Mapped[str] = mapped_column(String(255), default="")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    # 관리자 권한(공공문서 업로드 등 민감 엔드포인트 접근). 기본 False.
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    # 계정 역할: 'member'(회원 앱) | 'trainer'(트레이너 앱). 두 앱은 완전히 분리된
    # 계정이지만 users 테이블은 공유하고 role 로 구분한다(트레이너↔회원 데이터 공유의 축).
    role: Mapped[str] = mapped_column(
        String(20), default="member", server_default="member", index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    health_profile: Mapped["HealthProfile | None"] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )


class HealthProfile(Base):
    """건강 위험 정보 — /users/me/health 의 risk + 메타."""

    __tablename__ = "health_profiles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True
    )

    risk_title: Mapped[str] = mapped_column(String(200), default="")
    risk_body: Mapped[str] = mapped_column(Text, default="")
    risk_level: Mapped[str] = mapped_column(
        String(20), default="low"
    )  # low|medium|high
    conditions: Mapped[str] = mapped_column(Text, default="")  # "고혈압, 당뇨 전단계"
    goals: Mapped[str] = mapped_column(Text, default="")

    # 개인정보(내 프로필 모달) + 온보딩 인구통계
    phone: Mapped[str] = mapped_column(String(20), default="")
    birth_date: Mapped[str] = mapped_column(String(10), default="")  # YYYY-MM-DD
    gender: Mapped[str] = mapped_column(String(10), default="")  # male|female|other
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)

    # 일일 영양 목표(식단 관리용)
    daily_calories: Mapped[int | None] = mapped_column(Integer, nullable=True)
    daily_sodium_mg: Mapped[int | None] = mapped_column(Integer, nullable=True)
    daily_sugar_g: Mapped[int | None] = mapped_column(Integer, nullable=True)
    daily_carbs_g: Mapped[int | None] = mapped_column(Integer, nullable=True)
    daily_protein_g: Mapped[int | None] = mapped_column(Integer, nullable=True)
    daily_fat_g: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # 주간 운동 목표(운동 관리용)
    weekly_workout_goal: Mapped[int | None] = mapped_column(Integer, nullable=True)
    weekly_exercise_minutes_goal: Mapped[int | None] = mapped_column(
        Integer, nullable=True
    )
    weekly_burn_goal: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # 온보딩 완료 여부(프론트 온보딩 게이팅용)
    onboarded: Mapped[bool] = mapped_column(Boolean, default=False)

    activity_points: Mapped[int] = mapped_column(Integer, default=0)
    activity_rank: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="health_profile")


class DietEntry(Base):
    """식단 기록 — drift DietEntries 대응. 나트륨·당류 포함."""

    __tablename__ = "diet_entries"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    date: Mapped[str] = mapped_column(String(10), index=True)  # YYYY-MM-DD
    meal_type: Mapped[str] = mapped_column(String(20))  # breakfast|lunch|dinner|snack
    time_label: Mapped[str] = mapped_column(String(10), default="")
    foods_json: Mapped[str] = mapped_column(Text, default="[]")  # [{name, calories}]
    total_calories: Mapped[int] = mapped_column(Integer, default=0)
    carbs_g: Mapped[float] = mapped_column(Float, default=0.0)
    protein_g: Mapped[float] = mapped_column(Float, default=0.0)
    fat_g: Mapped[float] = mapped_column(Float, default=0.0)
    sodium_mg: Mapped[int] = mapped_column(Integer, default=0)
    # 당류는 소수. 음식 단위(FoodNutrient.sugar_g)가 이미 Float 이라 항목 단위만
    # Integer 로 남아 있으면 6.3+8.5 같은 합이 절삭된다(프론트도 double 로 다룸).
    sugar_g: Mapped[float] = mapped_column(Float, default=0.0)
    engine: Mapped[str] = mapped_column(
        String(20), default=""
    )  # 인식 엔진(gemini|yolo)
    # 재시도 중복 저장 방지용 멱등키(클라 요청당 1회 생성). NULL 허용 → 기존/무키 요청은 제약 밖.
    idempotency_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id", "idempotency_key", name="uq_diet_entries_user_idem"
        ),
    )


class FoodNutrient(Base):
    """공공 식품영양성분 DB(식약처/국가표준) 큐레이션 테이블.

    Vision 인식이 준 '음식 이름'을 이 표에 매핑해 신뢰 가능한 1인분 영양가로 교체한다.
    (LLM 은 '무엇인지' 식별에 강하고, 정확한 영양 수치는 이 공공 DB 가 제공.)
    수치는 1회 제공량(serving_size_g) 기준. name_norm 은 매칭용 정규화 이름.
    """

    __tablename__ = "food_nutrients"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100), index=True)
    name_norm: Mapped[str] = mapped_column(String(100), default="", index=True)
    category: Mapped[str] = mapped_column(
        String(30), default=""
    )  # 밥류|국·찌개류|구이류...
    serving_size_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    calories: Mapped[float] = mapped_column(Float, default=0)  # kcal / 1인분
    sodium_mg: Mapped[float] = mapped_column(Float, default=0)  # mg  / 1인분
    sugar_g: Mapped[float] = mapped_column(Float, default=0)  # g   / 1인분
    carbs_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    protein_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    fat_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    source: Mapped[str] = mapped_column(
        String(20), default="mfds"
    )  # 데이터 출처(식약처=mfds)


class ExerciseSession(Base):
    """운동 기록 — drift ExerciseSessions 대응."""

    __tablename__ = "exercise_sessions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    week_start: Mapped[str] = mapped_column(String(10), index=True)  # 월요일 YYYY-MM-DD
    day_label: Mapped[str] = mapped_column(String(4))  # 월/화/...
    type: Mapped[str] = mapped_column(String(20))  # cardio|strength|yoga|walking
    minutes: Mapped[int] = mapped_column(Integer, default=0)
    calories: Mapped[int] = mapped_column(Integer, default=0)
    # 운동 강도 — 칼로리 추정 배수의 근거이자 수정 시트 복원 값. light|moderate|high
    intensity: Mapped[str] = mapped_column(
        String(20), default="moderate", server_default="moderate"
    )
    #: 이 기록을 누가 만들었나. member=회원이 직접 남김, trainer_pt=트레이너가 PT
    #: 세션을 완료 처리해 파생된 기록. 파생 기록은 근거가 트레이너에게 있어 회원이
    #: 고칠 수 없고(#499), 화면에서도 수기 기록과 구분해 보여준다.
    source: Mapped[str] = mapped_column(
        String(20), default="member", server_default="member"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ScheduleEvent(Base):
    """일정 — drift ScheduleEvents 대응."""

    __tablename__ = "schedule_events"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    date: Mapped[str] = mapped_column(String(10), index=True)
    time: Mapped[str] = mapped_column(String(10), default="")
    title: Mapped[str] = mapped_column(String(200))
    category: Mapped[str] = mapped_column(
        String(20)
    )  # hospital|exercise|meal|medication|other
    emoji: Mapped[str] = mapped_column(String(10), default="")
    color_hex: Mapped[str] = mapped_column(String(10), default="#E0F2F7")


class Notification(Base):
    """알림 — drift NotificationItems 대응."""

    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(
        String(20)
    )  # reminder|health_check|achievement|system
    read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class MemberNotificationSetting(Base):
    """회원 알림 수신 설정 — 기기가 아니라 계정 단위. (#489)

    전에는 사용자 앱이 SharedPreferences 에만 저장해 기기를 바꾸면 초기화됐고,
    무엇보다 **서버가 몰라서 알림을 만들 때 끌 수가 없었다.**

    컬럼 이름은 앱이 쓰던 키(`notif_*`)에서 접두사만 뗀 것이다. 새 이름을 만들면
    앱 화면과 대응이 흐려진다. 트레이너 쪽(`TrainerProfile.notify_*`)과 대칭이지만
    항목이 달라 테이블을 나눈다.

    행이 없으면 기본값(`notification_service.DEFAULTS`)이다 — 가입할 때마다 행을
    만들지 않아도 되고, 기본값을 바꾸면 한 번도 설정을 건드리지 않은 회원에게
    바로 적용된다.
    """
    __tablename__ = "member_notification_settings"

    member_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    diet_log: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=true(), default=True
    )
    exercise_reminder: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=true(), default=True
    )
    trainer_message: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=true(), default=True
    )
    ai_coaching: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=true(), default=True
    )
    #: 주간 리포트만 기본 꺼짐 — 앱의 현재 기본값과 같다.
    weekly_report: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=false(), default=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class CoachDocument(Base):
    """RAG 코치용 문서 + 임베딩 (STEP 7).

    두 종류의 문서가 공존:
      - 개인 문서(환자 데이터): user_id = 특정 사용자  → 그 사용자만 검색됨
      - 공공 문서(가이드라인 등): user_id = NULL        → 모든 사용자 공유

    검색 시 (user_id == 현재사용자 OR user_id IS NULL) 로 가져오면
    내 개인기록 + 공용 가이드라인만 나오고 남의 개인기록은 절대 안 섞인다.
    """

    __tablename__ = "coach_documents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # nullable: 공공 문서는 NULL(전체 공유), 개인 문서는 특정 user_id
    user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True
    )
    # 'public' | 'meal' | 'workout' | 'profile' | 'vital' ...
    source: Mapped[str] = mapped_column(String(50), default="")
    # 도메인 필터용: 'diet' | 'exercise' | 'general' (도메인별 코치가 자기 자료만 검색)
    domain: Mapped[str] = mapped_column(String(20), default="general", index=True)
    #: 이 문서를 만든 원본 기록의 id (#603). 기록을 고치면 같은 참조의 문서를 지우고
    #: 다시 적재해, 옛 수치와 새 수치가 함께 검색되는 일이 없게 한다. 공공 문서와
    #: 참조를 남기기 전에 적재된 문서는 NULL 이다.
    source_ref: Mapped[str | None] = mapped_column(
        String(64), nullable=True
    )
    title: Mapped[str] = mapped_column(String(300), default="")
    content: Mapped[str] = mapped_column(Text)
    embedding: Mapped[list[float] | None] = mapped_column(
        Vector(EMBED_DIM), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class SocialAccount(Base):
    """소셜 로그인 연결 — 한 사용자에 여러 provider 를 붙일 수 있다.

    (provider, provider_user_id) 는 유일. 소셜 로그인 시 이 조합으로 사용자를 찾고,
    없으면 (이메일이 같은 기존 사용자에 연결하거나) 새 사용자를 만든다.
    """

    __tablename__ = "social_accounts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    provider: Mapped[str] = mapped_column(
        String(20), index=True
    )  # kakao|google|naver|apple
    provider_user_id: Mapped[str] = mapped_column(String(128))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint("provider", "provider_user_id", name="uq_social_provider_uid"),
    )


class Place(Base):
    """온오프라인 연결: 장소 — /places/nearby. 카카오맵 연동 자리."""

    __tablename__ = "places"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    category: Mapped[str] = mapped_column(
        String(30)
    )  # medical|fitness|healthy_food|pharmacy
    address: Mapped[str] = mapped_column(String(300), default="")
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    kakao_place_id: Mapped[str] = mapped_column(String(50), default="")


class GymProfile(Base):
    """헬스장 부가 정보 — `places`(category='fitness') 의 1:1 확장. (#324)

    헬스장 자체는 `Place` 다. 상담 검증(`consultation_service`)과 `/places/nearby`
    가 이미 `places` 를 쓰기 때문에 별도 테이블을 만들지 않았다. 다만 평점·영업시간
    같은 헬스장 전용 값을 `places` 에 넣으면 병원·약국·건강식이 공유하는 테이블이
    오염되므로 여기로 분리한다(`TrainerProfile` 이 `User` 를 확장하는 것과 같은 꼴).
    """

    __tablename__ = "gym_profiles"

    place_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("places.id", ondelete="CASCADE"), primary_key=True
    )
    #: 카카오 Local 은 평점을 주지 않는다 — 발견된 헬스장은 None.
    rating: Mapped[float | None] = mapped_column(Float, nullable=True)
    weekday_hours: Mapped[str] = mapped_column(String(50), default="")
    weekend_hours: Mapped[str] = mapped_column(String(50), default="")
    phone: Mapped[str] = mapped_column(String(20), default="")
    tags_json: Mapped[str] = mapped_column(
        Text, default="[]"
    )  # ["다이어트", "재활운동"]
    #: 제휴 헬스장만 트레이너 연결·상담이 가능하다.
    is_partner: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=false(), default=False, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class MemberGym(Base):
    """회원↔헬스장 링크 — 회원의 '내 헬스장'. (#444)

    전에는 이 링크가 없어서 담당 트레이너의 소속(`TrainerProfile.gym_id`)에서
    파생시켰다. 그래서 트레이너만 해제해도 헬스장이 함께 사라졌다 — 앱 MY 탭은
    두 해제를 따로 제공하는데 서버가 그 구분을 표현하지 못했다.

    `TrainerClient` 와 달리 `active` 이력 컬럼이 없다. 담당 링크는 루틴·채팅·일정이
    참조해 지우면 이력이 끊기지만, 헬스장 링크를 참조하는 것은 없어 해제 시 행을
    지우면 된다. 회원당 1곳이라는 불변식은 `member_id` 를 PK 로 두어 구조로 강제한다
    (partial unique index 가 필요 없다).
    """

    __tablename__ = "member_gyms"

    member_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    #: 헬스장은 `places`(category='fitness'). 장소가 사라지면 링크도 사라진다 —
    #: gym_id 는 NOT NULL 이라 SET NULL 을 쓸 수 없고, 없어진 헬스장을 '내 헬스장'
    #: 으로 남겨 둘 이유도 없다.
    gym_id: Mapped[str] = mapped_column(
        ForeignKey("places.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ConsultationRequest(Base):
    """회원의 헬스장·트레이너 상담 요청."""

    __tablename__ = "consultation_requests"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    member_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    target_type: Mapped[str] = mapped_column(String(20))
    gym_id: Mapped[str | None] = mapped_column(
        ForeignKey("places.id", ondelete="SET NULL"), nullable=True
    )
    trainer_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    exercise_goal: Mapped[str] = mapped_column(String(30))
    health_purpose_type: Mapped[str] = mapped_column(String(30))
    health_purpose_detail: Mapped[str | None] = mapped_column(Text, nullable=True)
    preferred_date: Mapped[str] = mapped_column(String(10))
    preferred_time_slot: Mapped[str] = mapped_column(String(20))
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), default="pending", server_default="pending"
    )
    #: 처리한 트레이너. 헬스장으로 온 요청(target_type='gym')은 소속 트레이너 누구나
    #: 받을 수 있어 요청 대상(trainer_id)과 다른 값이므로 별도 컬럼이다. (#467)
    decided_by: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    #: 승인·거절 시각. updated_at 은 어떤 수정으로도 갱신되어 근거가 못 된다.
    decided_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    #: 거절 사유. 승인 시에는 비어 있다.
    decision_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    __table_args__ = (
        Index(
            "uq_consultation_requests_pending_gym",
            "member_id",
            "gym_id",
            unique=True,
            postgresql_where=text("target_type = 'gym' AND status = 'pending'"),
        ),
        Index(
            "uq_consultation_requests_pending_trainer",
            "member_id",
            "trainer_id",
            unique=True,
            postgresql_where=text("target_type = 'trainer' AND status = 'pending'"),
        ),
        Index(
            "ix_consultation_requests_member_created_at",
            "member_id",
            "created_at",
        ),
        # 트레이너 인박스의 두 경로 — 내 앞으로 온 것 / 내 헬스장으로 온 것. (#467)
        Index("ix_consultation_requests_trainer_status", "trainer_id", "status"),
        Index("ix_consultation_requests_gym_status", "gym_id", "status"),
    )


#
# ---------------------------------------------------------------------------
# 트레이너 도메인 — 트레이너↔회원 데이터 공유의 뼈대.
#
# 핵심 설계(진짜 공유): "고객"은 별도 복제 테이블이 아니라 실제 회원 User 다.
# TrainerClient 링크로 트레이너와 회원을 잇고, 트레이너가 보는 고객 식단/운동은
# 회원이 회원 앱에서 직접 남긴 그 레코드(DietEntry/ExerciseSession)를 읽는다.
# 아래 테이블은 "공유되는 상호작용"(루틴 배정·완료기록·채팅·스케줄)만
# 담는다. 응답 형태는 트레이너 프론트 drift 계약(TrainerClients/ClientAiRoutines/
# ClientRoutineHistory/ClientChatMessages/TrainerScheduleEntries)에 정렬한다.
# ---------------------------------------------------------------------------


class TrainerProfile(Base):
    """트레이너 전용 프로필 — 프론트 seedTrainerProfile / Figma MY 화면 대응.

    회원의 HealthProfile 과 별개(역할이 다른 계정). 이름/이메일은 User 에 있고,
    여기엔 전문분야·경력·자격증·소속 헬스장 정보만 둔다.
    """

    __tablename__ = "trainer_profiles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    trainer_id: Mapped[str] = mapped_column(
        # unique=True 가 이미 유니크 인덱스를 만들므로 index=True 는 잉여(중복 인덱스). 제거.
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
    )
    phone: Mapped[str] = mapped_column(String(20), default="")
    specialty: Mapped[str] = mapped_column(String(50), default="")  # 퍼스널 트레이너
    career_years: Mapped[int] = mapped_column(Integer, default=0)  # 7 → "7년"
    intro: Mapped[str] = mapped_column(Text, default="")
    certifications_json: Mapped[str] = mapped_column(
        Text, default="[]"
    )  # ["생활스포츠지도사 2급", ...]
    #: 소속 헬스장(`places.id`). 아래 gym_* 문자열 컬럼을 대신한다 — 문자열만으로는
    #: 한 헬스장에 여러 트레이너를 묶을 수 없었다(#324, #301). 트레이너 앱이 아직
    #: gym_* 를 읽으므로 두 표현이 당분간 공존하고, 값이 있으면 gym_id 가 우선이다.
    gym_id: Mapped[str | None] = mapped_column(
        String(64),
        ForeignKey("places.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    #: 추천 레일에 올릴 한 줄 사유. 빈 문자열이면 추천 대상이 아니다.
    recommend_reason: Mapped[str] = mapped_column(
        String(200), nullable=False, server_default="", default=""
    )
    gym_name: Mapped[str] = mapped_column(String(100), default="")
    gym_address: Mapped[str] = mapped_column(String(300), default="")
    gym_hours: Mapped[str] = mapped_column(String(50), default="")
    gym_phone: Mapped[str] = mapped_column(String(20), default="")
    # 알림 수신 설정(#379). 기기 로컬이 아니라 계정 단위 — 트레이너는 센터 PC 와
    # 태블릿을 오간다. 기본값은 서버가 정한다(모두 켬 / 30분 전).
    notify_new_message: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=true(), default=True
    )
    notify_session_reminder: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=true(), default=True
    )
    reminder_lead_minutes: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="30", default=30
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class TrainerInviteCode(Base):
    """헬스장이 발급하는 트레이너 가입 초대 코드. (#475)

    트레이너 계정은 시드 스크립트로만 만들 수 있었다 — `/auth/register` 는 회원
    전용이라 트레이너 앱에서 가입해도 member 계정이 생겨 `/trainer/me` 가 403 을
    돌려줬다. 그래서 트레이너 앱의 가입 진입점이 데모에서만 열려 있었다.

    코드가 **소속을 결정한다**는 점이 핵심이다. 상담 대상 트레이너에게는 소속
    헬스장이 요구되므로(#443·#451), 소속을 가입 시점에 확정하면 "가입은 됐는데
    아무것도 못 하는" 상태가 생기지 않는다. 아무나 트레이너로 가입해 회원 상담을
    받는 것도 구조로 막힌다.

    한 번 쓰면 끝이다(`used_by`). 여러 명을 받으려면 헬스장이 코드를 여러 개
    발급한다 — 사용 횟수를 세는 것보다 "누가 이 코드를 썼는지"가 남는 편이
    나중에 추적할 수 있다.
    """

    __tablename__ = "trainer_invite_codes"

    #: 사람이 옮겨 적는 값이라 코드 자체가 PK 다. 대문자·숫자만 쓰고 대소문자
    #: 구분 없이 조회한다(입력 실수를 코드 오류로 만들지 않는다).
    code: Mapped[str] = mapped_column(String(32), primary_key=True)
    gym_id: Mapped[str] = mapped_column(
        ForeignKey("places.id", ondelete="CASCADE"), index=True
    )
    #: 만료 시각. NULL 이면 만료 없음.
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    #: 이 코드로 가입한 트레이너. NULL 이면 아직 쓰이지 않았다.
    used_by: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class TrainerClient(Base):
    """트레이너↔회원 담당 링크. 트레이너의 '고객 목록'은 이 링크로 정의된다.

    goal 은 트레이너가 설정한 코칭 목표(예: '혈압 관리 · 체중 감량'). active 는
    활성/휴면. 한 회원이 한 트레이너에게 중복 배정되지 않도록 (trainer, member) 유일.
    또한 회원측 API 는 '현재 담당 코치 1명'을 전제하므로, 회원당 active 링크는 최대
    1개로 partial unique index 로 강제한다(복수 트레이너 동시 배정 방지).
    """

    __tablename__ = "trainer_clients"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    trainer_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    member_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    goal: Mapped[str] = mapped_column(String(200), default="")
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint("trainer_id", "member_id", name="uq_trainer_client"),
        # 회원당 active 담당은 최대 1명(휴면 링크는 과거 이력으로 여러 개 허용).
        Index(
            "uq_trainer_client_active_member",
            "member_id",
            unique=True,
            postgresql_where=text("active"),
        ),
    )


class TrainerRoutine(Base):
    """트레이너/AI가 회원에게 배정한 루틴 — 프론트 ClientAiRoutines 대응.

    source: 'ai'(AI 추천) | 'trainer'(트레이너 직접 배정). 회원 앱에서 '받은 루틴'
    으로도 읽힌다(양쪽에서 보이는 공유 데이터).
    """

    __tablename__ = "trainer_routines"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    trainer_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    member_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(100))
    minutes: Mapped[int] = mapped_column(Integer, default=0)
    type: Mapped[str] = mapped_column(String(20))  # 유산소|근력|스트레칭
    reason: Mapped[str] = mapped_column(String(200), default="")
    source: Mapped[str] = mapped_column(String(20), default="ai")  # ai|trainer
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    # 재전송 중복 배정 방지용 멱등키(전송 시도당 1회 생성). NULL 허용 → 기존/무키
    # 요청은 제약 밖. DietEntry.idempotency_key 와 같은 방식이다.
    client_request_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint(
            "trainer_id",
            "member_id",
            "client_request_id",
            name="uq_trainer_routines_client_request",
        ),
    )


class RoutineHistory(Base):
    """회원의 운동 완료 기록 — 프론트 ClientRoutineHistory 대응.

    회원이 자율 운동을 완료하거나(회원 앱), 트레이너가 PT 세션을 완료 처리하면
    (스케줄 완료 루프) 생성된다. date_label 은 저장하지 않고 date 로부터 파생한다.
    """

    __tablename__ = "routine_history"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    member_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    # 트레이너 지도 세션이면 트레이너, 자율 운동이면 NULL.
    trainer_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    date: Mapped[str] = mapped_column(String(10), index=True)  # YYYY-MM-DD
    kind_label: Mapped[str] = mapped_column(
        String(50), default=""
    )  # 'PT 세션 · 트레이너 지도'
    completion_rate: Mapped[int] = mapped_column(Integer, default=0)  # 0..100
    exercises_json: Mapped[str] = mapped_column(
        Text, default="[]"
    )  # ["레그프레스 3세트", ...]
    client_feedback: Mapped[str] = mapped_column(Text, default="")
    trainer_note: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ChatMessage(Base):
    """트레이너↔회원 채팅 메시지 — 프론트 ClientChatMessages 대응.

    스레드는 (trainer_id, member_id) 로 식별. sender 는 백엔드 진실값 'trainer'|'member'
    로 저장하고, 트레이너 API 응답에선 프론트 계약에 맞춰 'client' 로 노출한다.
    read_at 으로 양쪽 미확인 수를 계산.
    """

    __tablename__ = "chat_messages"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    trainer_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    member_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    sender: Mapped[str] = mapped_column(String(20))  # trainer|member
    body: Mapped[str] = mapped_column(Text)
    # 한 번의 발신 시도에 클라이언트가 붙이는 멱등키. NULL 은 기존 앱 요청이며
    # 유니크 제약 밖에 남는다. sender 까지 scope 에 넣어 양방향이 같은 문자열 키를
    # 우연히 만들어도 서로 충돌하지 않게 한다.
    client_request_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    __table_args__ = (
        UniqueConstraint(
            "trainer_id",
            "member_id",
            "sender",
            "client_request_id",
            name="uq_chat_messages_client_request",
        ),
    )


class TrainerSchedule(Base):
    """트레이너의 일일 타임라인 슬롯 — 프론트 TrainerScheduleEntries 대응.

    회원과 매칭된 슬롯은 member_id 를 갖고, 상담/신규/공백은 client_name(표시용)만
    갖는다. status: 예정|완료|공백. program_json: [{name,sets,reps,weight}].
    """

    __tablename__ = "trainer_schedule"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    trainer_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    member_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    date: Mapped[str] = mapped_column(String(10), index=True)  # YYYY-MM-DD
    time: Mapped[str] = mapped_column(String(10), default="")  # "10:00"
    client_name: Mapped[str] = mapped_column(
        String(100), default=""
    )  # 표시용(상담/신규 포함)
    type: Mapped[str] = mapped_column(String(30), default="")  # 1:1 PT|상담|...
    duration_minutes: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(10), default="예정")  # 예정|완료|공백
    note: Mapped[str] = mapped_column(Text, default="")
    program_json: Mapped[str] = mapped_column(Text, default="[]")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    # 트레이너의 예약 생성 시도 단위 멱등키. 다른 create operation 과는 테이블이
    # 달라 같은 문자열을 써도 충돌하지 않는다. NULL 은 구버전 요청 호환용이다.
    client_request_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint(
            "trainer_id",
            "client_request_id",
            name="uq_trainer_schedule_client_request",
        ),
    )


class TrainerReservationSlot(Base):
    """A trainer-owned, member-bookable calendar slot."""

    __tablename__ = "trainer_reservation_slots"
    __table_args__ = (
        CheckConstraint("capacity > 0", name="ck_reservation_slot_capacity_positive"),
        CheckConstraint(
            "remaining >= 0 AND remaining <= capacity",
            name="ck_reservation_slot_remaining_range",
        ),
        Index("ix_reservation_slots_trainer_starts", "trainer_id", "starts_at"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    trainer_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    capacity: Mapped[int] = mapped_column(Integer)
    remaining: Mapped[int] = mapped_column(Integer)
    is_closed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=false(), default=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class TrainerReservation(Base):
    """A member's persisted booking for one trainer slot."""

    __tablename__ = "trainer_reservations"
    __table_args__ = (
        UniqueConstraint("member_id", "slot_id", name="uq_reservation_member_slot"),
        Index("ix_reservations_slot_status", "slot_id", "status"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    member_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    slot_id: Mapped[str] = mapped_column(
        ForeignKey("trainer_reservation_slots.id", ondelete="RESTRICT"), index=True
    )
    schedule_id: Mapped[str] = mapped_column(
        ForeignKey("trainer_schedule.id", ondelete="RESTRICT"), unique=True
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default="booked", default="booked"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class AuditLog(Base):
    """보안 감사 로그 — 인증/관리자 이벤트 추적.

    user_id 는 FK 를 두지 않는다(사용자가 삭제돼도 감사 기록은 남아야 하므로).
    event 예: auth.login, auth.register, auth.social, admin.public_doc_upload.
    """

    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    event: Mapped[str] = mapped_column(String(50), index=True)
    user_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    ip: Mapped[str] = mapped_column(String(64), default="")
    success: Mapped[bool] = mapped_column(Boolean, default=True)
    detail: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class AiConversation(Base):
    """AI 코치(온이)와의 대화 스레드.

    앱에는 대화 목록 UI 가 없고 채팅 시트 하나만 있으므로, 사용자당 활성 스레드
    1개를 get-or-create 해서 쓴다(coach_service 참고). 나중에 스레드 목록이 필요해질
    때를 대비해 테이블은 분리해 둔다 — 그때 컬럼 추가 없이 archived_at 만 채우면 된다.

    트레이너↔회원 채팅(chat_messages)과는 다른 도메인이다. 이쪽은 사람 간 대화가
    아니라 LLM 대화라 sender 대신 role(user|coach)을 쓰고 근거 문서를 함께 남긴다.
    """

    __tablename__ = "ai_conversations"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    #: 누가 나눈 대화인가 (#588). NULL 이면 회원 본인의 대화 — 회원 앱이 읽는 것.
    #: 값이 있으면 그 트레이너가 이 회원에 대해 물어본 대화다. `user_id` 는 어느
    #: 쪽이든 **검색 스코프**(누구 기록을 근거로 삼는가)라 항상 회원이다.
    trainer_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=True
    )
    #: 비우면 활성 스레드. 값이 있으면 보관된 스레드(현재는 쓰지 않음).
    archived_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # NULL 은 일반 UNIQUE 에서 서로 다른 값으로 취급된다. 회원 본인 스레드와
    # 트레이너별 스레드를 별도 부분 인덱스로 묶어 활성 대화를 하나만 허용한다.
    __table_args__ = (
        Index(
            "uq_ai_conversations_active_member",
            "user_id",
            unique=True,
            postgresql_where=text("archived_at IS NULL AND trainer_id IS NULL"),
        ),
        Index(
            "uq_ai_conversations_active_trainer",
            "user_id",
            "trainer_id",
            unique=True,
            postgresql_where=text("archived_at IS NULL AND trainer_id IS NOT NULL"),
        ),
    )


class AiMessage(Base):
    """AI 코치 대화의 한 줄.

    `sources_json` 은 그 답변의 근거로 쓰인 공공 가이드라인 제목들이다. 답변과 함께
    저장해야 대화를 복원했을 때도 근거 표시가 남는다(재접속 시 근거가 사라지면
    "왜 이렇게 답했는지"를 되짚을 수 없다).
    """

    __tablename__ = "ai_messages"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    conversation_id: Mapped[str] = mapped_column(
        ForeignKey("ai_conversations.id", ondelete="CASCADE"), index=True
    )
    #: 대화 내 순번(0부터). created_at 으로 정렬하면 안 되기 때문에 둔다 —
    #: PostgreSQL 의 now() 는 트랜잭션 시각이라 같은 커밋에 저장되는 질문과 답변이
    #: **동일한 created_at** 을 갖고, 그러면 정렬이 랜덤한 id 순으로 무너져 답변이
    #: 질문보다 먼저 보인다(실제로 그렇게 나왔다).
    seq: Mapped[int] = mapped_column(Integer, default=0)
    role: Mapped[str] = mapped_column(String(10))  # user|coach
    content: Mapped[str] = mapped_column(Text)
    sources_json: Mapped[str] = mapped_column(Text, default="[]")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint("conversation_id", "seq", name="uq_ai_messages_convo_seq"),
    )
