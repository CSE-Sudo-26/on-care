import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/app/shell/app_shell.dart';
import 'package:oncare_trainer/features/auth/domain/entities/session_state.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare_trainer/features/auth/presentation/pages/trainer_sign_in_page.dart';
import 'package:oncare_trainer/features/auth/presentation/pages/trainer_sign_up_page.dart';
import 'package:oncare_trainer/features/clients/presentation/pages/clients_page.dart';
import 'package:oncare_trainer/features/coaching/presentation/pages/coaching_page.dart';
import 'package:oncare_trainer/features/consultations/presentation/pages/consultations_page.dart';
import 'package:oncare_trainer/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:oncare_trainer/features/messages/presentation/pages/messages_page.dart';
import 'package:oncare_trainer/features/my/presentation/pages/my_page.dart';
import 'package:oncare_trainer/features/notifications/presentation/pages/notifications_page.dart';
import 'package:oncare_trainer/features/reports/presentation/pages/reports_page.dart';
import 'package:oncare_trainer/features/schedule/presentation/pages/schedule_page.dart';

/// Pure auth-guard policy for the router's `redirect`. Kept free of
/// `BuildContext`/`GoRouterState` so it can be unit-tested directly.
///
/// - signed-out (or still restoring) → forced onto the sign-in screen,
///   **carrying where they were headed** (`?from=`);
/// - in the app (demo or authenticated) → kept off sign-in, and sent to
///   the parked destination if there is one, else the 대시보드.
///
/// The parking is what makes a refresh survive: boot starts at the
/// browser URL with the session still [SessionStatus.unknown], so the
/// gate always sees the deep link first and must not throw it away
/// before secure storage has answered. (#701)
///
/// [location] is the full location (path **and** query) — the parked
/// destination rides on the query, so a path-only value would lose it.
///
/// Returning `null` means "no redirect — stay put".
String? sessionRedirect(SessionStatus status, String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  final onAuthRoute = path == AppRoutes.signIn || path == AppRoutes.signUp;
  switch (status) {
    case SessionStatus.unknown:
    case SessionStatus.signedOut:
      return onAuthRoute ? null : AppRoutes.signInResuming(location);
    case SessionStatus.demo:
    case SessionStatus.authenticated:
      if (onAuthRoute) {
        return AppRoutes.resumeTarget(location) ?? AppRoutes.dashboard;
      }
      // The platform boot location on a non-web launch is `/`, which
      // matches no route; send it home rather than to an error screen.
      return path == '/' ? AppRoutes.dashboard : null;
  }
}

/// Normalises `/clients/<id>` (no section) onto the default section, so
/// every client URL is fully qualified and the sub-tab state is always
/// readable from the location.
String? clientSectionRedirect(String? id) =>
    id == null ? null : AppRoutes.clientDetail(id);

/// Keeps legacy client-chat links working while `/messages` owns the only
/// full thread UI.
String? clientChatRedirect(String? id, String? section) {
  if (id == null || section != AppRoutes.clientChatSection) return null;
  return AppRoutes.messagesFor(id);
}

/// Builds the trainer routing tree: a seven-branch [StatefulShellRoute]
/// behind an auth gate, plus the auth routes.
///
/// Branches 0–4 are the sidebar destinations (대시보드 / 고객 / 스케줄 /
/// AI 코칭 / 리포트) in [navDestinations] order; branch 5 is 내 정보 —
/// reachable from the sidebar footer but not a nav row; branch 6 is
/// 상담 요청, whose nav row appears only against the real API.
///
/// [readStatus] drives [sessionRedirect]; [refresh] should fire whenever
/// the session changes so the guard re-evaluates without rebuilding the
/// router (a rebuild would drop the navigation stack).
///
/// [initialLocation] is left null in production **on purpose**: the boot
/// location is then the platform's — on web, the browser URL. Pinning it
/// to the sign-in screen is what made every refresh land on the 대시보드
/// no matter what the address bar said (#701). Tests pass it to boot at a
/// given deep link, which is otherwise unreachable from a widget test.
GoRouter buildAppRouter({
  required SessionStatus Function() readStatus,
  required Listenable refresh,
  String? initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) => sessionRedirect(
      readStatus(),
      // Full location, not `matchedLocation`: the parked destination
      // rides on the query string.
      state.uri.toString(),
    ),
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.clients,
                builder: (context, state) =>
                    ClientsPage(filter: state.uri.queryParameters['f']),
                routes: <RouteBase>[
                  // `/clients/<id>` → `/clients/<id>/overview`.
                  GoRoute(
                    path: AppRoutes.clientBarePattern,
                    redirect: (context, state) =>
                        clientSectionRedirect(state.pathParameters['id']),
                  ),
                  // The detail is rendered BY the clients page (split
                  // panel on wide, full-bleed on narrow) rather than as
                  // a pushed screen — one widget owns the layout choice.
                  GoRoute(
                    path: AppRoutes.clientDetailPattern,
                    redirect: (context, state) => clientChatRedirect(
                      state.pathParameters['id'],
                      state.pathParameters['section'],
                    ),
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: ClientsPage(
                        selectedId: state.pathParameters['id'],
                        section: state.pathParameters['section'],
                        filter: state.uri.queryParameters['f'],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.messages,
                builder: (context, state) => MessagesPage(
                  clientId: state.uri.queryParameters['client'],
                  filter: state.uri.queryParameters['f'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.schedule,
                builder: (context, state) => SchedulePage(
                  view: state.uri.queryParameters['v'],
                  date: state.uri.queryParameters['d'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.coaching,
                builder: (context, state) =>
                    CoachingPage(clientId: state.uri.queryParameters['client']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.reports,
                builder: (context, state) =>
                    ReportsPage(clientId: state.uri.queryParameters['client']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.my,
                builder: (context, state) =>
                    MyPage(tab: state.uri.queryParameters['t']),
              ),
            ],
          ),
          // 상담 요청 is appended AFTER 내 정보 on purpose: `myBranchIndex`
          // is `navDestinations.length`, so inserting here instead would
          // shift 내 정보 and silently break the footer's selection. (#467)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.consultations,
                builder: (context, state) => const ConsultationsPage(),
              ),
            ],
          ),
          // 알림함도 같은 이유로 맨 뒤에 붙인다. (#503)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.notifications,
                builder: (context, state) => const NotificationsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const TrainerSignInPage(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const TrainerSignUpPage(),
      ),
    ],
  );
}

/// Where the router boots. Null (production) means the platform
/// location — the browser URL on web. Tests override it to boot at a
/// deep link and watch the auth gate hand it back after restore.
final routerInitialLocationProvider = Provider<String?>((ref) => null);

/// Riverpod-managed router. Bridges session changes into a [Listenable]
/// so the auth guard re-evaluates without rebuilding the router.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(
    sessionControllerProvider,
    (_, _) => refresh.value++,
  );
  ref.onDispose(refresh.dispose);
  return buildAppRouter(
    readStatus: () => ref.read(sessionControllerProvider).status,
    refresh: refresh,
    initialLocation: ref.read(routerInitialLocationProvider),
  );
});
