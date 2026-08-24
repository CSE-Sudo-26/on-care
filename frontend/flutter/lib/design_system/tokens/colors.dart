import 'package:flutter/painting.dart';

/// Palette aligned with the original React prototype's `src/styles/theme.css`
/// (shadcn-style CSS variables). Light mode only for now — dark mode
/// follows the same shape and lands in a later phase.
class AppColors {
  AppColors._();

  // --- Brand ---
  /// `--primary` — bright teal-blue used for CTAs / active nav / accent
  /// fills throughout the app.
  static const Color primary = Color(0xFF3EAFDF);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  /// `--secondary` — deeper blue used as the second stop of the
  /// "today's record" gradient card.
  static const Color secondary = Color(0xFF277DA1);
  static const Color secondaryForeground = Color(0xFFFFFFFF);

  // --- Surface / text ---
  /// `--background`
  static const Color background = Color(0xFFFFFFFF);

  /// `--foreground` (oklch(0.145 0 0) ≈ #262626).
  static const Color foreground = Color(0xFF262626);

  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF262626);

  /// `--muted` — very soft blue tint used as fill for progress-bar tracks.
  static const Color muted = Color(0xFFE8F4F8);

  /// `--muted-foreground` — slate-500 ish.
  static const Color mutedForeground = Color(0xFF64748B);

  /// `--accent` — softer blue used as background for list rows /
  /// pills inside cards.
  static const Color accent = Color(0xFFE0F2F7);
  static const Color accentForeground = Color(0xFF0F172A);

  // --- Semantic ---
  static const Color destructive = Color(0xFFD4183D);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  /// `--warning` — orange used for "sodium too high" alerts and
  /// over-budget progress fills.
  static const Color warning = Color(0xFFF97316);
  static const Color warningForeground = Color(0xFFFFFFFF);

  // --- Borders & input ---
  /// `--border: rgba(0,0,0,0.1)`
  static const Color border = Color(0x1A000000);

  /// `--input-background`
  static const Color inputBackground = Color(0xFFF3F3F5);

  // --- Extra accents used by the gradient cards in the original. ---
  /// Used by the "이번 주 건강 점수" card (green gradient).
  static const Color scoreGradientStart = Color(
    0xFF22C55E,
  ); // tailwind green-500
  static const Color scoreGradientEnd = Color(0xFF059669); // emerald-600

  // --- Additional semantic aliases used by our reusable widgets
  // (AppBadge tones, MetricCard delta tones). The original React
  // app does not have explicit `success` / `info` tokens — these are
  // pragmatic additions kept in the same teal/orange/green family.
  /// 완료·성공 초록 (`#34C759`). **두 앱이 같은 값을 쓴다** — 회원이 자기
  /// 폰에서 `완료` 로 본 것을 트레이너 화면에서 다른 초록으로 보여 주지 않는다
  /// (#1239). 성취(`achievement`)·식단 계열색과는 뜻이 다르다.
  static const Color success = Color(0xFF34C759);

  /// 성취 초록 (`#22C55E`). 완료와 **다른 뜻**이다 — 완료는 할 일을 끝냈다는
  /// 상태이고, 성취는 목표를 이뤄 축하할 일이다. `이번 주 건강 점수` 카드의
  /// 그라디언트와 같은 초록이라 알림의 성취 배지가 그 카드와 한 짝으로 읽힌다.
  static const Color achievement = scoreGradientStart;
  static const Color info = primary;
  static const Color error = destructive;
  static const Color primaryContainer = accent;

  // --- Status / chart semantics (수정사항 선행 토큰, #995) ---
  //
  // 세 파트(공통·사용자앱 / 트레이너 대시보드·메시지·스케줄·리포트 /
  // 트레이너 고객·프로그램)가 **같은 이름**으로 읽도록 두 앱에 같은 이름·같은
  // 값으로 둔다. 화면에서 색을 직접 고르지 말고 여기서 가져간다.

  /// 목표 안쪽(= 초과가 아님) 상태색. 앱 브랜드 파랑을 그대로 쓴다.
  ///
  /// 초록으로 그리지 않는다. 초록은 "정상" 으로 읽히는데, 1g 만 먹어도 초과는
  /// 아니라서 영양이 한참 모자란 날까지 "괜찮다" 고 말해 버렸다(#1070).
  /// 상태색이 말할 수 있는 것은 "초과했는가" 뿐이므로, 초과가 아닌 쪽은
  /// 판단을 담지 않는 브랜드색으로 중립하게 둔다.
  static const Color statusWithinGoal = primary;

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

  /// 식단 그래프 색. **각 앱의 브랜드색**이다 — 회원 앱은 파랑, 트레이너는
  /// 자기 남색(#1239).
  ///
  /// 한때 초록(`#22A882`)이었지만 초록은 "정상" 으로 읽혀, 목표에 한참 못 미친
  /// 날까지 괜찮다고 말했다(#1070). 지금은 판단을 담지 않는 브랜드색으로 그리고
  /// 초과한 날만 [statusOver] 로 갈린다. 두 앱의 식단 그래프가 서로 다른 색인
  /// 것은 그래서 의도다 — 각자 자기 앱의 색으로 말한다.
  static const Color dietChart = primary;

  /// 운동 그래프 색. 앱별 브랜드 파랑을 그대로 쓴다.
  static const Color exerciseChart = primary;

  /// 그래프 목표선(파선). 데이터 선과 섞이지 않도록 중립 회색을 쓰고,
  /// 굵기·파선 간격은 차트 위젯에서 통일한다.
  static const Color chartGoalLine = Color(0xFF98A2B3);
}
