/// Layout tokens for the trainer app's web-first surface.
///
/// The app is a desktop/tablet web console: a fixed left sidebar plus a
/// fluid content column. Breakpoints below are measured against the
/// **viewport**, except [splitBreakpoint], which is measured against the
/// **content area** (the viewport minus the sidebar) because it decides
/// whether a page can host a master-detail split.
class AppLayout {
  AppLayout._();

  // --- Sidebar ---

  /// Width of the expanded sidebar (brand + labelled nav + profile).
  static const double sidebarWidth = 232;

  /// Width of the collapsed icon-only rail (labels move to tooltips).
  static const double sidebarRailWidth = 76;

  /// Viewport width from which the sidebar shows labels. Below this the
  /// rail is used instead.
  static const double sidebarExpandBreakpoint = 1280;

  /// Viewport width below which the sidebar leaves the layout entirely
  /// and becomes a drawer behind a menu button (tablet portrait/phone).
  static const double sidebarDrawerBreakpoint = 1024;

  /// 리포트 왼쪽 열에서 요약 카드가 남은 자리를 채우기 시작하는 열 높이.
  ///
  /// 고객 목록(5줄 고정)만으로도 이 아래에서는 자리가 빠듯하다 — 그보다 짧은
  /// 창에서는 요약을 늘리는 대신 열 안에서 스크롤한다. (#1177)
  static const double reportsSummaryFillMinHeight = 560;

  /// 헤더 가운데 슬롯(통합 검색 바)이 인라인 형태를 유지하는 최소 폭.
  /// 이보다 좁아지면 검색 바가 스스로 아이콘으로 접힌다 — 접히기 전에
  /// 좌우 대칭 예약을 포기하고 남는 자리를 몰아 준다. (#995)
  static const double headerCenterMinWidth = 400;

  // --- Content ---

  /// Max width of a single, readable content column (forms, timelines,
  /// settings). Wider than this and line length hurts scanning.
  static const double contentMaxWidth = 760;

  /// Max width of a full multi-column page (dashboard, split views).
  static const double wideMaxWidth = 1440;

  /// Content-area width from which a page may switch to a master-detail
  /// split (list + panel). Deliberately lower than the old phone-era
  /// value: the sidebar already consumes ~250px of the viewport.
  static const double splitBreakpoint = 900;

  /// Content-area width from which the dashboard uses two columns.
  static const double twoColumnBreakpoint = 1080;

  /// Fixed width of a list column inside a split layout.
  static const double splitListWidth = 380;

  /// Outer padding around top-level page content.
  static const double pagePadding = 24;

  /// Height of the sticky page header (title + actions).
  static const double pageHeaderHeight = 88;
}
