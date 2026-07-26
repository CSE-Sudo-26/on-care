# oncare-trainer

On-Care **트레이너 전용 앱**입니다. [On-Care Figma 트레이너 목업](../../docs)을 기준으로
사용자 앱([frontend/flutter](../flutter))과 **완전히 분리된 코드베이스**로 구현했습니다
(아키텍처 패턴만 미러링, `package:oncare` import 0건 — 계정도 별도).

> 현재 상태: **트레이너 MVP + 웹 와이드 레이아웃/스케줄·프로그램 관리** —
> 인증 + 4탭(고객/스케줄/AI루틴/MY) 전부 실제 화면, 와이드 뷰포트 마스터-디테일,
> 스케줄 CRUD·AI 루틴의 스케줄 등록까지. 백엔드 미연결(drift 로컬 DB mock), 웹 1차 타깃

## 아키텍처 방향 (하이브리드)

| 대상 | 플랫폼 |
| --- | --- |
| 일반 회원 | 네이티브 앱(iOS/Android) — 사용자 앱(`frontend/flutter`) |
| 트레이너 | **웹 반응형 우선** (센터 PC·태블릿) — 본 앱. 수요 증가 시 앱 패키징 |

이에 따라 콘텐츠 폭 제한(`AppLayout.contentMaxWidth`), drift 웹 런타임
(`tool/fetch_drift_wasm.sh`)이 포함되어 있습니다.

### 와이드 뷰포트 (≥ `AppLayout.splitBreakpoint` = 1024px)

- **고객 탭**: 마스터-디테일 스플릿 — 고객을 누르면 우측 패널에서
  채팅/식단/운동기록이 열리고(닫기 버튼으로 리스트만 보기 복귀), 선택은
  URL(`/clients?c=<id>`)에 동기화되어 새로고침에도 복원됩니다.
- **스케줄 탭**: 날짜/주간 개요가 좌측에 도킹, 타임라인이 우측 컬럼.
- **AI 루틴 탭**: 고객 선택·식단 요약(좌) + 루틴 편집기(우) 분할.
- 좁은 화면은 기존 단일 컬럼 + 전체 화면 push 그대로입니다.

## 빌드 / 실행

```bash
flutter pub get

# 웹에서 drift(로컬 DB)가 동작하려면 최초 1회 (CI/배포에도 동일 단계 필요)
bash tool/fetch_drift_wasm.sh

# 실행 (웹)
flutter run -d chrome

# 테스트 / 정적 분석 / drift codegen
flutter test
flutter analyze
dart run build_runner build --delete-conflicting-outputs
```

로그인: 비어있지 않은 아무 이메일/비밀번호 → 시드 트레이너(김트레이너)로 로그인.
"로그인 없이 데모 둘러보기"로 바로 진입할 수도 있습니다.

## 구조

[frontend/flutter/docs/STRUCTURE.md](../flutter/docs/STRUCTURE.md)의 레이어 규칙
(app / core / shared / design_system / features, 단방향 의존)을 그대로 따릅니다.

```
lib/
├─ app/            # 부트스트랩, GoRouter(+세션 인증 게이트), 4탭 셸
├─ core/           # drift DB·시드, 토큰 저장, 날짜 유틸(ymd)
├─ shared/         # 여러 feature 공유: TrainerClient/TrainerProfile 모델,
│                  # ClientRepository 서비스, ClientAvatar·OniAvatar·MetricTile·BrandHeader
├─ design_system/  # 토큰(블루 primary + 오렌지 액센트), 테마
└─ features/       # auth / clients(채팅·식단·운동기록) / schedule / ai_routine / my
```

## 이슈 여정 (1 → 12)

| # | 내용 | 비고 (추가/삭제) |
| --- | --- | --- |
| 1 | 프로젝트 스캐폴딩 + 디자인 토큰 | Flutter 기본 브랜딩(파비콘/런처) → 온케어 로고로 교체 |
| 2 | 세션/인증 로직 (mock 로그인·데모·복원) | 사용자 앱 auth 미재사용(역할 개념 부재) — 신규 설계 |
| 3 | 트레이너 로그인 화면 | 소셜/회원가입 제외(1:1 계정) |
| 4 | drift 스키마 + 고객 3명 시드 | `seed-` prefix·날짜 슬라이드·단일 트랜잭션(리뷰 반영) |
| 5 | 4탭 셸 + 인증 게이트 | 스캐폴딩 placeholder 삭제 |
| 6 | 고객 리스트 (예약 배지·AI 요약) | drift `.watch` 테스트 헬퍼 도입(pumpAndSettle 회피) |
| 7 | 고객 상세 — 채팅 | 아바타 3중복 → 공유 `ClientAvatar` 추출(리뷰 반영) |
| 8 | 고객 상세 — 식단 | 나트륨/당류 임계값을 도메인 상수로 통합(리뷰 반영) |
| 9 | 고객 상세 — 운동기록 | + 블루 팔레트 스왑·BrandHeader·웹 drift 런타임(별도 PR 분리) |
| 10 | 스케줄 탭 (타임라인·PT 전송) | + 웹 폭 제한, `ymd()` 중복 3곳 통합, 당류 보라 토큰 삭제 |
| 11 | AI 루틴 탭 (고객 선택·수정·전송) | `TrainerClient`/`ClientRepository` → shared 승격, Oni 마스코트 채택 |
| 12 | MY 탭 (프로필·자격증·통계·헬스장) | **역할 전환 미구현**(계정 분리 정책) → 로그아웃만, `TabPlaceholder` 삭제 |

### 이후 확장 (웹 와이드 + 관리 기능)

| 브랜치 | 내용 |
| --- | --- |
| `feature/trainer-split-view` | 고객 탭 마스터-디테일 스플릿(URL 동기화·닫기 버튼), 나트륨 초과 우선 정렬(동순위 → 최근 채팅순), 채팅 초안 고객 간 누수 수정, 포맷/LF 정규화 |
| `fix/trainer-chat-send-guard` | 채팅 중복 전송 가드(`_sending`)·dispose 후 접근 방지·메시지 도착 시에만 자동 스크롤 |
| `fix/trainer-client-detail-states` | 고객 상세 로딩/오류/미존재 상태 분리 + 다시 시도 |
| `feature/trainer-schedule-manage` | 스케줄 추가/수정/삭제(15분 단위 시간), 예정 세션 확장(계획 미리보기·계획 없음 안내·💬 채팅 바로가기), 오늘 중심 주간 스트립, 와이드 2컬럼 |
| `feature/trainer-routine-programs` | AI 루틴 → 오늘 PT 스케줄 등록(예정 세션에 부착 or 신규 슬롯), AI 추천 항목 삭제, 고객 피커 가로 스크롤, 와이드 분할 |
| `feature/trainer-session-complete` | 예정 세션 ✓ 완료 처리(메모 입력) → 고객 운동기록 자동 기록 — 예약→수업→기록 루프 완성 |
| `feature/trainer-send-to-chat` | 숙제/PT 프로그램 전송 시 채팅 스레드에 영속 메시지 + 고객 카드 미리보기 갱신 (`ChatRepository` shared 승격) |
| `feature/trainer-unread-badge` | 고객 카드 안읽은 메시지 뱃지(스레드 열람 시 해제, KV 마커 — 스키마 무변경) |
| `feature/trainer-client-onboarding` | ＋ 신규 고객 등록 시트(이름 *필수 표시), 상세 헤더 ● 활성/○ 휴면 토글, 아웃라인 버튼 공용화 |
| `feature/trainer-date-nav` | 스케줄·AI 루틴 날짜 이동 — 스케줄 주간 스트립(사용자 앱 식단 스트립 스타일, 예약일 dot·빈 날짜 안내), AI 루틴 등록 오늘…+6일 칩. 리포지토리 `watchDate`/날짜 파라미터화 |
| `feature/trainer-diet-trend` | 식단 탭 최근 7일 나트륨 추이 미니 차트(초과일 강조·주간 평균) — `sodiumWeekJson` 컬럼(schema v2·addColumn 마이그레이션). 막대 라벨 오늘 기준 실제 요일(리뷰 반영) |

## 주요 결정

- **색상**: 서비스 메인 = 파랑(#3EAFDF). 오렌지는 "트레이너" 브랜드 워드·경고·수동 추가
  구분·MY 아이덴티티 블록에만 (`brandOrange`/`warning`)
- **역할 전환 없음**: Figma의 "역할 전환" UI는 구현하지 않음 — 트레이너/회원은 계정으로 분리
- **mock-first**: 전송 등 상호작용은 Figma와 동일한 in-memory mock.
  채팅과 스케줄(추가/수정/삭제·AI 루틴 등록)은 drift에 영속
  (재시딩에도 `seed-` 아닌 행은 보존)
- **프로그램 이원화**: AI 루틴은 "고객 숙제 전송(mock)"과
  "PT 스케줄 등록(drift 영속)" 두 액션으로 분리 — 스케줄 탭의 예정
  세션에서 계획 미리보기로 이어짐. 등록일은 오늘…+6일 선택 가능
- **디자인 일관성**: 사용자 앱 리디자인(figma kit)의 Oni 마스코트·AI 필 패턴 채택

## 로드맵

- 트레이너 CI/배포 파이프라인 (analyze·test·web build + wasm fetch,
  `dart format --set-exit-if-changed` 포함)
- 실 백엔드(FastAPI) 연동 — `TrainerAuthRepository`/`SessionTokenStore` 교체 지점 주석 참조
- 자정 넘김 시 '오늘' 스케줄/예약 수 자동 갱신, DB JSON 역직렬화 방어
  (백엔드 연동과 함께 처리)
- **복수 헬스장 소속**: 현재 트레이너는 헬스장 1곳(seedTrainerProfile.gym)에
  고정 — 여러 센터를 담당하려면 센터-트레이너 소속(N:N) 모델과 고객·스케줄의
  센터 스코프가 필요. 계정/권한과 함께 백엔드 단계에서 도입 예정
