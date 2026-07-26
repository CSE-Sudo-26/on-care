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

`indicators[]`: `{ label, current(int), max(int), unit, over_budget?(bool) }` — 칼로리/나트륨/당류 3종.

### 식단 (핵심: 나트륨·당류·고혈압 관점)
| Method | Path | 응답 핵심 필드 |
|---|---|---|
| GET | `/diet/days/today` | `{ entries[], total_calories, total_sodium_mg, total_sugar_g, macros, ai_coach_message }` |
| POST | `/diet/analyze` | multipart `{ image, meal_type, idempotency_key? }` → `{ entry_id, analysis }` (분석과 동시에 diet_entries 저장) |

`entries[]`: `{ id(str), meal_type(breakfast|lunch|dinner|snack), time_label, foods[], total_calories, sodium_mg, sugar_g }`
`foods[]`: `[{ name, calories }]` (drift 주석 기준)
`macros`: `{ carbs_pct, protein_pct, fat_pct }`
`idempotency_key`(선택): 재시도 중복 저장 방지. 클라 요청당 1회 생성해 재시도 시 재사용하면, 서버는 (user_id, key) 유니크 제약으로 같은 키의 재요청에 대해 **인식·저장을 건너뛰고 기존 entry 를 반환**한다(중복 기록·RAG 재적재 없음).

### 운동
| Method | Path | 응답 핵심 필드 |
|---|---|---|
| GET | `/exercise/weeks/current` | `{ sessions[], daily_minutes[7], cardio_minutes[7], strength_minutes[7], stretching_minutes[7], day_labels[7], total_minutes, total_calories, streak_days, ai_coach_message }` |
| POST | `/exercise/sessions` | 입력 `{ type, minutes(>0), calories, intensity(light\|moderate\|high), day_label? }` → 생성된 `sessions[]` 항목 |
| PUT | `/exercise/sessions/{id}` | 입력 동일(부분 갱신) → 갱신된 항목 |

`sessions[]`: `{ id(str), day_label, type(cardio|strength|yoga|walking), minutes, calories, intensity(light|moderate|high), date_label, time_label, items[str] }`
`intensity`: 생략 시 `moderate`. 수정 시트가 저장된 강도로 복원되고 칼로리 추정 배수(0.85/1.0/1.2)의 근거가 된다.
`day_labels`: `["월","화","수","목","금","토","일"]`

### 일정
| Method | Path | 응답 |
|---|---|---|
| GET | `/schedule/events?date=YYYY-MM-DD` | `[{ id, date, time, title, category, emoji, color_hex }]` (배열) |

category: hospital|exercise|meal|medication|other

### 알림
| Method | Path | 응답 |
|---|---|---|
| GET | `/notifications` | `[{ id, title, body, category, read(bool), created_at(ISO), time_ago }]` (배열, 최신순) |

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

### 장소 (온오프라인 연결)
| Method | Path | 응답 |
|---|---|---|
| GET | `/places/nearby` | `[{ id, name, category, address, distance_meters, lat, lng }]` (배열) |

category: medical|fitness|healthy_food|pharmacy

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
