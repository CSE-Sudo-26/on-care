"""트레이너 → 회원 담당 요청(#919).

상담 요청(`consultation_service`)의 반대 방향이다. 센터에서 먼저 등록·결제를
마친 회원을 트레이너가 콘솔에서 잡을 수 있어야 하는데, 지금까지 담당 관계가
생기는 경로는 회원이 상담을 요청하고 트레이너가 수락하는 하나뿐이었다.

**담당은 회원이 수락해야 생긴다.** 트레이너가 명단에 곧바로 밀어 넣지 않는 것은
담당 관계가 상대의 식단·건강 기록을 여는 권한이기 때문이다 — 한쪽이 일방적으로
만들 수 있으면 그 권한이 동의 없이 열린다. 그래서 이 모듈이 만드는 것은 링크가
아니라 **요청**이고, 링크를 만드는 것은 회원의 [accept] 뿐이다.

수락의 뒷정리(휴면 링크 되살리기·헬스장 연결·회원당 활성 담당 1명)는 상담 수락과
같은 규칙을 따른다. 두 경로가 같은 불변식을 지켜야 하므로 그 판단을
[consultation_service] 에서 가져다 쓴다 — 규칙을 복사하면 한쪽만 고쳐지는 날이
온다.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.models import (
    Notification,
    TrainerClient,
    TrainerClientInvite,
    TrainerProfile,
    User,
)
from app.schemas.trainer_api import (
    MemberLookupOut,
    TrainerClientInviteOut,
    MemberClientInviteOut,
)
from app.services import consultation_service, notification_service


class InviteError(Exception):
    """이 모듈이 화면에 그대로 전할 수 있는 실패."""


class MemberNotFound(InviteError):
    """그 이메일의 회원이 없다."""


class NotAMember(InviteError):
    """트레이너 계정에는 담당 요청을 보낼 수 없다."""


class MemberAlreadyCoached(InviteError):
    """이미 담당 트레이너가 있는 회원이다."""


class DuplicatePendingInvite(InviteError):
    """이미 보낸 요청이 대기 중이다."""


class InviteNotFound(InviteError):
    """없거나 남의 요청이다."""


class InviteAlreadyDecided(InviteError):
    """이미 처리된 요청이다."""


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _active_trainer_id(db: Session, member_id: str) -> str | None:
    return db.scalar(
        select(TrainerClient.trainer_id).where(
            TrainerClient.member_id == member_id,
            TrainerClient.active.is_(True),
        )
    )


def lookup_member(db: Session, trainer_id: str, member_id: str) -> MemberLookupOut:
    """회원 ID **완전 일치**로 회원 한 명을 찾는다.

    이메일 대신 회원 ID(=`User.id`, 회원 앱 MY 탭의 "내 회원 ID")를 쓰는
    이유는 두 가지다. 이메일은 개인정보라 회원이 트레이너에게 공유하길 꺼릴 수
    있고, 성별·나이 같은 인적 사항으로 찾게 하면 동명이인·오입력을 트레이너가
    가려낼 수 없다. 이미 회원마다 고유한 `User.id` 가 있으므로 새 식별자 체계를
    만들지 않고 그걸 그대로 쓴다.

    부분 일치나 이름 검색을 두지 않는 것은 의도다. 트레이너가 이름 몇 글자로
    회원 명부를 훑을 수 있으면, 담당도 아닌 사람들의 존재가 드러난다. 완전
    일치는 "이미 그 회원의 ID를 알고 있다"는 뜻이라 새로 새는 정보가 없다.

    돌려주는 값도 요청을 보낼지 판단할 만큼만이다 — 이름, 이미 담당이 있는지,
    내가 보낸 요청이 대기 중인지. 성별·나이 등 신체 정보는 담당이 성립한
    뒤에만 조회된다(`/trainer/clients/{id}/health-profile`) — 여기서는 주지
    않는다.
    """
    normalized = member_id.strip().lower()
    member = db.scalar(
        select(User).where(func.lower(User.id) == normalized)
    )
    if member is None:
        raise MemberNotFound("그 회원 ID를 쓰는 회원을 찾지 못했어요.")
    if member.role != "member":
        raise NotAMember("트레이너 계정에는 담당 요청을 보낼 수 없어요.")

    current = _active_trainer_id(db, member.id)
    pending = db.scalar(
        select(TrainerClientInvite.id).where(
            TrainerClientInvite.trainer_id == trainer_id,
            TrainerClientInvite.member_id == member.id,
            TrainerClientInvite.status == "pending",
        )
    )
    return MemberLookupOut(
        member_id=member.id,
        name=member.name,
        email=member.email,
        # 누가 담당인지까지는 밝히지 않는다. 요청을 보낼 수 있는지만 알면 된다.
        has_trainer=current is not None,
        coached_by_me=current == trainer_id,
        invite_pending=pending is not None,
    )


def invite(
    db: Session, trainer_id: str, member_id: str, message: str | None
) -> TrainerClientInviteOut:
    """담당 요청을 보낸다. 링크는 만들지 않는다.

    이미 담당이 있는 회원은 여기서 막는다. 회원당 활성 담당은 1명이라, 보내 봐야
    수락할 수 없는 요청이 회원 앱에 쌓일 뿐이다.
    """
    member = db.get(User, member_id)
    if member is None:
        raise MemberNotFound("회원을 찾지 못했어요.")
    if member.role != "member":
        raise NotAMember("트레이너 계정에는 담당 요청을 보낼 수 없어요.")

    current = _active_trainer_id(db, member_id)
    if current == trainer_id:
        raise MemberAlreadyCoached("이미 담당하고 있는 회원이에요.")
    if current is not None:
        raise MemberAlreadyCoached("이미 다른 트레이너가 담당 중인 회원이에요.")

    row = TrainerClientInvite(
        id=f"tci-{uuid.uuid4().hex[:12]}",
        trainer_id=trainer_id,
        member_id=member_id,
        message=(message or "").strip() or None,
        status="pending",
    )
    db.add(row)
    _notify_member(db, row)
    try:
        db.commit()
    except IntegrityError:
        # 부분 유니크(대기 중일 때만)에 걸린 경우다 — 두 번 누른 것과 구분되지
        # 않으므로, 화면이 "이미 보냈어요" 로 읽을 수 있는 실패로 옮긴다.
        db.rollback()
        raise DuplicatePendingInvite("이미 보낸 요청이 기다리고 있어요.") from None
    db.refresh(row)
    return _to_trainer_out(db, [row])[0]


def list_sent(db: Session, trainer_id: str, status: str = "pending") -> list[TrainerClientInviteOut]:
    """내가 보낸 요청. `status='all'` 이면 처리된 것까지."""
    query = select(TrainerClientInvite).where(
        TrainerClientInvite.trainer_id == trainer_id
    )
    if status != "all":
        query = query.where(TrainerClientInvite.status == status)
    rows = list(
        db.scalars(query.order_by(TrainerClientInvite.created_at.desc())).all()
    )
    return _to_trainer_out(db, rows)


def cancel(db: Session, trainer_id: str, invite_id: str) -> None:
    """보낸 요청을 거둬들인다. 대기 중인 것만."""
    row = db.get(TrainerClientInvite, invite_id)
    if row is None or row.trainer_id != trainer_id:
        # 남의 요청도 여기로 온다 — 존재조차 드러내지 않는다.
        raise InviteNotFound("요청을 찾지 못했어요.")
    if row.status != "pending":
        raise InviteAlreadyDecided("이미 처리된 요청이에요.")
    row.status = "cancelled"
    row.decided_at = _now()
    db.commit()


def list_for_member(db: Session, member_id: str) -> list[MemberClientInviteOut]:
    """나에게 온 대기 중인 담당 요청."""
    rows = list(
        db.scalars(
            select(TrainerClientInvite)
            .where(
                TrainerClientInvite.member_id == member_id,
                TrainerClientInvite.status == "pending",
            )
            .order_by(TrainerClientInvite.created_at.desc())
        ).all()
    )
    return _to_member_out(db, rows)


class DataSharingConsentRequired(Exception):
    """동의 없이 담당 요청을 수락하려 했다. (#1022)"""


def accept(
    db: Session,
    member_id: str,
    invite_id: str,
    *,
    data_sharing_consent: bool = False,
) -> MemberClientInviteOut:
    """회원이 수락한다 — 담당 링크가 **여기서** 생긴다.

    상태 전이·링크 생성·헬스장 연결·알림을 한 트랜잭션으로 커밋한다. 나눠 커밋하면
    수락 표시만 남고 담당은 안 생긴 반쪽 상태가 만들어진다(상담 수락과 같은 이유).

    수락하는 사이에 다른 트레이너의 담당이 생겼으면 [MemberAlreadyCoached] 다.
    회원당 활성 담당 1명이라는 불변식을 IntegrityError 로 만나기 전에 막는다.
    """
    if not data_sharing_consent:
        # 수락하는 순간 트레이너가 회원의 식단·운동·신체 정보를 읽는다. 동의를
        # 받지 않고 그 문을 열 수는 없다. (#1022)
        raise DataSharingConsentRequired(
            "식단·운동 기록 공유에 동의해야 담당 요청을 수락할 수 있습니다."
        )

    row = _require_member_row(db, member_id, invite_id)

    existing = db.scalar(
        select(TrainerClient).where(
            TrainerClient.member_id == member_id,
            TrainerClient.active.is_(True),
        )
    )
    if existing is not None and existing.trainer_id != row.trainer_id:
        raise MemberAlreadyCoached("이미 다른 트레이너가 담당 중이에요.")

    if existing is None:
        consultation_service.attach_member_to_trainer(
            db,
            row.trainer_id,
            member_id,
            consented_at=_now(),
        )
    consultation_service.link_member_gym(
        db, member_id, consultation_service.trainer_gym_id(db, row.trainer_id)
    )

    row.status = "accepted"
    row.decided_at = _now()

    member_name = db.scalar(select(User.name).where(User.id == member_id)) or "회원"
    notification_service.queue_for_trainer(
        db,
        trainer_id=row.trainer_id,
        kind=notification_service.TRAINER_CONSULTATION_KIND,
        title="담당 요청이 수락되었어요",
        body=f"{member_name} 회원이 담당으로 연결되었어요.",
    )
    db.commit()
    db.refresh(row)
    return _to_member_out(db, [row])[0]


def reject(db: Session, member_id: str, invite_id: str) -> MemberClientInviteOut:
    """회원이 거절한다. 링크는 만들지 않는다."""
    row = _require_member_row(db, member_id, invite_id)
    row.status = "rejected"
    row.decided_at = _now()

    member_name = db.scalar(select(User.name).where(User.id == member_id)) or "회원"
    notification_service.queue_for_trainer(
        db,
        trainer_id=row.trainer_id,
        kind=notification_service.TRAINER_CONSULTATION_KIND,
        title="담당 요청이 거절되었어요",
        body=f"{member_name} 회원이 담당 요청을 거절했어요.",
    )
    db.commit()
    db.refresh(row)
    return _to_member_out(db, [row])[0]


def _require_member_row(
    db: Session, member_id: str, invite_id: str
) -> TrainerClientInvite:
    row = db.get(TrainerClientInvite, invite_id)
    if row is None or row.member_id != member_id:
        raise InviteNotFound("요청을 찾지 못했어요.")
    if row.status != "pending":
        raise InviteAlreadyDecided("이미 처리된 요청이에요.")
    return row


def _notify_member(db: Session, row: TrainerClientInvite) -> None:
    """요청이 왔다고 회원에게 남긴다(커밋은 호출자가 한다).

    수신 설정을 보지 않는 것은 상담 결과 알림과 같은 이유다 — 나에게 온 담당
    요청은 끌 수 있는 알림이 아니다. 알림이 없으면 회원은 트레이너가 요청을
    보냈다는 사실 자체를 알 길이 없다.
    """
    trainer_name = (
        db.scalar(select(User.name).where(User.id == row.trainer_id)) or "트레이너"
    )
    db.add(
        Notification(
            id=f"noti-{uuid.uuid4().hex[:12]}",
            user_id=row.member_id,
            title="담당 요청이 도착했어요",
            body=f"{trainer_name} 트레이너가 담당 코치가 되기를 요청했어요.",
            category=notification_service.MEMBER_CONSULTATION,
            read=False,
        )
    )


def _trainer_labels(db: Session, rows: list[TrainerClientInvite]) -> dict[str, tuple[str, str]]:
    """요청에 붙일 트레이너 이름·소속. 한 번에 모아 읽어 N+1 을 피한다."""
    ids = {row.trainer_id for row in rows}
    if not ids:
        return {}
    names = {
        user.id: user.name
        for user in db.scalars(select(User).where(User.id.in_(ids))).all()
    }
    gyms = {
        profile.trainer_id: (profile.gym_name or "")
        for profile in db.scalars(
            select(TrainerProfile).where(TrainerProfile.trainer_id.in_(ids))
        ).all()
    }
    return {tid: (names.get(tid, "트레이너"), gyms.get(tid, "")) for tid in ids}


def _to_trainer_out(
    db: Session, rows: list[TrainerClientInvite]
) -> list[TrainerClientInviteOut]:
    ids = {row.member_id for row in rows}
    members = (
        {
            user.id: user
            for user in db.scalars(select(User).where(User.id.in_(ids))).all()
        }
        if ids
        else {}
    )
    out: list[TrainerClientInviteOut] = []
    for row in rows:
        member = members.get(row.member_id)
        out.append(
            TrainerClientInviteOut(
                id=row.id,
                member_id=row.member_id,
                member_name=member.name if member else "회원",
                member_email=member.email if member else "",
                message=row.message,
                status=row.status,
                created_at=row.created_at,
                decided_at=row.decided_at,
            )
        )
    return out


def _to_member_out(
    db: Session, rows: list[TrainerClientInvite]
) -> list[MemberClientInviteOut]:
    labels = _trainer_labels(db, rows)
    out: list[MemberClientInviteOut] = []
    for row in rows:
        name, gym = labels.get(row.trainer_id, ("트레이너", ""))
        out.append(
            MemberClientInviteOut(
                id=row.id,
                trainer_id=row.trainer_id,
                trainer_name=name,
                gym_name=gym or None,
                message=row.message,
                status=row.status,
                created_at=row.created_at,
            )
        )
    return out
