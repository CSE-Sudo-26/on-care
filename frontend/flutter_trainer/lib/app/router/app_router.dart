import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/main_shell.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/ai_routine/presentation/pages/ai_routine_page.dart';
import 'package:oncare_trainer/features/auth/domain/entities/session_state.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare_trainer/features/auth/presentation/pages/trainer_sign_in_page.dart';
import 'package:oncare_trainer/features/auth/presentation/pages/trainer_sign_up_page.dart';
import 'package:oncare_trainer/features/clients/presentation/pages/client_detail_page.dart';
import 'package:oncare_trainer/features/clients/presentation/pages/clients_page.dart';
import 'package:oncare_trainer/features/my/presentation/pages/my_page.dart';
import 'package:oncare_trainer/features/schedule/presentation/pages/schedule_page.dart';

/// Pure auth-guard policy for the router's `redirect`. Kept free of
/// `BuildContext`/`GoRouterState` so it can be unit-tested directly.
///
/// - signed-out (or still restoring) → forced onto the sign-in screen;
/// - in the app (demo or authenticated) → kept off sign-in (bounced to
///   the 고객 tab).
///
/// Returning `null` means "no redirect — stay put".
String? sessionRedirect(SessionStatus status, String location) {
  final onAuthRoute =
      location == AppRoutes.signIn || location == AppRoutes.signUp;
  switch (status) {
    case SessionStatus.unknown:
    case SessionStatus.signedOut:
      return onAuthRoute ? null : AppRoutes.signIn;
    case SessionStatus.demo:
    case SessionStatus.authenticated:
      return onAuthRoute ? AppRoutes.clients : null;
  }
}

/// Builds the trainer routing tree: a four-branch [StatefulShellRoute]
/// (고객/스케줄/AI루틴/MY) behind an auth gate, plus the sign-in route.
///
/// [readStatus] drives [sessionRedirect]; [refresh] should fire whenever
/// the session changes so the guard re-evaluates without rebuilding the
/// router (a rebuild would drop the navigation stack).
GoRouter buildAppRouter({
  required SessionStatus Function() readStatus,
  required Listenable refresh,
}) {
  return GoRouter(
    initialLocation: AppRoutes.signIn,
    refreshListenable: refresh,
    redirect: (context, state) =>
        sessionRedirect(readStatus(), state.matchedLocation),
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.clients,
                builder: (context, state) => const ClientsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.schedule,
                builder: (context, state) => const SchedulePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.aiRoutine,
                builder: (context, state) => const AiRoutinePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.my,
                builder: (context, state) => const MyPage(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen client detail (over the shell — no bottom nav).
      GoRoute(
        path: AppRoutes.clientDetailPattern,
        builder: (context, state) =>
            ClientDetailPage(clientId: state.pathParameters['id']!),
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
  );
});
