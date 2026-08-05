/// Centralised route paths for the trainer app. Anything that needs to
/// navigate imports this rather than another feature module
/// (STRUCTURE.md §4).
///
/// URLs are **path-based** (`/clients/<id>/diet`) rather than
/// query-based: the sidebar console is deep-linked constantly (a KPI
/// card jumps to a filtered list, a schedule row jumps to a chat), and
/// paths keep back/forward, refresh and link-sharing honest.
class AppRoutes {
  AppRoutes._();

  /// Trainer login screen (email/password + demo bypass).
  static const String signIn = '/auth/sign-in';

  /// Trainer 회원가입 screen (name/email/password).
  static const String signUp = '/auth/sign-up';

  // --- Main navigation (StatefulShellRoute branches) ---

  /// 대시보드 — the console's home; what needs doing today.
  static const String dashboard = '/dashboard';

  /// 고객 — roster list, with the detail panel as a child path.
  static const String clients = '/clients';

  /// 스케줄 — day / week calendar.
  static const String schedule = '/schedule';

  /// AI 코칭 — routine generation, templates, send history.
  static const String coaching = '/coaching';

  /// 리포트 — client weekly reports + trainer operating metrics.
  static const String reports = '/reports';

  /// 내 정보 / 설정 — reached from the sidebar footer, not the nav list.
  static const String my = '/my';

  // --- Client detail ---

  /// Sub-sections of a client's detail panel, in tab order.
  static const List<String> clientSections = <String>[
    'overview',
    'chat',
    'diet',
    'workout',
    'routines',
  ];

  /// The section shown when a client is opened without one.
  static const String defaultClientSection = 'overview';

  /// Route pattern for the client detail panel.
  static const String clientDetailPattern = ':id/:section';

  /// Route pattern for a client opened without a section (redirects).
  static const String clientBarePattern = ':id';

  /// Builds `/clients/<id>/<section>`. Ids are percent-encoded — a
  /// backend member id is not guaranteed to be URL-safe.
  static String clientDetail(String id, {String? section}) {
    final safeSection = clientSections.contains(section)
        ? section!
        : defaultClientSection;
    return '$clients/${Uri.encodeComponent(id)}/$safeSection';
  }

  /// Builds the 고객 list filtered to a preset. Used by the dashboard
  /// KPI cards (`unread` = 답장 필요, `attention` = 주의 고객).
  static String clientsFiltered(String filter) => Uri(
    path: clients,
    queryParameters: <String, String>{'f': filter},
  ).toString();

  /// Builds the AI 코칭 workspace with [clientId] preselected.
  static String coachingFor(String clientId) => Uri(
    path: coaching,
    queryParameters: <String, String>{'client': clientId},
  ).toString();

  /// Builds the 리포트 tab focused on [clientId].
  static String reportFor(String clientId) => Uri(
    path: reports,
    queryParameters: <String, String>{'client': clientId},
  ).toString();

  /// Builds the 스케줄 tab on a given [view] (`day` | `week`) and date.
  static String scheduleView(String view, {String? date}) => Uri(
    path: schedule,
    queryParameters: <String, String>{'v': view, 'd': ?date},
  ).toString();

  /// Builds the 내 정보 page on a given [tab] (`profile` | `settings`).
  static String mySection(String tab) =>
      Uri(path: my, queryParameters: <String, String>{'t': tab}).toString();
}
