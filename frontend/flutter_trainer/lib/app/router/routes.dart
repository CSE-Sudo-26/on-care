/// Centralised route paths for the trainer app. Anything that needs to
/// navigate imports this rather than another feature module
/// (STRUCTURE.md §4).
class AppRoutes {
  AppRoutes._();

  /// Trainer login screen (email/password + demo bypass).
  static const String signIn = '/auth/sign-in';

  /// Trainer 회원가입 screen (name/email/password).
  static const String signUp = '/auth/sign-up';

  // Main tabs (StatefulShellRoute branches).

  /// 고객 관리 — client list (home tab).
  static const String clients = '/clients';

  /// 스케줄 — daily PT timeline.
  static const String schedule = '/schedule';

  /// AI 루틴 — AI routine generation.
  static const String aiRoutine = '/ai-routine';

  /// MY — trainer profile.
  static const String my = '/my';

  /// Client detail route pattern (full-screen, over the shell).
  static const String clientDetailPattern = '/client/:id';

  /// Builds the client detail path for [id].
  static String clientDetail(String id) => '/client/$id';

  /// Builds the 고객 tab location with [id] preselected (wide split
  /// panel). Routed through [Uri] so the id is percent-encoded — string
  /// concatenation would break on a `?`/`&`/non-ASCII id.
  static String clientsWithSelection(String id) =>
      Uri(path: clients, queryParameters: <String, String>{'c': id}).toString();
}
