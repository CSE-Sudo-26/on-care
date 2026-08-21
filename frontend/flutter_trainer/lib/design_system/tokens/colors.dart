import 'package:flutter/painting.dart';

/// Trainer-app palette. Derived from the On-Care Figma trainer mock
/// (`On-Care_figma/src/app/App.tsx`, TrainerApp section). The trainer
/// experience is branded **남색 (navy)** (연한 #9DC3E0 ~ 진한 #2E7DAB), with
/// orange kept only as a small identity/warning accent.
///
/// Values are picked to match the mock and are the single source of
/// truth — widgets must read from here (STRUCTURE.md §2.5: no hardcoded
/// colors).
class AppColors {
  AppColors._();

  // --- Brand (service = navy; orange demoted to identity/warning accents) ---
  /// Primary navy used for CTAs / active nav / links — the service's
  /// main color.
  static const Color primary = Color(0xFF2E7DAB);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  /// Deeper navy — gradient second stop for primary CTAs.
  static const Color secondary = Color(0xFF17435F);

  /// Trainer identity orange — kept only as a small accent (the
  /// "트레이너" brand word, MY-tab highlights), not as the main color.
  /// 브랜드 주황 (`#FF953C`). **주의가 아닌** 강조에 쓴다 — 메모·안내 박스,
  /// 진행 척도의 '부분', 지표 구분색 등. 주의는 [warning](빨강)이다.
  static const Color brandOrange = Color(0xFFFF953C);

  /// Tone-down green used by the user app's normal sugar chart
  /// (`FigmaColors.greenText`).
  static const Color userSugarGreen = Color(0xFF22A882);

  // --- Accent (client navy) ---
  /// Navy used for client avatars, info chips, and the "AI 요약" card.
  static const Color accent = Color(0xFF2E7DAB);
  static const Color accentForeground = Color(0xFFFFFFFF);

  /// Deeper navy — second stop of the client-avatar gradient.
  static const Color accentDark = Color(0xFF17435F);

  /// AI-summary card gradient (mock: `linear-gradient(135deg,#C8E8F6,
  /// #A8D8F0)` on the 고객 탭 "AI 요약" card).
  static const Color aiCardGradientStart = Color(0xFFDCEAF4);
  static const Color aiCardGradientEnd = Color(0xFF9DC3E0);

  /// 운동 유형 3색 — 회원 앱 `운동 현황` 과 **같은 그림**을 트레이너 토큰으로
  /// 옮긴 것이다(#943). 도넛·누적 막대·범례가 모두 이 셋을 쓴다.
  ///
  /// 명도로 갈라 둔 한 계열이다. 유형마다 다른 색상환을 쓰면 세 값이 서로 다른
  /// 뜻을 가진 것처럼 보이는데, 셋은 **같은 운동 시간을 나눈 것**이다.
  /// 순서는 언제나 유산소 → 근력 → 스트레칭이라 색을 외우지 않아도 자리로
  /// 읽힌다.
  /// 탄단지 3색 — 회원 앱 식단 탭 `이번 달` 막대와 같은 램프다(#944).
  ///
  /// **한 색의 농담**이다. `오늘` 뷰가 칼로리 링과 탄단지 진행 바를 모두 브랜드
  /// 색 하나로 그리므로, 기간 뷰만 다른 색상환을 쓰면 같은 카드를 오갈 때 색이
  /// 튄다. 셋은 서로 다른 지표가 아니라 **한 칼로리를 나눈 것**이라, 색상보다
  /// 농담으로 가르는 편이 뜻에도 맞는다.
  ///
  /// 값은 브랜드 색을 흰 배경 위에 100% / 65% / 35% 로 얹은 결과다. 알파 대신
  /// 불투명 값으로 박아 두는 이유는 막대가 목표선 위에 겹쳐 그려지기 때문이다 —
  /// 반투명이면 선이 비쳐 층 경계가 흐려진다.
  static const Color macroCarbs = Color(0xFF2E7DAB);
  static const Color macroProtein = Color(0xFF79AECC);
  static const Color macroFat = Color(0xFFB7D6E7);

  static const Color chartCardio = Color(0xFF2E7DAB);
  static const Color chartStrength = Color(0xFF17435F);
  static const Color chartStretching = Color(0xFFD6E7F3);

  /// 사용자 앱 "오늘의 AI 통합 조언" 배너 배경(연한 남색). MY 탭
  /// "이번 달 통계" 카드도 이 남색 톤을 쓴다.
  static const Color bannerStart = Color(0xFFEAF2F9);
  static const Color bannerEnd = Color(0xFFD6E7F3);

  // --- Surface / text ---
  /// App canvas behind cards (final trainer wireframe uses `#F5F7FA`).
  static const Color background = Color(0xFFF5F7FA);

  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF1A1A1A);

  /// Primary text.
  static const Color foreground = Color(0xFF1A1A1A);

  /// Secondary body text. Dark enough to stay readable on white and the
  /// app's pale surfaces (white contrast 7.61:1).
  static const Color mutedForeground = Color(0xFF465568);

  /// Tertiary / placeholder text (white contrast 4.72:1, WCAG AA for
  /// normal text). It remains lighter than [mutedForeground] without
  /// fading into the card background.
  static const Color subtleForeground = Color(0xFF667585);

  /// Disabled text. Visibly inactive but still legible (white contrast
  /// 3.77:1) when a trainer needs to understand why an action is disabled.
  static const Color disabledForeground = Color(0xFF768596);

  // --- Semantic ---
  /// Success / "완료" green (`#34C759`).
  /// 세션 **종류**의 색. 상태(예정·완료·취소·노쇼)와 갈래가 다르다. (#1013)
  ///
  /// 시간표에서 읽는 것은 색과 자리다. 종류를 셋째 줄 글씨로만 말하면 훑는
  /// 동안에는 `1:1 PT` 와 `상담` 이 똑같이 보인다. 그래서 **면의 색이 종류를**,
  /// 왼쪽 띠의 색이 상태를 말한다 — 두 값이 서로를 덮지 않는다.
  ///
  /// 색만으로 구분하지도 않는다. 블록과 알약에 `상담` 이라는 글씨가 그대로
  /// 남아, 색을 못 보는 경우에도 종류를 알 수 있다.
  static const Color sessionPersonalTraining = primary;

  /// 상담. 남색 계열(1:1 PT)·초록(완료)·빨강(취소·노쇼) 어디와도 겹치지 않는
  /// 색을 골랐다.
  static const Color sessionConsultation = Color(0xFF7C5CD1);

  static const Color success = Color(0xFF34C759);

  /// '주의' 빨강 (`#F04438`). [overTarget] 과 **같은 색이다.**
  ///
  /// 예전에는 주황(`#FF953C`)이었다. 목표 초과만 빨강이고 완만한 주의는 주황이라는
  /// 규칙이었는데, 회원은 자기 폰에서 빨갛게 보고 있는 것을 트레이너는 주황으로
  /// 봐서 **두 앱이 같은 사실을 다른 세기로** 말했다. 주의는 주의다. (#690)
  ///
  /// 메모·안내처럼 주의가 아닌 자리에는 쓰지 않는다 — 그런 곳은 [brandOrange].
  static const Color warning = Color(0xFFF04438);

  /// "목표 초과" red (`#F04438`). Matches the member app's
  /// `FigmaColors.dangerRed` — a member who sees 나트륨 초과 in red on
  /// their phone must not see it in orange on their trainer's screen.
  static const Color overTarget = Color(0xFFF04438);

  /// Destructive / delete red (`#FF3B30`).
  static const Color destructive = Color(0xFFFF3B30);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  // --- Borders & fills ---
  /// Card hairline border (`rgba(0,0,0,0.05)`).
  static const Color border = Color(0x0D000000);

  /// Stronger divider / input border (navy-tinted grey).
  static const Color borderStrong = Color(0xFFDEE8F1);

  /// Soft neutral grey fill for input backgrounds / list rows (`#F2F4F7`).
  static const Color inputBackground = Color(0xFFF2F4F7);

  /// Navy-tinted fill used behind client sub-sections.
  static const Color accentSurface = Color(0xFFEAF2F9);

  // --- Status / chart semantics (수정사항 선행 토큰, #995) ---
  //
  // 세 파트(공통·사용자앱 / 트레이너 대시보드·메시지·스케줄·리포트 /
  // 트레이너 고객·프로그램)가 **같은 이름**으로 읽도록 두 앱에 같은 이름·같은
  // 값으로 둔다. 화면에서 색을 직접 고르지 말고 여기서 가져간다.

  /// 정상 초록. "고객-식단-정상 초록"을 기준값으로 승격한 것이다.
  /// 식단 그래프·정상 태그·달성 표시가 모두 이 초록 하나를 쓴다.
  static const Color statusNormal = Color(0xFF22A882);

  /// 주의 주황 — **고객 상태 등급**의 중간 단계(주의 고객)에 쓴다.
  /// 텍스트·아이콘용. 배지 배경·막대는 [statusCautionFill].
  static const Color statusCaution = Color(0xFFE8760A);

  /// 주의 주황(채움). 배지 배경, 진행 막대의 '주의' 구간.
  static const Color statusCautionFill = Color(0xFFFF953C);

  /// 위험 빨강 — 고객 상태 등급의 마지막 단계(이탈 위험).
  static const Color statusDanger = Color(0xFFF04438);

  /// 목표 초과 빨강 — 칼로리·나트륨·당류가 목표를 넘은 지표 표시.
  /// [statusDanger] 와 **같은 값이다.** 회원이 자기 폰에서 빨갛게 보는 초과를
  /// 트레이너 화면에서 다른 세기로 보여주지 않는다.
  static const Color statusOver = statusDanger;

  /// 식단 그래프 색. 파랑에서 초록으로 옮긴다 — 운동과 한눈에 갈라 보라는
  /// 요구이므로 식단만 바꾸고 운동은 파랑을 지킨다.
  static const Color dietChart = statusNormal;

  /// 운동 그래프 색. 앱별 브랜드 파랑을 그대로 쓴다.
  static const Color exerciseChart = primary;

  /// 그래프 목표선(파선). 데이터 선과 섞이지 않도록 중립 회색을 쓰고,
  /// 굵기·파선 간격은 차트 위젯에서 통일한다.
  static const Color chartGoalLine = Color(0xFF98A2B3);
}
