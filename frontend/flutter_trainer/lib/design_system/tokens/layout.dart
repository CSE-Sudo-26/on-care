/// Layout tokens for the trainer app's web-first surface. The Figma is
/// a phone mock; on desktop/tablet web the content column is centered
/// and capped so lists/chat don't stretch edge-to-edge.
class AppLayout {
  AppLayout._();

  /// Max width of the main content column (tabs, detail, chat).
  static const double contentMaxWidth = 720;

  /// Viewport width from which the 고객 탭 switches to the
  /// master-detail split (list + embedded detail panel).
  static const double splitBreakpoint = 1024;

  /// Max width of the split (list + detail) layout on wide viewports.
  static const double wideMaxWidth = 1200;

  /// Fixed width of the client list column inside the split layout.
  static const double splitListWidth = 360;
}
