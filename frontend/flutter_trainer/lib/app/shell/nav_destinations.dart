import 'package:flutter/material.dart';

import 'package:oncare_trainer/app/router/routes.dart';

/// Sidebar grouping. Two groups only — the daily operating surfaces and
/// the coaching surfaces that carry the product's differentiator.
enum NavGroup {
  /// 매일 여는 것 — 대시보드 / 고객 / 스케줄.
  operations('운영'),

  /// 이 서비스의 차별점 — AI 코칭 / 리포트.
  coaching('코칭');

  const NavGroup(this.label);

  /// Section heading shown above the group in the expanded sidebar.
  final String label;
}

/// Which live counter, if any, a destination shows as a badge.
enum NavBadge {
  /// No badge.
  none,

  /// Total unread client messages (답장 필요).
  unreadMessages,

  /// Today's booked session count.
  todayReservations,
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
    required this.group,
    this.badge = NavBadge.none,
  });

  /// Korean label shown in the expanded sidebar / rail tooltip.
  final String label;

  /// Icon in the unselected state.
  final IconData icon;

  /// Icon in the selected state.
  final IconData activeIcon;

  /// Branch root location.
  final String route;

  /// Which sidebar group this belongs to.
  final NavGroup group;

  /// Live counter rendered next to the label.
  final NavBadge badge;
}

/// The console's five destinations, in branch order.
const List<NavDestination> navDestinations = <NavDestination>[
  NavDestination(
    label: '대시보드',
    icon: Icons.space_dashboard_outlined,
    activeIcon: Icons.space_dashboard,
    route: AppRoutes.dashboard,
    group: NavGroup.operations,
  ),
  NavDestination(
    label: '고객',
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    route: AppRoutes.clients,
    group: NavGroup.operations,
    badge: NavBadge.unreadMessages,
  ),
  NavDestination(
    label: '스케줄',
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_today,
    route: AppRoutes.schedule,
    group: NavGroup.operations,
    badge: NavBadge.todayReservations,
  ),
  NavDestination(
    label: 'AI 코칭',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
    route: AppRoutes.coaching,
    group: NavGroup.coaching,
  ),
  NavDestination(
    label: '리포트',
    icon: Icons.insights_outlined,
    activeIcon: Icons.insights,
    route: AppRoutes.reports,
    group: NavGroup.coaching,
  ),
];
