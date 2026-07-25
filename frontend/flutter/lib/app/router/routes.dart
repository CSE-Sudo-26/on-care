/// Centralised route paths. Anything that needs to navigate imports
/// this rather than another feature module — see STRUCTURE.md §4.
class AppRoutes {
  AppRoutes._();

  // Main tabs (StatefulShellRoute branches)
  static const String dashboard = '/dashboard';
  static const String diet = '/diet';
  static const String exercise = '/exercise';
  static const String myHealth = '/my-health';

  // Modal-ish routes (pushed from any tab)
  static const String aiCoach = '/ai-coach';
  static const String notification = '/notification';
  static const String place = '/place';
  static const String gyms = '/gyms';
  static const String trainers = '/trainers';

  // Auth
  static const String signIn = '/auth/sign-in';
  static const String signUp = '/auth/sign-up';

  // First-run onboarding (shown right after sign-up)
  static const String onboarding = '/onboarding';

  // Dev-only routes (registered only in non-prod builds).
  static const String uiCatalog = '/dev/ui-catalog';
}
