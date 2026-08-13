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
  static const Color brandOrange = Color(0xFFFF953C); // 주의 오렌지(#FF953C)로 통일

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

  /// Warning orange (`#FF953C`) — a caution that is NOT a target being
  /// exceeded: partial routine completion, a manual entry to double-check.
  static const Color warning = Color(0xFFFF953C);

  /// "목표 초과" red (`#F04438`). Matches the member app's
  /// `FigmaColors.dangerRed` — a member who sees 나트륨 초과 in red on
  /// their phone must not see it in orange on their trainer's screen.
  /// Reserved for a target actually being exceeded; use [warning] for
  /// softer cautions.
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
