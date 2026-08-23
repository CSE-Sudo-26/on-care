import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/app/shell/app_shell.dart';
import 'package:oncare_trainer/app/shell/nav_destinations.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare_trainer/features/my/data/trainer_settings.dart';
import 'package:oncare_trainer/features/notifications/data/repositories/notification_repository.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

/// The console's left navigation column.
///
/// Three presentations, all driven by [expanded] / the host's breakpoint:
///  * expanded (≥ [AppLayout.sidebarExpandBreakpoint]) — brand, grouped
///    labelled destinations, trainer profile footer;
///  * rail (≥ [AppLayout.sidebarDrawerBreakpoint]) — icons + tooltips;
///  * drawer (below that) — the expanded form inside a [Drawer].
///
/// The profile footer is deliberately NOT a nav destination: 내 정보 /
/// 설정 is opened once in a while, so it sits below the divider rather
/// than competing with the five daily surfaces.
class AppSidebar extends ConsumerWidget {
  /// Creates the sidebar.
  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.expanded,
    this.profileSelected = false,
    this.onNavigate,
  });

  /// Index of the active branch (matches [navDestinations] order). Values
  /// beyond the destination list (the 내 정보 branch) select nothing.
  final int currentIndex;

  /// Whether the 내 정보 / 설정 branch is active — highlights the footer
  /// instead of a nav row.
  final bool profileSelected;

  /// Invoked with the branch index when a destination is tapped.
  final ValueChanged<int> onSelect;

  /// Whether labels are shown (false renders the icon rail).
  final bool expanded;

  /// Called after any navigation — the drawer host uses it to close
  /// itself so the drawer doesn't stay open over the new page.
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Badges are live counters, not decoration: they're the reason a
    // trainer looks at the sidebar between tasks.
    // 알림 설정이 이 배지를 끈다 — 설정 화면이 "사이드바 뱃지로 알려드려요"
    // 라고 적어 두고 정작 아무 데서도 읽지 않아, 꺼도 배지가 그대로였다(#817).
    final settings = ref.watch(trainerSettingsProvider);
    final unread = settings.newMessageAlerts
        ? ref
              .watch(unreadCountsProvider)
              .valueOrNull
              ?.values
              .fold<int>(0, (sum, n) => sum + n)
        : null;
    // 완료한 수업은 빠진 '남은 일감' 수. 대시보드 KPI 의 '오늘 예약' 과는
    // 다른 숫자이고, 달라야 한다(#860).
    final pendingSessions = ref
        .watch(todayPendingSessionCountProvider)
        .valueOrNull;
    final profile = ref.watch(sessionControllerProvider).profile;
    // 상담 요청 only exists against the real API — the demo has no member
    // backend to receive requests from, so the row is not built at all
    // there and the demo sidebar stays exactly as it was. (#467)
    // 알림함도 실 API 빌드에서만 — 데모에는 알림을 만드는 회원 백엔드가 없어
    // 늘 비어 있는 행이 하나 더 생길 뿐이다. (#503)
    final notificationInbox = ref.watch(notificationInboxEnabledProvider);
    final unreadNotifications = notificationInbox
        ? ref.watch(trainerUnreadNotificationsProvider).valueOrNull
        : null;

    return Container(
      width: expanded ? AppLayout.sidebarWidth : AppLayout.sidebarRailWidth,
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(right: BorderSide(color: AppColors.borderStrong)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Brand(expanded: expanded),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                children: <Widget>[
                  for (var i = 0; i < navDestinations.length; i++) ...<Widget>[
                    if (expanded && (i == 0 || i == 4))
                      _NavGroupLabel(
                        label: i == 0
                            ? l.navOperationsGroup
                            : l.navCoachingGroup,
                      ),
                    _NavTile(
                      destination: navDestinations[i],
                      selected: currentIndex == i,
                      expanded: expanded,
                      badgeCount: switch (navDestinations[i].badge) {
                        NavBadge.unreadMessages => unread,
                        NavBadge.todayPendingSessions => pendingSessions,
                        // Not reachable from this loop — 상담 요청 is not in
                        // navDestinations and is rendered below with its
                        // count passed in directly.
                        NavBadge.pendingConsultations => null,
                        NavBadge.unreadNotifications => null,
                        NavBadge.none => null,
                      },
                      onTap: () {
                        onSelect(i);
                        onNavigate?.call();
                      },
                    ),
                  ],
                  if (notificationInbox)
                    _NavTile(
                      destination: notificationsDestination,
                      selected:
                          currentIndex == AppShell.notificationsBranchIndex,
                      expanded: expanded,
                      badgeCount: unreadNotifications,
                      onTap: () {
                        onSelect(AppShell.notificationsBranchIndex);
                        onNavigate?.call();
                      },
                    ),
                ],
              ),
            ),
            _ProfileFooter(
              profile: profile,
              expanded: expanded,
              selected: profileSelected,
              onTap: () {
                context.go(AppRoutes.my);
                onNavigate?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavGroupLabel extends StatelessWidget {
  const _NavGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.subtleForeground,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Logo + wordmark. The 트레이너 word keeps the navy primary so the two
/// On-Care clients read as one service with distinct audiences.
class _Brand extends StatelessWidget {
  const _Brand({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    // The logo art is already a filled circle — putting it on a rounded
    // square tile drew a second, competing shape around it.
    final logo = SizedBox(
      width: 40,
      height: 40,
      child: ClipOval(
        child: Image.asset(
          'assets/images/oncare-logo.png',
          fit: BoxFit.cover,
          // The logo is a bundled asset; if it ever fails to decode, fall
          // back to a glyph rather than blowing a red box into the shell.
          errorBuilder: (context, error, stack) =>
              const Icon(Icons.favorite, size: 26, color: AppColors.primary),
        ),
      ),
    );

    return Container(
      // Taller than the page header so the brand has room to breathe now
      // that no rule separates it from the nav.
      height: AppLayout.pageHeaderHeight + AppSpacing.lg,
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? AppSpacing.lg : AppSpacing.md,
      ),
      alignment: expanded ? Alignment.centerLeft : Alignment.center,
      child: expanded
          ? Row(
              children: <Widget>[
                logo,
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  // 서비스 이름이 `On-Care 트레…` 가 되면 이 콘솔이 무엇인지가
                  // 사라진다 — 좁으면 글씨를 줄인다. (#1004)
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          const TextSpan(
                            text: 'On-Care ',
                            style: TextStyle(color: AppColors.foreground),
                          ),
                          TextSpan(
                            text: AppLocalizations.of(
                              context,
                            ).appWordmarkTrainer,
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ],
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            )
          : Tooltip(
              message: AppLocalizations.of(context).appTitle,
              child: logo,
            ),
    );
  }
}

/// One destination row. Active state is a soft navy surface plus a left
/// indicator rather than a solid navy pill — the pages themselves lean
/// on navy for their own emphasis, and two saturated navies fight.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.badgeCount,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool expanded;
  final int? badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = navLabel(AppLocalizations.of(context), destination.label);
    final color = selected ? AppColors.primary : AppColors.mutedForeground;
    final icon = Icon(
      selected ? destination.activeIcon : destination.icon,
      size: 20,
      color: color,
    );

    final row = Container(
      height: 42,
      padding: EdgeInsets.symmetric(horizontal: expanded ? AppSpacing.md : 0),
      alignment: expanded ? Alignment.centerLeft : Alignment.center,
      child: expanded
          ? Row(
              children: <Widget>[
                icon,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount! > 0)
                  _Badge(count: badgeCount!),
              ],
            )
          : Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: <Widget>[
                icon,
                if (badgeCount != null && badgeCount! > 0)
                  // width/height 를 명시해야 Stack 의 느슨한 제약과 무관하게
                  // _Badge 가 항상 고정 20×20 정원으로 그려진다 — 없으면
                  // 아이콘 위에 음수 오프셋으로 겹쳐 그리는 이 경계 조건에서
                  // 배지가 살짝 세로로 긴 타원으로 찌그러진다.
                  Positioned(
                    top: -4,
                    right: -10,
                    width: 20,
                    height: 20,
                    child: _Badge(count: badgeCount!),
                  ),
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        selected: selected,
        button: true,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? AppColors.accentSurface : Colors.transparent,
          borderRadius: const BorderRadius.all(AppRadius.md),
          child: InkWell(
            key: ValueKey<String>('sidebar-${destination.route}'),
            onTap: onTap,
            borderRadius: const BorderRadius.all(AppRadius.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(AppRadius.md),
                border: Border(
                  left: BorderSide(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: expanded ? row : Tooltip(message: label, child: row),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // A fixed circle, not a stretching pill: the counts here are small
    // (unread threads, today's bookings) and a dot that changes width
    // with the number makes the nav rows look ragged.
    final label = count > 99 ? '99+' : '$count';
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          // 3 characters ("99+") only fit at a smaller size inside a
          // fixed circle.
          fontSize: label.length > 2 ? 8.5 : 10.5,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryForeground,
        ),
      ),
    );
  }
}

/// Trainer identity + the entry to 내 정보 / 설정.
class _ProfileFooter extends StatelessWidget {
  const _ProfileFooter({
    required this.profile,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final TrainerProfile? profile;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Demo mode carries no profile; fall back to the seed identity so
    // the footer never renders as a nameless blank.
    final name = profile?.name ?? seedTrainerProfile.name;
    final gym = profile?.gym.name ?? seedTrainerProfile.gym.name;
    final avatar = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentSurface,
      ),
      child: Text(
        name.isEmpty
            ? AppLocalizations.of(context).appAvatarFallback
            : String.fromCharCode(name.runes.first),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.accentSurface : Colors.transparent,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: InkWell(
          key: const ValueKey<String>('sidebar-profile'),
          onTap: onTap,
          borderRadius: const BorderRadius.all(AppRadius.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? AppSpacing.sm : 0,
              vertical: AppSpacing.sm,
            ),
            child: expanded
                ? Row(
                    children: <Widget>[
                      avatar,
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              gym,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.subtleForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.settings_outlined,
                        size: 16,
                        color: AppColors.subtleForeground,
                      ),
                    ],
                  )
                : Tooltip(
                    message: AppLocalizations.of(
                      context,
                    ).sidebarMyTooltip(name),
                    child: avatar,
                  ),
          ),
        ),
      ),
    );
  }
}
