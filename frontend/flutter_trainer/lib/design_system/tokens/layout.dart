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
  static const double sidebarWidth = 248;

  /// Width of the collapsed icon-only rail (labels move to tooltips).
  static const double sidebarRailWidth = 76;

  /// Viewport width from which the sidebar shows labels. Below this the
  /// rail is used instead.
  static const double sidebarExpandBreakpoint = 1280;

  /// Viewport width below which the sidebar leaves the layout entirely
  /// and becomes a drawer behind a menu button (tablet portrait/phone).
  static const double sidebarDrawerBreakpoint = 1024;

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
  static const double splitListWidth = 340;

  /// Horizontal padding around page content.
  static const double pagePadding = 24;

  /// Height of the sticky page header (title + actions).
  static const double pageHeaderHeight = 64;
}
