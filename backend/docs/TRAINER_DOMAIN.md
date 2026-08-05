# 트레이너 도메인 · 회원↔트레이너 데이터 공유

> 트레이너 앱 백엔드와 회원측 "내 담당 코치" 미러의 설계·계약 문서.
> 회원 앱 계약은 [`API_CONTRACT.md`](../API_CONTRACT.md)를, 프론트 구조는
> [`frontend/flutter/docs/STRUCTURE.md`](../../frontend/flutter/docs/STRUCTURE.md)를 참고.
>
> 대상 작업: 트레이너 도메인(#249~#253), 회원측 미러(#254), 리뷰 후속(#261).

## 1. 한 줄 요약

트레이너 앱과 회원 앱은 **완전히 분리된 계정**(`users.role = 'member' | 'trainer'`)이지만
**같은 회원 데이터를 공유**한다. "고객"은 별도 복제본이 아니라 **실제 회원 User**이며,
트레이너 API는 회원이 회원 앱에서 남긴 `DietEntry`·`RoutineHistory`를 **그대로 읽어**
로스터를 집계한다. 별도 동기화 파이프라인이 없어 데이터가 어긋날 여지가 없다.

```
회원 앱 ──기록──▶ diet_entries / routine_history ◀──조회── 트레이너 앱
                        (단일 원본, 실시간 공유)
```

## 2. 역할과 인증

- `users.role`: `member`(회원 앱) | `trainer`(트레이너 앱). 서버 기본값 `member`.
- 두 앱은 로그인 계정이 다르다. **앱 내 역할 전환 기능은 없다.**
- 인증 의존성(`app/api/deps.py`):
  - `get_current_user` — 토큰 있으면 그 사용자, 없으면 데모 회원(회원 앱 계약 유지).
    단, 비활성 계정은 기존 토큰을 포함해 401이며, **trainer 역할이 회원 데이터
    엔드포인트로 새어들지 않도록** 트레이너 계정엔 403.
  - `RequireTrainer` / `require_trainer` — 트레이너 전용 라우터 가드(회원 계정 403).
  - `RequireMember` / `require_member` — 회원 전용 라우터 가드.

## 3. 데이터 모델 (마이그레이션 `0012_trainer_domain`)

| 테이블 | 역할 |
|---|---|
| `users.role` | 계정 역할 컬럼(member\|trainer), 인덱스 |
| `trainer_profiles` | 트레이너 프로필(전문분야·경력·소속 짐) |
| `trainer_clients` | 트레이너↔회원 담당 링크(로스터의 정의) |
| `trainer_routines` | 트레이너/AI가 회원에게 배정한 루틴 |
| `routine_history` | 회원 운동 완료 기록(회원 앱·PT 세션 공용 원본) |
| `chat_messages` | 트레이너↔회원 1:1 채팅 |
| `trainer_schedule` | 트레이너 오늘 타임라인(예약→수업→기록 루프) |

### 담당 링크 제약 (`trainer_clients`)

- `UNIQUE(trainer_id, member_id)` — 같은 트레이너에 같은 회원 중복 배정 금지.
- **`UNIQUE(member_id) WHERE active`** (partial unique index
  `uq_trainer_client_active_member`) — 회원측 API가 "현재 담당 코치 **1명**"을 전제하므로,
  회원당 **active 링크는 최대 1개**로 강제한다. 휴면(`active=false`) 이력은 여러 개 허용.
  이 인덱스는 `0012` 테이블 생성을 수정하지 않고 별도 `0013_trainer_active_coach_uq`
  마이그레이션으로 추가한다(이미 `0012`가 적용된 DB 에서도 확실히 생성되도록).

> 정책이 복수 담당으로 바뀌면 이 인덱스를 제거하고 회원측 코치·채팅·루틴 API를
> **목록 기반**으로 바꿔야 한다(현재는 단일 담당 가정).

## 4. 트레이너 API (`/v1/trainer/*`, RequireTrainer)

| Method | Path | 설명 |
|---|---|---|
| GET | `/trainer/me` | 내 트레이너 프로필 |
| PUT | `/trainer/me` | 프로필 부분 수정(보낸 필드만; 이름/이메일은 계정 소관) |
| GET | `/trainer/clients` | 고객 로스터(회원 실데이터 집계) |
| GET | `/trainer/clients/{member_id}/diet?date=` | 해당 회원의 실제 식단 기록 |
| GET | `/trainer/clients/{member_id}/history` | 해당 회원 운동 기록(최신순) |
| GET | `/trainer/clients/{member_id}/routines` | 배정 루틴 |
| POST | `/trainer/clients/{member_id}/routines` | 루틴 배정 |
| GET | `/trainer/clients/{member_id}/chat?before=&before_id=` | 채팅 스레드(커서 페이지네이션) |
| POST | `/trainer/clients/{member_id}/chat` | 메시지 전송 |
| POST | `/trainer/clients/{member_id}/chat/read` | 읽음 처리 |
| GET | `/trainer/chat/unread` | 회원별 미확인 수 |
| GET | `/trainer/schedule?date=` | 오늘 타임라인 |
| GET | `/trainer/schedule/booked-dates` | 예약 있는 날짜 |
| POST | `/trainer/schedule` | 예약 생성(예정) |
| PUT | `/trainer/schedule/{id}` | 예약 수정 |
| DELETE | `/trainer/schedule/{id}` | 예약 삭제 |
| POST | `/trainer/schedule/{id}/complete` | 세션 완료(예정→완료) |
| POST | `/trainer/clients/{member_id}/ai-coach` | 담당 고객 데이터 기반 AI 코칭 질의 |
| GET | `/trainer/clients/{member_id}/report?week_start=` | 주간 리포트(어느 요일을 줘도 그 주 월요일로 정규화) |
| POST | `/trainer/clients/{member_id}/report/send` | 리포트를 회원 채팅 스레드로 전송 |

### 트레이너용 AI 코칭 (`/trainer/clients/{id}/ai-coach`)

회원 앱의 `/ai-coach/chat` 과 **같은 RAG 파이프라인**(`services/coach/chat.answer`)을
쓰되, 검색 스코프가 호출자(트레이너)가 아니라 **담당 회원**이다. 트레이너가 자기
자신의(비어 있는) 기록으로 코칭받는 일을 막기 위한 구분이며, 접근 경계는 담당 링크
확인(`_require_client`) — 남의 고객이면 404 로 존재조차 드러내지 않는다.

### 주간 리포트 (`/trainer/clients/{id}/report`)

O2O 코칭의 재등록 고리. 세션 수·완료 수는 `trainer_schedule`, 이행률은
`routine_history`, 나트륨은 `diet_entries`에서 그 주만 집계한다 — 새로 수집하는
데이터는 없다. **기록이 없는 항목은 0 이 아니라 `null`** 로 내려간다("이행률 0%"는
"안 했다"는 거짓말이 되므로). 전송은 별도 리포트 함이 아니라 **회원이 이미 읽고 있는
채팅 스레드**로 들어간다.

### 로스터 집계 (`build_roster`)

- 회원별 식단·기록과 최신 메시지·루틴을 **배치 조회**한다(N+1 방지).
  `chat_messages`·`trainer_routines`의 회원별 최신 1건은 **`DISTINCT ON (member_id)`**로 한 번에.
- `last_routine` 라벨은 `created_at`(UTC 저장)을 **시스템 로컬 시각으로 변환**해 계산한다
  (`_local_date_iso` → `astimezone().date()`). UTC `.date()`로 계산하면 자정 근처에서
  '오늘/어제'가 어긋난다. 운영은 `TZ=Asia/Seoul`.
- 채팅 스레드는 `(created_at, id)` **복합 커서**(`before`/`before_id`)로 페이지네이션 —
  같은 `created_at`이 여러 건이어도 안정적으로 끊어 읽는다.

## 5. 예약 → 수업 → 기록 루프

`trainer_schedule`의 예약을 완료하면 회원 `routine_history`로 적재되어
"트레이너가 지도한 PT 세션"이 회원 앱 운동 이력에도 나타난다(양방향 공유).

- **완료(`complete_session`)**: `예정` 슬롯만 완료 가능(공백 400, 미래 400).
  조건부 `UPDATE ... WHERE status='예정'` + `rowcount==1` 게이트로 **동시 완료 요청의
  중복 기록을 방지**. 기록 id는 슬롯 기준 결정론적(`sched-hist-{id}`)이라 재호출에도 멱등.
- **수정(`update_session`)**: `완료` 세션 수정은 **409**(기록과 스케줄이 어긋나지 않게).
  `member_id=""` 또는 명시적 `null`은 '배정 해제'로 해석해 **NULL** 저장한다.
  DB `NOT NULL`인 나머지 필드의 명시적 `null`은 요청 경계에서 **422**로 거부한다.
- **삭제(`delete_session`)**: `완료` 세션을 지우면 파생된 `sched-hist-{id}` 운동기록도
  **함께 삭제**(고아 레코드 방지 — 완료 시 적재의 역연산).

## 6. 회원측 "내 담당 코치" 미러 (`/v1/me/coach/*`, RequireMember)

트레이너가 배정한 데이터를 **회원 관점**으로 되비추는 읽기 미러 + 양방향 채팅.

| Method | Path | 설명 |
|---|---|---|
| GET | `/me/coach` | 내 담당 코치 요약(활성 담당 없으면 404) |
| GET | `/me/coach/routines` | 받은 루틴 |
| GET | `/me/coach/sessions` | 내 PT 세션(최근 100건) |
| GET | `/me/coach/chat` | 채팅 스레드 |
| GET | `/me/coach/chat/unread` | 미확인 수 |
| POST | `/me/coach/chat` | 코치에게 메시지 전송 |
| POST | `/me/coach/chat/read` | 읽음 처리 |

- 담당 코치는 **active 링크**만 인정(`get_member_trainer_id` → `active.is_(True)`).
  휴면 링크만 있으면 코치 조회/발신 불가(404/빈 목록).
- `/me/coach/sessions`는 시간이 지나며 누적되는 PT 세션을 **최근 100건**으로 상한.

## 7. 데모 시드 (`seed_trainer.py`, `seed_member_data.py`)

- 트레이너 계정 "김트레이너"(`trainer@oncare.com`) + 담당 회원 3명(김민수/이지수/박성호).
  회원 실데이터(식단·운동기록·채팅·루틴·스케줄)를 함께 시드해 **시드 단계부터 공유가 성립**.
- **멱등**: 결정론적 id + 존재 검사로 재기동에도 중복 없음. 날짜가 넘어가면 '오늘'이 새로
  시드되어 과거 데이터가 누적된다.
- **동시 기동 안전**: 시드 커밋은 `_safe_commit`으로 **UNIQUE 위반(SQLSTATE 23505)만**
  무시하고(다른 인스턴스가 먼저 넣은 경우), FK(23503)·NOT NULL(23502)·CHECK 등 **진짜
  오류는 재발생**시켜 데이터가 롤백된 채 조용히 기동되지 않게 한다.
- 이메일 충돌 등으로 회원 계정/링크가 없으면 그 회원 건강 데이터는 **건너뛴다**(FK 오류 방지).

## 8. 마이그레이션 선형화 주의

트레이너 마이그레이션은 스택이 **가장 마지막에 머지**되므로 병렬로 갈라졌던 번호를
재선형화했다: `0010_diet_entry_macros`(#207) → `0011_health_daily_sugar_g`(#230/#231)
→ **`0012_trainer_domain`**(도메인 테이블) → **`0013_trainer_active_coach_uq`**(회원당
active 담당 1명 partial unique index). 반드시 `0010`·`0011`이 main에 반영된 뒤 머지해야
alembic 단일 head가 유지된다. 자세한 배포/마이그레이션 절차는 배포 문서를 참고.
