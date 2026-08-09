import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/shell/app_sidebar.dart';
import 'package:oncare_trainer/app/shell/nav_destinations.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// Persistent console shell: a left [AppSidebar] plus the active branch.
///
/// The trainer surface is a desktop/tablet web console, so navigation is
/// a vertical sidebar rather than the phone-era bottom tab bar. Three
/// responsive forms, keyed off the viewport:
///
/// | 뷰포트 | 형태 |
/// | --- | --- |
/// | ≥ 1280 | 사이드바 펼침 (아이콘 + 라벨 + 프로필) |
/// | ≥ 1024 | 아이콘 레일 (라벨은 툴팁) |
/// | < 1024 | 드로어 + 상단 메뉴 버튼 |
///
/// Branch order matches [navDestinations]; the trailing branch (내 정보 /
/// 설정) has no nav row — it is reached from the sidebar footer.
class AppShell extends StatelessWidget {
  /// Creates the shell around the current [navigationShell] branch.
  const AppShell({required this.navigationShell, super.key});

  /// The indexed-stack shell driving branch switching + state retention.
  final StatefulNavigationShell navigationShell;

  /// Branch index of the 내 정보 / 설정 page — the one branch that is not
  /// a nav destination.
  static int get myBranchIndex => navDestinations.length;

  /// Branch index of 상담 요청. Sits after [myBranchIndex] so adding it
  /// could not shift any existing branch. (#467)
  static int get consultationsBranchIndex => myBranchIndex + 1;

  /// Branch index of 알림함. 상담 요청과 같은 이유로 맨 뒤에 붙인다 — 앞에
  /// 끼우면 `myBranchIndex` 가 밀려 푸터 선택이 조용히 깨진다. (#503)
  static int get notificationsBranchIndex => consultationsBranchIndex + 1;

  void _goBranch(int index) {
    // Tapping the active destination resets it to its branch root (e.g.
    // 고객 상세에서 l.clientsTitle을 다시 누르면 목록으로) — the standard console
    // behaviour; tapping another switches branch, keeping its state.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < AppLayout.sidebarDrawerBreakpoint;
    final expanded = width >= AppLayout.sidebarExpandBreakpoint;
    final onMy = navigationShell.currentIndex == myBranchIndex;

    if (compact) {
      return Scaffold(
        backgroundColor: AppColors.background,
        drawer: Drawer(
          width: AppLayout.sidebarWidth,
          backgroundColor: AppColors.card,
          child: Builder(
            builder: (drawerContext) => AppSidebar(
              currentIndex: navigationShell.currentIndex,
              profileSelected: onMy,
              expanded: true,
              onSelect: _goBranch,
              onNavigate: () => Navigator.of(drawerContext).maybePop(),
            ),
          ),
        ),
        appBar: const _CompactBar(),
        body: navigationShell,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSidebar(
            currentIndex: navigationShell.currentIndex,
            profileSelected: onMy,
            expanded: expanded,
            onSelect: _goBranch,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

/// Top bar for the drawer (narrow) form — the menu button plus the
/// wordmark, since the sidebar's brand block is off-screen there.
class _CompactBar extends StatelessWidget implements PreferredSizeWidget {
  const _CompactBar();

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AppBar(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 52,
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: AppColors.mutedForeground),
      shape: const Border(bottom: BorderSide(color: AppColors.borderStrong)),
      title: Padding(
        padding: EdgeInsets.only(left: AppSpacing.xs),
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: 'On-Care ',
                style: TextStyle(color: AppColors.foreground),
              ),
              TextSpan(
                text: l.appWordmarkTrainer,
                style: TextStyle(color: AppColors.primary),
              ),
            ],
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
