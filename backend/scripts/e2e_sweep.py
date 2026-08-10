"""회원↔트레이너 전 경로를 실 API 로 훑어 끊긴 곳을 찾는다 (#479).

단위 테스트는 각 조각이 도는 것만 보증한다. 이 스크립트는 **두 역할이 같은 DB 를
사이에 두고 실제로 이어지는지** 를 본다 — 회원이 남긴 것이 트레이너에게 보이고,
트레이너가 한 일이 회원에게 돌아오는지.

전 항목을 손으로 밟지 않는 이유는 재현 때문이다. 여기서 걸린 것만 화면으로 확인하면
된다(#479 의 검증 방법 참고).

사용법 (backend/ 디렉터리에서, 로컬 스택이 떠 있는 상태):
  docker compose up -d
  python -m scripts.e2e_sweep
  python -m scripts.e2e_sweep --base http://localhost:8000/v1

만든 것은 모두 되돌린다 — 식단·운동 세션은 DELETE, 건강 목표는 원래 값으로 복구,
채팅과 거기서 파생된 개인 RAG 문서(#580)는 DB 에서 제거(둘 다 삭제 API 가 없다).
그래서 몇 번을 돌려도 데모 DB 가 그대로다. 정리에 실패하면 조용히 넘어가지 않고
FAIL 로 보고한다. DB 정리는 로컬 DATABASE_URL 을 쓰므로, --allow-remote 로 원격을
때리면 채팅과 RAG 문서는 남는다.

AI 코칭·루틴 경로는 다루지 않는다. 키가 없으면 규칙 폴백이 200 을 돌려주어 통과처럼
보이기 때문이다(#579 수정 후 #589 에서 검증).
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

DEFAULT_BASE = "http://localhost:8000/v1"
DEMO_PASSWORD = "oncare123"
MEMBER_EMAIL = "jisu@oncare.com"
MEMBER_ID = "user-jisu"
TRAINER_EMAIL = "trainer@oncare.com"
LOCAL_HOSTS = ("localhost", "127.0.0.1", "[::1]", "host.docker.internal")

_JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF e2e-sweep"
_BOUNDARY = "----e2esweep"

# 실행마다 다른 키를 쓴다. 고정 키면 정리(DELETE)가 실패했을 때 다음 실행이 기존
# 엔트리를 그대로 돌려받아(find_by_idempotency), 식단이 안 늘어난 것처럼 보인다.
_RUN_TAG = str(int(time.time()))
_MARKER = "e2e-sweep-" + _RUN_TAG


class Result:
    """시나리오 하나의 결과. 실패는 '무엇이 기대와 달랐는지'까지 남긴다."""

    def __init__(self, group: str, name: str, status: str, detail: str = "") -> None:
        self.group = group
        self.name = name
        self.status = status  # PASS | FAIL | SKIP
        self.detail = detail


class Api:
    def __init__(self, base: str) -> None:
        self.base = base.rstrip("/")

    def _call(
        self,
        method: str,
        path: str,
        *,
        token: str | None = None,
        json_body: Any = None,
        form: dict[str, str] | None = None,
        multipart: tuple[str, bytes, str] | None = None,
    ) -> tuple[int, Any]:
        url = f"{self.base}{path}"
        data: bytes | None = None
        headers: dict[str, str] = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        if json_body is not None:
            data = json.dumps(json_body, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        elif form is not None:
            data = urllib.parse.urlencode(form).encode("utf-8")
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        elif multipart is not None:
            field, blob, extra = multipart
            body = (
                f"--{_BOUNDARY}\r\n"
                f'Content-Disposition: form-data; name="{field}"; filename="meal.jpg"\r\n'
                "Content-Type: image/jpeg\r\n\r\n"
            ).encode() + blob + f"\r\n{extra}--{_BOUNDARY}--\r\n".encode()
            data = body
            headers["Content-Type"] = f"multipart/form-data; boundary={_BOUNDARY}"

        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as res:
                raw = res.read().decode("utf-8")
                return res.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                return e.code, json.loads(raw)
            except json.JSONDecodeError:
                return e.code, raw
        except Exception as e:  # noqa: BLE001 — 연결 실패도 결과로 보고한다
            return 0, str(e)

    def get(self, path, **kw):
        return self._call("GET", path, **kw)

    def post(self, path, **kw):
        return self._call("POST", path, **kw)

    def put(self, path, **kw):
        return self._call("PUT", path, **kw)

    def delete(self, path, **kw):
        return self._call("DELETE", path, **kw)

    def login(self, email: str) -> str | None:
        code, body = self.post(
            "/auth/login", form={"username": email, "password": DEMO_PASSWORD}
        )
        if code == 200 and isinstance(body, dict):
            return body.get("access_token")
        return None


def multipart_fields(pairs: dict[str, str]) -> str:
    out = ""
    for k, v in pairs.items():
        out += (
            f"--{_BOUNDARY}\r\n"
            f'Content-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'
        )
    return out

# ─────────────────────────────────────────────── 시나리오 ──


def scenario_auth(api: Api, m: str, t: str, out: list[Result]) -> None:
    g = "인증·계정"
    code, _ = api.get("/users/me", token=m)
    out.append(Result(g, "회원 /users/me", "PASS" if code == 200 else "FAIL", str(code)))

    code, _ = api.get("/users/me/health", token=m)
    out.append(Result(g, "건강정보 조회", "PASS" if code == 200 else "FAIL", str(code)))

    # 목표는 PUT 전용이라 GET 이 없지만 /users/me/profile 이 같은 값을 노출한다.
    # 원래 값을 먼저 읽어 두고 끝나면 되돌린다 — 스윕이 데모 DB 를 바꿔 놓으면
    # 반복 실행할수록 시연 데이터가 실제와 어긋난다.
    _, profile = api.get("/users/me/profile", token=m)
    original = profile.get("daily_calories") if isinstance(profile, dict) else None
    probe = 1800 if original != 1800 else 1900

    code, _ = api.put(
        "/users/me/health-goals", token=m, json_body={"daily_calories": probe}
    )
    _, after = api.get("/users/me/profile", token=m)
    saved = after.get("daily_calories") if isinstance(after, dict) else None
    dash_code, _ = api.get("/dashboard/summary", token=m)
    ok = code in (200, 201) and saved == probe and dash_code == 200
    out.append(Result(
        g, "건강 목표 저장", "PASS" if ok else "FAIL",
        f"{code} daily_calories -> {saved} (기대 {probe})",
    ))

    code, _ = api.put(
        "/users/me/health-goals", token=m, json_body={"daily_calories": original}
    )
    _, restored = api.get("/users/me/profile", token=m)
    back = restored.get("daily_calories") if isinstance(restored, dict) else None
    out.append(Result(
        g, "건강 목표 원복(정리)", "PASS" if back == original else "FAIL",
        f"{back} (원래 {original})",
    ))

    code, _ = api.get("/trainer/me", token=t)
    out.append(Result(g, "트레이너 /trainer/me", "PASS" if code == 200 else "FAIL", str(code)))

    # 권한: 회원 토큰으로 트레이너 API 는 막혀야 한다
    code, _ = api.get("/trainer/clients", token=m)
    out.append(Result(
        g, "회원 토큰으로 트레이너 API 차단",
        "PASS" if code in (401, 403) else "FAIL", f"{code} (401/403 기대)",
    ))


def scenario_diet(api: Api, m: str, t: str, out: list[Result]) -> None:
    from datetime import date

    g = "식단"
    code, before = api.get("/trainer/clients/" + MEMBER_ID + "/diet", token=t)
    n_before = len(before) if code == 200 and isinstance(before, list) else -1

    code, body = api.post(
        "/diet/analyze",
        token=m,
        multipart=("image", _JPEG, multipart_fields(
            {"meal_type": "dinner", "idempotency_key": _MARKER}
        )),
    )
    out.append(Result(g, "사진 업로드·분석", "PASS" if code == 200 else "FAIL", str(code)))
    entry_id = body.get("entry_id") if code == 200 and isinstance(body, dict) else None

    code, day = api.get("/diet/days/today", token=m)
    entries = (day or {}).get("entries", []) if isinstance(day, dict) else []
    has = code == 200 and any(e.get("id") == entry_id for e in entries)
    out.append(Result(g, "오늘 식단에 반영", "PASS" if has else "FAIL", str(code)))

    # #516 이 구현한 일별 복원 — 실 API 기준으로 다시 확인
    code, _ = api.get("/diet/days/" + date.today().isoformat(), token=m)
    out.append(Result(g, "일별 복원 /diet/days/{date}", "PASS" if code == 200 else "FAIL", str(code)))

    code, after = api.get("/trainer/clients/" + MEMBER_ID + "/diet", token=t)
    n_after = len(after) if code == 200 and isinstance(after, list) else -1
    grew = n_before >= 0 and n_after > n_before
    out.append(Result(
        g, "회원 식단 → 트레이너 화면", "PASS" if grew else "FAIL", f"{n_before} -> {n_after}",
    ))

    # 정리는 조용히 건너뛰면 안 된다. 남은 엔트리는 시드 개수를 단언하는 pytest 를
    # 깨뜨리므로(docs/local_fullstack.md '알려진 함정'), 못 지웠으면 FAIL 로 알린다.
    if entry_id:
        code, _ = api.delete("/diet/entries/" + entry_id, token=m)
        out.append(Result(g, "식단 삭제(정리)", "PASS" if code in (200, 204) else "FAIL", str(code)))
    else:
        out.append(Result(g, "식단 삭제(정리)", "FAIL", "entry_id 를 못 받아 정리 못 함"))


def _db_session():
    """로컬 DB 세션. reembed.py 와 같은 방식이며, 열 수 없으면 사유를 돌려준다."""
    try:
        from app.db.session import SessionLocal
    except Exception as e:  # noqa: BLE001 - 임포트 실패도 결과로 보고한다
        return None, f"임포트 실패: {e!r}"
    try:
        return SessionLocal(), ""
    except Exception as e:  # noqa: BLE001
        return None, repr(e)


def latest_document_id() -> tuple[int, str]:
    """개인 RAG 문서의 현재 최대 id. 이후 생긴 문서를 가려내는 기준선이다."""
    db, err = _db_session()
    if db is None:
        return -1, err
    try:
        from sqlalchemy import func, select

        from app.models.models import CoachDocument

        return int(db.execute(select(func.coalesce(func.max(CoachDocument.id), 0))).scalar_one()), ""
    except Exception as e:  # noqa: BLE001
        return -1, repr(e)
    finally:
        db.close()


def purge_sweep_traces(marker: str, doc_baseline: int) -> tuple[int, int, str]:
    """스윕이 남긴 채팅과 그로부터 파생된 개인 RAG 문서를 지운다.

    채팅에는 삭제 API 가 없다(coach/trainer 라우터 모두 GET·POST 뿐). 게다가 #580
    이후 식단·채팅이 개인 RAG 문서로 적재되므로(personal_ingest), 원본을 지워도
    문서는 남아 AI 코칭 근거를 오염시킨다. 문서 본문에는 마커가 없는 것도 있어
    (식단 문서는 분석 결과 그대로다) 문자열이 아니라 **실행 전 최대 id** 를
    기준으로 그 뒤에 생긴 회원 문서를 지운다. 적재 경로가 늘어도 그대로 걸린다.

    원격 대상(--allow-remote)은 로컬 DATABASE_URL 과 다르므로 지울 수 없다.
    """
    db, err = _db_session()
    if db is None:
        return -1, -1, err
    try:
        from sqlalchemy import delete

        from app.models.models import ChatMessage, CoachDocument

        chats = db.execute(
            delete(ChatMessage).where(ChatMessage.body.like("%" + marker + "%"))
        ).rowcount or 0
        docs = 0
        if doc_baseline >= 0:
            docs = db.execute(
                delete(CoachDocument).where(
                    CoachDocument.user_id == MEMBER_ID,
                    CoachDocument.id > doc_baseline,
                )
            ).rowcount or 0
        db.commit()
        return chats, docs, ""
    except Exception as e:  # noqa: BLE001
        return -1, -1, repr(e)
    finally:
        db.close()


def scenario_chat(api: Api, m: str, t: str, out: list[Result]) -> None:
    g = "채팅"
    from_member = "e2e sweep from member " + _MARKER
    from_trainer = "e2e sweep from trainer " + _MARKER

    code, _ = api.post("/me/coach/chat", token=m, json_body={"text": from_member})
    out.append(Result(g, "회원 발신", "PASS" if code in (200, 201) else "FAIL", str(code)))

    code, msgs = api.get("/trainer/clients/" + MEMBER_ID + "/chat", token=t)
    items = msgs if isinstance(msgs, list) else (msgs or {}).get("messages", [])
    seen = code == 200 and any(from_member in (x.get("body") or "") for x in items)
    out.append(Result(g, "트레이너 수신", "PASS" if seen else "FAIL", str(code)))

    code, _ = api.post(
        "/trainer/clients/" + MEMBER_ID + "/chat", token=t,
        json_body={"text": from_trainer},
    )
    out.append(Result(g, "트레이너 발신", "PASS" if code in (200, 201) else "FAIL", str(code)))

    code, msgs = api.get("/me/coach/chat", token=m)
    items = msgs if isinstance(msgs, list) else (msgs or {}).get("messages", [])
    seen = code == 200 and any(from_trainer in (x.get("body") or "") for x in items)
    out.append(Result(g, "회원 수신", "PASS" if seen else "FAIL", str(code)))

    code, _ = api.get("/me/coach/chat/unread", token=m)
    out.append(Result(g, "회원 미읽음 수", "PASS" if code == 200 else "FAIL", str(code)))

    code, _ = api.get("/trainer/chat/unread", token=t)
    out.append(Result(g, "트레이너 미읽음 수", "PASS" if code == 200 else "FAIL", str(code)))


def scenario_roster(api: Api, m: str, t: str, out: list[Result]) -> None:
    g = "트레이너 로스터·고객 상세"
    code, rows = api.get("/trainer/clients", token=t)
    n = len(rows) if isinstance(rows, list) else 0
    out.append(Result(g, "고객 목록", "PASS" if code == 200 else "FAIL", f"{code} n={n}"))

    for path, label in (
        ("/diet", "고객 식단"),
        ("/history", "고객 운동 이력"),
        ("/routines", "고객 루틴"),
        ("/report", "고객 리포트"),
    ):
        code, _ = api.get("/trainer/clients/" + MEMBER_ID + path, token=t)
        out.append(Result(g, label, "PASS" if code == 200 else "FAIL", str(code)))


def scenario_exercise(api: Api, m: str, t: str, out: list[Result]) -> None:
    g = "운동"
    code, week_before = api.get("/exercise/weeks/current", token=m)
    out.append(Result(g, "주간 조회", "PASS" if code == 200 else "FAIL", str(code)))

    code, created = api.post(
        "/exercise/sessions",
        token=m,
        json_body={"type": "cardio", "intensity": "moderate", "minutes": 30, "calories": 210},
    )
    out.append(Result(g, "세션 저장", "PASS" if code in (200, 201) else "FAIL", str(code)))
    session_id = created.get("id") if isinstance(created, dict) else None

    # 응답 전체를 비교하면 '무언가 바뀌었다' 밖에 못 본다. 방금 넣은 30분·210kcal 이
    # 그대로 더해졌는지 집계 필드로 확인해야 실제로 반영된 것이다.
    code, week_after = api.get("/exercise/weeks/current", token=m)
    before_min = (week_before or {}).get("total_minutes") if isinstance(week_before, dict) else None
    after_min = (week_after or {}).get("total_minutes") if isinstance(week_after, dict) else None
    delta = (after_min - before_min) if isinstance(before_min, int) and isinstance(after_min, int) else None
    out.append(Result(
        g, "주간 집계에 반영", "PASS" if delta == 30 else "FAIL",
        f"{code} total_minutes {before_min} -> {after_min} (+30 기대)",
    ))

    # 트레이너가 회원 운동 이력을 읽는 경로
    code, _ = api.get("/trainer/clients/" + MEMBER_ID + "/history", token=t)
    out.append(Result(g, "트레이너가 운동 이력 조회", "PASS" if code == 200 else "FAIL", str(code)))

    if session_id:
        code, _ = api.delete("/exercise/sessions/" + session_id, token=m)
        out.append(Result(g, "세션 삭제(정리)", "PASS" if code in (200, 204) else "FAIL", str(code)))
    else:
        out.append(Result(g, "세션 삭제(정리)", "FAIL", "id 를 못 받아 정리 못 함"))


def scenario_reservation(api: Api, m: str, t: str, out: list[Result]) -> None:
    g = "예약·일정"
    for path, tok, label in (
        ("/reservations/me", m, "내 예약"),
        ("/schedule/events", m, "회원 일정"),
        ("/trainer/schedule", t, "트레이너 일정"),
        ("/trainer/reservation-slots", t, "트레이너 슬롯 관리"),
        ("/trainer/schedule/booked-dates", t, "예약된 날짜"),
    ):
        code, _ = api.get(path, token=tok)
        out.append(Result(g, label, "PASS" if code == 200 else "FAIL", str(code)))


def scenario_consultation(api: Api, m: str, t: str, out: list[Result]) -> None:
    g = "상담"
    for path, tok, label in (
        ("/consultations/me", m, "회원 상담 내역"),
        ("/trainer/consultations", t, "트레이너 상담 목록"),
        ("/trainer/consultations/pending-count", t, "대기 건수"),
    ):
        code, _ = api.get(path, token=tok)
        out.append(Result(g, label, "PASS" if code == 200 else "FAIL", str(code)))


def scenario_misc(api: Api, m: str, t: str, out: list[Result]) -> None:
    g = "회원 화면"
    for path, label in (
        ("/dashboard/summary", "홈 대시보드"),
        ("/exercise/weeks/current", "운동 주간"),
        ("/notifications", "알림함"),
        ("/me/coach", "담당 코치"),
        ("/me/coach/routines", "배정 루틴"),
        ("/me/coach/sessions", "PT 세션"),
        ("/diet/recommendations", "식단 추천"),
        ("/trainers/recommended", "추천 트레이너"),
        ("/gyms", "헬스장"),
    ):
        code, _ = api.get(path, token=m)
        out.append(Result(g, label, "PASS" if code == 200 else "FAIL", str(code)))

    g2 = "트레이너 화면"
    for path, label in (
        ("/trainer/notifications", "알림함"),
        ("/trainer/notifications/unread-count", "미읽음 수"),
        ("/trainer/me/settings", "설정"),
    ):
        code, _ = api.get(path, token=t)
        out.append(Result(g2, label, "PASS" if code == 200 else "FAIL", str(code)))


def is_local(base: str) -> bool:
    host = urllib.parse.urlsplit(base).hostname or ""
    return host in LOCAL_HOSTS or host.endswith(".localhost")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=DEFAULT_BASE)
    ap.add_argument(
        "--allow-remote",
        action="store_true",
        help="로컬이 아닌 --base 를 허용한다(데이터를 쓰고 지우므로 기본은 거부).",
    )
    args = ap.parse_args()

    # 이 스크립트는 읽기만 하지 않는다. 식단·운동 세션·채팅을 만들고 DELETE 까지 한다.
    # 배포 환경을 실수로 가리키면 실제 사용자 데이터를 건드리므로 기본은 로컬만 허용.
    if not is_local(args.base) and not args.allow_remote:
        print("거부: " + args.base + " 은 로컬이 아닙니다.")
        print("  이 스크립트는 식단/운동/채팅을 생성하고 삭제합니다.")
        print("  정말 이 대상에 쓰려면 --allow-remote 를 붙이세요.")
        return 2

    api = Api(args.base)
    member = api.login(MEMBER_EMAIL)
    trainer = api.login(TRAINER_EMAIL)
    if not member or not trainer:
        print("로그인 실패 - 백엔드가 " + args.base + " 에 떠 있는지 확인하세요.")
        print("  member=" + str(bool(member)) + " trainer=" + str(bool(trainer)))
        return 2

    # 시나리오가 만든 개인 RAG 문서를 가려내려면 시작 전 기준선이 필요하다.
    doc_baseline, base_err = latest_document_id()

    out: list[Result] = []
    for fn in (
        scenario_auth, scenario_diet, scenario_exercise, scenario_chat,
        scenario_roster, scenario_reservation, scenario_consultation,
        scenario_misc,
    ):
        try:
            fn(api, member, trainer, out)
        except Exception as e:  # noqa: BLE001 - 한 그룹이 죽어도 나머지는 계속
            out.append(Result(fn.__name__, "실행 중 예외", "FAIL", repr(e)))

    # 채팅 2건과, 식단·채팅이 파생시킨 개인 RAG 문서 3건(식단 1 + 채팅 2)을 지운다.
    g = "정리"
    chats, docs, err = purge_sweep_traces(_MARKER, doc_baseline)
    out.append(Result(
        g, "채팅 삭제", "PASS" if chats == 2 else "FAIL",
        f"{chats}건 (2건 기대)" + (" - " + err if err else ""),
    ))
    out.append(Result(
        g, "개인 RAG 문서 삭제", "PASS" if docs == 3 else "FAIL",
        f"{docs}건 (3건 기대)" + (" - " + (err or base_err) if (err or base_err) else ""),
    ))

    group = None
    for r in out:
        if r.group != group:
            group = r.group
            print("")
            print("[" + group + "]")
        print("  " + r.status.ljust(4) + " " + r.name.ljust(30) + " " + r.detail)

    failed = [r for r in out if r.status == "FAIL"]
    print("")
    print("총 " + str(len(out)) + "건 · 통과 " + str(len(out) - len(failed))
          + " · 실패 " + str(len(failed)))
    if failed:
        print("")
        print("실패 목록 (화면 확인 대상):")
        for r in failed:
            print("  - [" + r.group + "] " + r.name + " - " + r.detail)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
