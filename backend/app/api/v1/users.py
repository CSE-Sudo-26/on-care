"""
사용자 라우터 — 프론트 계약 정렬.

  GET  /users/me           -> { id, name, email }
  GET  /users/me/health    -> { profile, risk, activity_points, activity_rank, settings[] }
  POST /auth/login         -> { access_token, token_type }   (Stage 4 대비)
  POST /auth/register      -> { id, name, email }             (Stage 4 대비)

데이터 엔드포인트(/users/me*)는 토큰 없으면 데모 사용자로 동작.
"""
from __future__ import annotations

import uuid
from typing import Annotated

import jwt
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser, RequireMember
from app.core.rate_limit import rate_limit
from app.services.audit import client_ip, record as audit
from app.core.security import (
    create_access_token, create_refresh_token, decode_refresh_token,
    hash_password, verify_password,
)
from app.db.session import get_db
from app.models.models import HealthProfile, User
from app.schemas.user import (
    HealthGoalsUpdate, HealthProfileBrief, OnboardingRequest, ProfileUpdate,
    ProfileView, RefreshRequest, RiskInfo, SettingItem, Token, TrainerRegister,
    UserHealth, UserMe, UserRegister,
)
from app.services import reservation_service, trainer_signup_service
from app.services.health_service import DEMO_SETTINGS

router = APIRouter(tags=["users"])


@router.get("/users/me", response_model=UserMe)
def get_me(current_user: CurrentUser) -> UserMe:
    return UserMe(id=current_user.id, name=current_user.name, email=current_user.email)


@router.get("/users/me/health", response_model=UserHealth)
def get_my_health(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> UserHealth:
    profile = current_user.health_profile

    # risk: 저장된 프로필 있으면 사용, 없으면 데모 기본값(프론트 mock 과 동일)
    if profile and profile.risk_title:
        risk = RiskInfo(title=profile.risk_title, body=profile.risk_body, level=profile.risk_level)
        points = profile.activity_points
        rank = profile.activity_rank
    else:
        risk = RiskInfo(
            title="고혈압·당뇨 위험 주의",
            body="최근 혈압과 혈당 추세가 다소 높습니다. 식단·운동 관리에 신경 써주세요.",
            level="medium",
        )
        points = 1240
        rank = 14

    return UserHealth(
        profile=HealthProfileBrief(name=current_user.name, email=current_user.email),
        risk=risk,
        activity_points=points,
        activity_rank=rank,
        settings=[SettingItem(**s) for s in DEMO_SETTINGS],
    )


# ---- 프로필 / 온보딩 / 탈퇴 ----

def _get_or_create_profile(db: Session, user: User) -> HealthProfile:
    """사용자의 HealthProfile 을 가져오거나(없으면) 생성한다."""
    profile = user.health_profile
    if profile is None:
        profile = HealthProfile(user_id=user.id)
        db.add(profile)
        db.flush()
    return profile


def _profile_view(user: User) -> ProfileView:
    p = user.health_profile
    return ProfileView(
        id=user.id,
        name=user.name,
        email=user.email,
        phone=p.phone if p else "",
        birth_date=p.birth_date if p else "",
        gender=p.gender if p else "",
        height_cm=p.height_cm if p else None,
        conditions=p.conditions if p else "",
        goals=p.goals if p else "",
        daily_calories=p.daily_calories if p else None,
        daily_sodium_mg=p.daily_sodium_mg if p else None,
        daily_sugar_g=p.daily_sugar_g if p else None,
        daily_carbs_g=p.daily_carbs_g if p else None,
        daily_protein_g=p.daily_protein_g if p else None,
        daily_fat_g=p.daily_fat_g if p else None,
        weekly_workout_goal=p.weekly_workout_goal if p else None,
        weekly_exercise_minutes_goal=(
            p.weekly_exercise_minutes_goal if p else None
        ),
        weekly_burn_goal=p.weekly_burn_goal if p else None,
        onboarded=p.onboarded if p else False,
    )


@router.get("/users/me/profile", response_model=ProfileView)
def get_my_profile(current_user: CurrentUser) -> ProfileView:
    """내 프로필 통합 뷰(인구통계·목표·온보딩 여부). 조회는 데모 폴백 허용."""
    return _profile_view(current_user)


@router.post("/users/me/onboarding", response_model=ProfileView)
def submit_onboarding(
    payload: OnboardingRequest,
    user: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> ProfileView:
    """최초 온보딩 저장. 제공된 필드만 반영하고 onboarded=True 로 표시."""
    data = payload.model_dump(exclude_unset=True)
    if "name" in data and data["name"] is not None:
        user.name = data.pop("name")
    else:
        data.pop("name", None)

    profile = _get_or_create_profile(db, user)
    for field, value in data.items():
        setattr(profile, field, value)
    profile.onboarded = True

    db.commit()
    db.refresh(user)
    return _profile_view(user)


@router.put("/users/me/health-goals", response_model=ProfileView)
def update_health_goals(
    payload: HealthGoalsUpdate,
    user: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> ProfileView:
    """건강 목표(식단 일일 6종 + 주간 운동 3종) 저장. 제공된 필드만 반영."""
    profile = _get_or_create_profile(db, user)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(profile, field, value)
    db.commit()
    db.refresh(user)
    return _profile_view(user)


@router.put("/users/me", response_model=ProfileView)
def update_me(
    payload: ProfileUpdate,
    user: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> ProfileView:
    """내 프로필 모달 저장: 이름/이메일(중복검사)/전화/생년월일."""
    data = payload.model_dump(exclude_unset=True)

    new_email = data.get("email")
    if new_email is not None and new_email != user.email:
        dup = db.scalar(select(User).where(User.email == new_email, User.id != user.id))
        if dup is not None:
            raise HTTPException(status_code=409, detail="이미 사용 중인 이메일입니다.")
        user.email = new_email
    if data.get("name") is not None:
        user.name = data["name"]

    profile = _get_or_create_profile(db, user)
    if "phone" in data and data["phone"] is not None:
        profile.phone = data["phone"]
    if "birth_date" in data and data["birth_date"] is not None:
        profile.birth_date = data["birth_date"]

    db.commit()
    db.refresh(user)
    return _profile_view(user)


@router.delete("/users/me")
def delete_me(
    user: RequireMember,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    """회원 탈퇴. 예약 좌석을 복구한 뒤 프로필·식단·운동·일정·알림·
    소셜계정·개인 코치문서를 함께 삭제한다."""
    reservation_service.cancel_member_reservations_for_account_deletion(
        db, user.id
    )
    db.delete(user)
    db.commit()
    return {"status": "deleted"}


# ---- 인증 (Stage 4 대비, 지금도 동작) ----

@router.post(
    "/auth/register",
    response_model=UserMe,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit("auth-register"))],
)
def register(
    request: Request,
    payload: UserRegister,
    db: Annotated[Session, Depends(get_db)],
) -> UserMe:
    exists = db.scalar(select(User).where(User.email == payload.email))
    if exists:
        audit(db, event="auth.register", ip=client_ip(request), success=False, detail=payload.email)
        raise HTTPException(status_code=409, detail="이미 가입된 이메일입니다.")
    user = User(
        id=f"user-{uuid.uuid4().hex[:12]}",
        email=payload.email,
        name=payload.name or payload.email.split("@")[0],
        hashed_password=hash_password(payload.password),
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="이미 가입된 이메일입니다.") from None
    db.refresh(user)
    audit(db, event="auth.register", user_id=user.id, ip=client_ip(request), success=True)
    return UserMe(id=user.id, name=user.name, email=user.email)


@router.post(
    "/auth/trainer/register",
    response_model=UserMe,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit("auth-register"))],
)
def register_trainer(
    request: Request,
    payload: TrainerRegister,
    db: Annotated[Session, Depends(get_db)],
) -> UserMe:
    """헬스장 초대 코드로 트레이너 계정을 만든다. (#475)

    `/auth/register` 와 나누는 이유: 그쪽은 `role='member'` 를 만든다. 한 엔드포인트에
    역할 분기를 넣으면 코드 없이 트레이너를 만들 수 있는 경로가 생기기 쉽다.

    코드가 소속 헬스장을 결정한다 — 소속 없는 트레이너는 상담 대상이 될 수 없어
    (#443·#451) 가입 직후 아무것도 못 하는 상태가 된다.

    회원 가입과 같은 rate limit 버킷을 쓴다. 코드를 무작위로 넣어 보는 시도도
    가입 시도이므로 같은 한도가 맞다.
    """
    try:
        trainer = trainer_signup_service.register_trainer(db, payload)
    except trainer_signup_service.InviteCodeInvalid as exc:
        audit(
            db,
            event="auth.trainer_register",
            ip=client_ip(request),
            success=False,
            detail=payload.email,
        )
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except trainer_signup_service.TrainerEmailTaken as exc:
        audit(
            db,
            event="auth.trainer_register",
            ip=client_ip(request),
            success=False,
            detail=payload.email,
        )
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    audit(
        db,
        event="auth.trainer_register",
        user_id=trainer.id,
        ip=client_ip(request),
        success=True,
    )
    return UserMe(id=trainer.id, name=trainer.name, email=trainer.email)


@router.post(
    "/auth/login",
    response_model=Token,
    dependencies=[Depends(rate_limit("auth-login"))],
)
def login(
    request: Request,
    form: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: Annotated[Session, Depends(get_db)],
) -> Token:
    user = db.scalar(select(User).where(User.email == form.username))
    if (
        not user
        or not user.is_active
        or not verify_password(form.password, user.hashed_password)
    ):
        audit(db, event="auth.login", ip=client_ip(request), success=False, detail=form.username)
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 올바르지 않습니다.")
    audit(db, event="auth.login", user_id=user.id, ip=client_ip(request), success=True)
    return Token(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post(
    "/auth/refresh",
    response_model=Token,
    dependencies=[Depends(rate_limit("auth-refresh"))],
)
def refresh(payload: RefreshRequest, db: Annotated[Session, Depends(get_db)]) -> Token:
    """refresh 토큰으로 새 access(+refresh) 토큰 발급(회전)."""
    invalid = HTTPException(status_code=401, detail="유효하지 않은 refresh 토큰입니다.")
    try:
        user_id = decode_refresh_token(payload.refresh_token)
    except jwt.InvalidTokenError:
        raise invalid
    user = db.scalar(select(User).where(User.id == user_id))
    if user is None or not user.is_active:
        raise invalid
    return Token(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )
