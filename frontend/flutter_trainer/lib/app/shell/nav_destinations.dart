import 'package:flutter/material.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// Which live counter, if any, a destination shows as a badge.
enum NavBadge {
  /// No badge.
  none,

  /// Total unread client messages (답장 필요).
  unreadMessages,

  /// Today's booked session count.
  todayReservations,

  /// Undecided consultation requests. Supplied by the sidebar directly
  /// rather than looked up from [navDestinations] — this destination is
  /// conditional, so it is not in that list. (#467)
  pendingConsultations,

  /// Unread trainer notifications. Supplied by the sidebar directly for the
  /// same reason as [pendingConsultations]. (#503)
  unreadNotifications,
}

/// One entry in the sidebar. The order of [navDestinations] is the tab
/// order used by the router's [StatefulShellRoute] branches — index N
/// here is branch N there, so the two must never drift apart.
class NavDestination {
  /// Creates a sidebar destination.
  const NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.badge = NavBadge.none,
  });

  /// Which label to show. **문자열이 아니라 키다.** 이 리스트는 `const` 라
  /// (브랜치 순서를 구조로 못 박는다) 생성 시점에 로케일을 알 수 없다. 화면이
  /// `navLabel(l, destination.label)` 로 그릴 때 비로소 문구가 정해진다. (#501)
  final NavLabel label;

  /// Icon in the unselected state.
  final IconData icon;

  /// Icon in the selected state.
  final IconData activeIcon;

  /// Branch root location.
  final String route;

  /// Live counter rendered next to the label.
  final NavBadge badge;
}

/// The console's five destinations, in branch order.
///
/// One flat list, evenly spaced. An earlier revision split these into
/// 운영 / 코칭 groups with headings; the headings named the obvious and
/// the extra gap made the five rows read as two lists instead of one.
/// 사이드바 라벨 키. 값이 아니라 키인 이유는 [NavDestination.label] 참고.
enum NavLabel {
  dashboard,
  clients,
  schedule,
  messages,
  coaching,
  reports,
  consultations,
  notifications,
}

/// 라벨 키 → 현재 로케일의 문구.
String navLabel(AppLocalizations l, NavLabel label) => switch (label) {
  NavLabel.dashboard => l.navDashboard,
  NavLabel.clients => l.navClients,
  NavLabel.schedule => l.navSchedule,
  NavLabel.messages => l.navMessages,
  NavLabel.coaching => l.navCoaching,
  NavLabel.reports => l.navReports,
  NavLabel.consultations => l.navConsultations,
  NavLabel.notifications => l.navNotifications,
};

const List<NavDestination> navDestinations = <NavDestination>[
  NavDestination(
    label: NavLabel.dashboard,
    icon: Icons.space_dashboard_outlined,
    activeIcon: Icons.space_dashboard,
    route: AppRoutes.dashboard,
  ),
  NavDestination(
    label: NavLabel.clients,
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    route: AppRoutes.clients,
    badge: NavBadge.unreadMessages,
  ),
  NavDestination(
    label: NavLabel.schedule,
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_today,
    route: AppRoutes.schedule,
    badge: NavBadge.todayReservations,
  ),
  NavDestination(
    label: NavLabel.messages,
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    route: AppRoutes.messages,
    badge: NavBadge.unreadMessages,
  ),
  NavDestination(
    label: NavLabel.coaching,
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
    route: AppRoutes.coaching,
  ),
  NavDestination(
    label: NavLabel.reports,
    icon: Icons.insights_outlined,
    activeIcon: Icons.insights,
    route: AppRoutes.reports,
  ),
];

/// 상담 요청 — deliberately NOT in [navDestinations]. (#467)
///
/// That list defines branch order (index N here is branch N there), and the
/// row is only shown against the real API. A conditional entry would make
/// the list's length depend on build config, which is exactly what
/// `AppShell.myBranchIndex` reads. Keeping it separate lets the sidebar
/// render it with an explicit branch index and leaves the demo untouched.
const NavDestination consultationsDestination = NavDestination(
  label: NavLabel.consultations,
  icon: Icons.mark_email_unread_outlined,
  activeIcon: Icons.mark_email_unread,
  route: AppRoutes.consultations,
  badge: NavBadge.pendingConsultations,
);

/// 알림함 — [consultationsDestination] 과 같은 이유로 [navDestinations] 밖에
/// 둔다. 실 API 빌드에서만 보이고, 브랜치 인덱스를 사이드바가 직접 넘긴다. (#503)
const NavDestination notificationsDestination = NavDestination(
  label: NavLabel.notifications,
  icon: Icons.notifications_none,
  activeIcon: Icons.notifications,
  route: AppRoutes.notifications,
  badge: NavBadge.unreadNotifications,
);
