"""
ORM 모델 — 프론트 계약(LocalApiInterceptor + drift 스키마)에 맞춤.

핵심 정렬 사항:
- 사용자 id 는 문자열(예: 'user-demo')
- 식단은 나트륨(sodium_mg)·당류(sugar_g)를 1급 지표로 (고혈압·당뇨 특화)
- vitals 는 kind(weight|blood-pressure|blood-sugar) + value(JSON)
- drift 테이블(diet_entries, exercise_sessions, schedule_events, notifications)과 1:1 대응

이번 STEP 1 에서는 테이블 생성만 검증하고, 살은 이후 STEP 에서 채웁니다.
"""
from __future__ import annotations

from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    Boolean, DateTime, Float, ForeignKey, Index, Integer, String, Text, UniqueConstraint,
    func, text,
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
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    health_profile: Mapped["HealthProfile | None"] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )


class HealthProfile(Base):
    """건강 위험 정보 — /users/me/health 의 risk + 메타."""
    __tablename__ = "health_profiles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)

    risk_title: Mapped[str] = mapped_column(String(200), default="")
    risk_body: Mapped[str] = mapped_column(Text, default="")
    risk_level: Mapped[str] = mapped_column(String(20), default="low")  # low|medium|high
    conditions: Mapped[str] = mapped_column(Text, default="")  # "고혈압, 당뇨 전단계"
    goals: Mapped[str] = mapped_column(Text, default="")

    # 개인정보(내 프로필 모달) + 온보딩 인구통계
    phone: Mapped[str] = mapped_column(String(20), default="")
    birth_date: Mapped[str] = mapped_column(String(10), default="")   # YYYY-MM-DD
    gender: Mapped[str] = mapped_column(String(10), default="")       # male|female|other
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)

    # 건강 목표(건강 목표 모달)
    goal_weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    goal_bp_systolic: Mapped[int | None] = mapped_column(Integer, nullable=True)
    goal_blood_sugar: Mapped[int | None] = mapped_column(Integer, nullable=True)
    daily_calories: Mapped[int | None] = mapped_column(Integer, nullable=True)
    daily_sodium_mg: Mapped[int | None] = mapped_column(Integer, nullable=True)
    daily_sugar_g: Mapped[int | None] = mapped_column(Integer, nullable=True)

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
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    date: Mapped[str] = mapped_column(String(10), index=True)  # YYYY-MM-DD
    meal_type: Mapped[str] = mapped_column(String(20))  # breakfast|lunch|dinner|snack
    time_label: Mapped[str] = mapped_column(String(10), default="")
    foods_json: Mapped[str] = mapped_column(Text, default="[]")  # [{name, calories}]
    total_calories: Mapped[int] = mapped_column(Integer, default=0)
    carbs_g: Mapped[float] = mapped_column(Float, default=0.0)
    protein_g: Mapped[float] = mapped_column(Float, default=0.0)
    fat_g: Mapped[float] = mapped_column(Float, default=0.0)
    sodium_mg: Mapped[int] = mapped_column(Integer, default=0)
    sugar_g: Mapped[int] = mapped_column(Integer, default=0)
    engine: Mapped[str] = mapped_column(String(20), default="")  # 인식 엔진(gemini|yolo)
    # 재시도 중복 저장 방지용 멱등키(클라 요청당 1회 생성). NULL 허용 → 기존/무키 요청은 제약 밖.
    idempotency_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("user_id", "idempotency_key", name="uq_diet_entries_user_idem"),
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
    category: Mapped[str] = mapped_column(String(30), default="")  # 밥류|국·찌개류|구이류...
    serving_size_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    calories: Mapped[float] = mapped_column(Float, default=0)      # kcal / 1인분
    sodium_mg: Mapped[float] = mapped_column(Float, default=0)     # mg  / 1인분
    sugar_g: Mapped[float] = mapped_column(Float, default=0)       # g   / 1인분
    carbs_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    protein_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    fat_g: Mapped[float | None] = mapped_column(Float, nullable=True)
    source: Mapped[str] = mapped_column(String(20), default="mfds")  # 데이터 출처(식약처=mfds)


class ExerciseSession(Base):
    """운동 기록 — drift ExerciseSessions 대응."""
    __tablename__ = "exercise_sessions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    week_start: Mapped[str] = mapped_column(String(10), index=True)  # 월요일 YYYY-MM-DD
    day_label: Mapped[str] = mapped_column(String(4))  # 월/화/...
    type: Mapped[str] = mapped_column(String(20))  # cardio|strength|yoga|walking
    minutes: Mapped[int] = mapped_column(Integer, default=0)
    calories: Mapped[int] = mapped_column(Integer, default=0)
    # 운동 강도 — 칼로리 추정 배수의 근거이자 수정 시트 복원 값. light|moderate|high
    intensity: Mapped[str] = mapped_column(String(20), default="moderate", server_default="moderate")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Vital(Base):
    """체중/혈압/혈당 — drift Vitals 대응."""
    __tablename__ = "vitals"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(20), index=True)  # weight|blood-pressure|blood-sugar
    value_json: Mapped[str] = mapped_column(Text, default="{}")
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ScheduleEvent(Base):
    """일정 — drift ScheduleEvents 대응."""
    __tablename__ = "schedule_events"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    date: Mapped[str] = mapped_column(String(10), index=True)
    time: Mapped[str] = mapped_column(String(10), default="")
    title: Mapped[str] = mapped_column(String(200))
    category: Mapped[str] = mapped_column(String(20))  # hospital|exercise|meal|medication|other
    emoji: Mapped[str] = mapped_column(String(10), default="")
    color_hex: Mapped[str] = mapped_column(String(10), default="#E0F2F7")


class Notification(Base):
    """알림 — drift NotificationItems 대응."""
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(String(20))  # reminder|health_check|achievement|system
    read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


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
    title: Mapped[str] = mapped_column(String(300), default="")
    content: Mapped[str] = mapped_column(Text)
    embedding: Mapped[list[float] | None] = mapped_column(Vector(EMBED_DIM), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SocialAccount(Base):
    """소셜 로그인 연결 — 한 사용자에 여러 provider 를 붙일 수 있다.

    (provider, provider_user_id) 는 유일. 소셜 로그인 시 이 조합으로 사용자를 찾고,
    없으면 (이메일이 같은 기존 사용자에 연결하거나) 새 사용자를 만든다.
    """
    __tablename__ = "social_accounts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(20), index=True)  # kakao|google|naver|apple
    provider_user_id: Mapped[str] = mapped_column(String(128))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("provider", "provider_user_id", name="uq_social_provider_uid"),
    )


class Place(Base):
    """온오프라인 연결: 장소 — /places/nearby. 카카오맵 연동 자리."""
    __tablename__ = "places"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    category: Mapped[str] = mapped_column(String(30))  # medical|fitness|healthy_food|pharmacy
    address: Mapped[str] = mapped_column(String(300), default="")
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    kakao_place_id: Mapped[str] = mapped_column(String(50), default="")


#
# ---------------------------------------------------------------------------
# 트레이너 도메인 — 트레이너↔회원 데이터 공유의 뼈대.
#
# 핵심 설계(진짜 공유): "고객"은 별도 복제 테이블이 아니라 실제 회원 User 다.
# TrainerClient 링크로 트레이너와 회원을 잇고, 트레이너가 보는 고객 식단/운동/
# 바이탈은 회원이 회원 앱에서 직접 남긴 그 레코드(DietEntry/ExerciseSession/Vital)
# 를 읽는다. 아래 테이블은 "공유되는 상호작용"(루틴 배정·완료기록·채팅·스케줄)만
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
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True
    )
    phone: Mapped[str] = mapped_column(String(20), default="")
    specialty: Mapped[str] = mapped_column(String(50), default="")     # 퍼스널 트레이너
    career_years: Mapped[int] = mapped_column(Integer, default=0)       # 7 → "7년"
    intro: Mapped[str] = mapped_column(Text, default="")
    certifications_json: Mapped[str] = mapped_column(Text, default="[]")  # ["생활스포츠지도사 2급", ...]
    gym_name: Mapped[str] = mapped_column(String(100), default="")
    gym_address: Mapped[str] = mapped_column(String(300), default="")
    gym_hours: Mapped[str] = mapped_column(String(50), default="")
    gym_phone: Mapped[str] = mapped_column(String(20), default="")
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
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
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("trainer_id", "member_id", name="uq_trainer_client"),
        # 회원당 active 담당은 최대 1명(휴면 링크는 과거 이력으로 여러 개 허용).
        Index(
            "uq_trainer_client_active_member", "member_id",
            unique=True, postgresql_where=text("active"),
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
    type: Mapped[str] = mapped_column(String(20))       # 유산소|근력|스트레칭
    reason: Mapped[str] = mapped_column(String(200), default="")
    source: Mapped[str] = mapped_column(String(20), default="ai")  # ai|trainer
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


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
    kind_label: Mapped[str] = mapped_column(String(50), default="")  # 'PT 세션 · 트레이너 지도'
    completion_rate: Mapped[int] = mapped_column(Integer, default=0)  # 0..100
    exercises_json: Mapped[str] = mapped_column(Text, default="[]")   # ["레그프레스 3세트", ...]
    client_feedback: Mapped[str] = mapped_column(Text, default="")
    trainer_note: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


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
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
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
    client_name: Mapped[str] = mapped_column(String(100), default="")  # 표시용(상담/신규 포함)
    type: Mapped[str] = mapped_column(String(30), default="")  # 1:1 PT|상담|...
    duration_minutes: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(10), default="예정")  # 예정|완료|공백
    note: Mapped[str] = mapped_column(Text, default="")
    program_json: Mapped[str] = mapped_column(Text, default="[]")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


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
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
