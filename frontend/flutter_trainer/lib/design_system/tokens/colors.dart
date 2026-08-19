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
}
