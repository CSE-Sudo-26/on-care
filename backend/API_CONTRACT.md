# On-Care 백엔드 API 계약 명세 (STEP 0)

> 이 문서는 **프론트엔드(Flutter)의 `LocalApiInterceptor` 를 정답으로 삼아** 역으로 추출한
> 백엔드 API 계약입니다. 백엔드는 이 명세에 맞춰 구현합니다.
> 출처: `frontend/flutter/lib/core/network/interceptors/local_api_interceptor.dart`,
> `core/storage/app_database.dart`, `core/network/case_mapper.dart`, `app_config.dart`

## 공통 규약

- **Base URL**: 빌드 타임 `API_BASE_URL` 로 주입. 경로에 `/api` prefix 없음.
- **버전**: `/version` 이 `api_version: "v1"` 반환 → 실제 서버는 **`/v1` prefix** 사용 가정.
  (프론트 base URL 에 `/v1` 을 포함시키거나 서버가 `/v1` 라우터를 둠. 본 백엔드는 **`/v1` prefix** 채택.)
- **JSON 표기**: **snake_case** (Pydantic alias 규약). 프론트의 case_mapper 가 camelCase 로 변환.
- **인증**: `Authorization: Bearer <token>` (JWT). auth_interceptor 가 Stage 4에서 부착 예정.
- **에러**: `{ "code": "...", "message": "..." }` 형태. 4xx/5xx 는 DioException 으로 처리됨.
- **사용자 id**: **문자열** (`"user-demo"`). 정수 아님.

## 프론트에 실제 구현된 엔드포인트 (이번에 완성할 대상)

### 시스템

| Method | Path | 응답 |
|---|---|---|
| GET | `/ping` | `{ message }` |
| GET | `/healthz` | `{ status, backend }` |
| GET | `/version` | `{ api_version, app_version }` |

### 사용자

| Method | Path | 응답 핵심 필드 |
|---|---|---|
| GET | `/users/me` | `{ id(str), name, email }` |
| GET | `/users/me/health` | `{ profile, risk, indicators[], activity_points, activity_rank, settings[] }` |

`indicators[]` 각 항목(kind = weight|blood-pressure|blood-sugar):
`{ kind, label, latest_value(str), unit, delta_text, improving(bool), last_7_days[float], chart_values[float], chart_min_y, chart_max_y, chart_interval, recent_records[{label,value}] }`

`risk`: `{ title, body, level(low|medium|high) }`

### 대시보드

| Method | Path | 응답 핵심 필드 |
|---|---|---|
| GET | `/dashboard/summary` | `{ indicators[], diet_entries(int), exercise_minutes, today_schedule[], week_score, week_score_delta, sodium_warning(nullable), exercise_feedback }` |

`indicators[]`: `{ label, current(float), max(int), unit, over_budget?(bool) }` — 칼로리/나트륨/당류 3종.
`current` 는 당류가 소수(17.8g)라 float. 칼로리·나트륨은 정수 값이 그대로 실린다. 목표치(`max`)는 셋 다 정수.

### 식단 (핵심: 나트륨·당류·고혈압 관점)

| Method | Path | 응답 핵심 필드 |
|---|---|---|
| GET | `/diet/days/today` | `{ entries[], total_calories, total_sodium_mg, total_sugar_g, macros, ai_coach_message }` |
| POST | `/diet/analyze` | multipart `{ image, meal_type, idempotency_key? }` → `{ entry_id, analysis }` (분석과 동시에 diet_entries 저장) |

`entries[]`: `{ id(str), meal_type(breakfast|lunch|dinner|snack), time_label, foods[], total_calories(int), sodium_mg(int), sugar_g(float) }`
당류만 소수다 — 항목 단위 당류가 6.3g·8.5g 처럼 소수로 들어오고 합계도 절삭 없이 유지된다(`total_sugar_g` 도 float).
`foods[]`: `[{ name, calories }]` (drift 주석 기준)
`macros`: `{ carbs_pct, protein_pct, fat_pct }`
`idempotency_key`(선택): 재시도 중복 저장 방지. 클라 요청당 1회 생성해 재시도 시 재사용하면, 서버는 (user_id, key) 유니크 제약으로 같은 키의 재요청에 대해 **인식·저장을 건너뛰고 기존 entry 를 반환**한다(중복 기록·RAG 재적재 없음).

### 운동

| Method | Path | 응답 핵심 필드 |
|---|---|---|
| GET | `/exercise/weeks/current` | `{ sessions[], daily_minutes[7], daily_calories[7], cardio_minutes[7], strength_minutes[7], stretching_minutes[7], day_labels[7], total_minutes, total_calories, streak_days, ai_coach_message }` |
| POST | `/exercise/sessions` | 입력 `{ type, minutes(>0), calories, intensity(light\|moderate\|high), day_label? }` → 생성된 `sessions[]` 항목 |
| PUT | `/exercise/sessions/{id}` | 입력 동일(부분 갱신) → 갱신된 항목 |

`sessions[]`: `{ id(str), day_label, type(cardio|strength|yoga|walking), minutes, calories, intensity(light|moderate|high), date_label, time_label, items[str] }`
`intensity`: 생략 시 `moderate`. 수정 시트가 저장된 강도로 복원되고 칼로리 추정 배수(0.85/1.0/1.2)의 근거가 된다.
`day_labels`: `["월","화","수","목","금","토","일"]`
`daily_calories`: 요일별 소모 칼로리(합 = `total_calories`). 홈 '주간 추이' 차트가 이 시리즈를 읽으며, 비어 있으면 클라이언트가 데모 상수로 폴백한다.

### 일정 (캘린더 상세 CRUD)

| Method | Path | 응답 |
|---|---|---|
| GET | `/schedule/events?date=YYYY-MM-DD` | `[{ id, date, time, title, category, emoji, color_hex }]` (배열) |
| GET | `/schedule/events?month=YYYY-MM` | 그 달 전체(캘린더 뷰) |
| GET | `/schedule/events/{id}` | 단건(없으면 404) |
| POST | `/schedule/events` | 입력 `{ date, time?, title, category, emoji?, color_hex? }` → 생성 항목 |
| PUT | `/schedule/events/{id}` | 부분 수정(본인 소유만, 아니면 404) |
| DELETE | `/schedule/events/{id}` | 삭제 → `{ status: "deleted" }` |

category: hospital|exercise|meal|medication|other
- **검증**: `date`(YYYY-MM-DD)·`month`(YYYY-MM)·`time`(HH:MM 또는 빈값)·`color_hex`(#RGB/#RRGGBB)는
  형식 위반 시 **422**. 특히 `month`는 미검증 시 `month=%` 같은 값이 LIKE 와일드카드로 새므로 필수.

### 알림 (액션)

| Method | Path | 응답 |
|---|---|---|
| GET | `/notifications` | `[{ id, title, body, category, read(bool), created_at(ISO), time_ago }]` (배열, 최신순) |
| GET | `/notifications/unread-count` | `{ unread(int) }` |
| POST | `/notifications/{id}/read` | 단건 읽음 → `{ id, read: true }` |
| POST | `/notifications/read-all` | 전체 읽음 → `{ marked_read(int) }` |
| DELETE | `/notifications/{id}` | 삭제 → `{ status: "deleted" }` |

category: reminder|health_check|achievement|system

### AI 코치

| Method | Path | 응답 |
|---|---|---|
| GET | `/ai-coach/feedback` | `{ greeting, suggestions[{ tag, title, body }] }` |

tag: diet|exercise|hydration|...

### 바이탈 (체중/혈압/혈당)

| Method | Path | 본문/응답 |
|---|---|---|
| POST | `/vitals/weight` | body: `{ ...value, recorded_at? }` → `{ id, kind, value, recorded_at }` |
| POST | `/vitals/blood-pressure` | 〃 (value 예: `{systolic, diastolic}`) |
| POST | `/vitals/blood-sugar` | 〃 (value 예: `{mg_per_dl}`) |
| GET | `/vitals/{kind}/latest` | `{ id, kind, value, recorded_at }` 또는 `{}` (데이터 없음) |

value 예시(drift 주석): weight `{kg}`, blood-pressure `{systolic, diastolic}`, blood-sugar `{mg_per_dl}`

### 장소 (온오프라인 연결, O2O)

| Method | Path | 응답 |
|---|---|---|
| GET | `/places/nearby?lat=&lng=&category=&radius_m=` | `[{ id, name, category, address, distance_meters, lat, lng }]` (거리순 배열) |

category: medical|fitness|healthy_food|pharmacy (생략 가능)
- **공급자**: `places_provider` 설정에 따라 **카카오 Local 실검색**(서버가 키를 쥐고 프록시,
  60초 TTL 캐시) 또는 **시드 폴백**. 키가 없거나 호출 실패 시 자동으로 시드로 폴백.
- **무카테고리**: `category` 생략 시 네 카테고리를 **모두 검색·병합**하고 각 결과를 해당
  카테고리로 태깅한다(공급자 간 의미 일치, 빈 category 없음).
- **검증**: `lat`(-90~90)·`lng`(-180~180)·`category`(허용값)는 위반 시 **422**.

### 트레이너 디렉터리 (회원앱 탐색)

| Method | Path | 응답 |
|---|---|---|
| GET | `/trainers` | `[{ id, gym_id, name, role, reason, career, intro, certifications[] }]` |
| GET | `/trainers/recommended` | 같은 형태 — 홈·운동 탭 추천 레일 |
| GET | `/trainers/{trainer_id}` | 단건(없으면 404) |

- **노출 조건**: 소속(`gym_id`)이 있고 그 장소가 `category='fitness'` 인 트레이너만. 상담 요청 시의 대상 검증과 같은 조건이라, 목록에 뜬 트레이너는 상담을 걸 수 있다. (#451)
- **`/trainers/recommended` 순서**: 회원마다 다르다. 회원의 만성질환(`conditions`)·목표(`goals`)·가장 최근 상담의 `exercise_goal`·내 헬스장(`MemberGym`)을 신호로 점수를 매겨 내림차순 정렬한다. 동점은 경력 → id 로 갈라 같은 회원이 새로고침해도 순서가 흔들리지 않는다. (#500)
- **신호가 없는 회원**(온보딩 전 등)은 운영자가 `recommend_reason` 을 적어 둔 트레이너만 **기존 순서 그대로** 받는다. 빈 목록을 주지 않는다.
- **`reason`**: 운영자가 쓴 `recommend_reason` 이 우선이고, 비어 있을 때만 점수 근거에서 만든 문구가 채워진다(예: `회원님이 다니는 헬스장 소속 · 체중 감량 지도 경험`).

### 트레이너 도메인 / 회원측 코치 미러

트레이너 앱 백엔드(`/v1/trainer/*`)와 회원측 "내 담당 코치" 미러(`/v1/me/coach/*`),
그리고 트레이너↔회원 **실데이터 공유** 설계는 별도 문서로 분리했다:
**[`docs/TRAINER_DOMAIN.md`](docs/TRAINER_DOMAIN.md)**.

핵심: `users.role`(member|trainer)로 두 앱 계정을 구분하되, "고객"은 실제 회원 User이고
트레이너 API는 회원의 실제 `diet_entries`·`routine_history`를 그대로 읽어 집계한다.

---

## 인증 관련 메모

- 프론트는 `Authorization: Bearer` 를 쓰지만, 로그인 UI/토큰 저장은 **Stage 4 예정**(아직 미구현).
- 따라서 이번 백엔드는 로그인 엔드포인트(`/auth/login` 등)를 **제공은 하되**,
  프론트 계약상의 데이터 엔드포인트(`/users/me` 등)는 **토큰이 있으면 그 사용자, 없으면 데모 사용자**로
  동작하도록 설계(프론트가 mock→실서버 전환 시 점진 연동 가능).
- test user 시드는 유지하되 **id 를 문자열**로 운용(`user-demo` 호환).

## 도메인 핵심 (놓치면 안 되는 차별점)

On-Care 는 **고혈압·당뇨 위험군 특화**다. 식단은 칼로리뿐 아니라 **나트륨(sodium_mg)·당류(sugar_g)**
가 1급 지표다. Gemini 식단 분석 프롬프트도 **DASH 식단/고혈압 관점**(기존 PoC 의 프롬프트)을 반영한다.
