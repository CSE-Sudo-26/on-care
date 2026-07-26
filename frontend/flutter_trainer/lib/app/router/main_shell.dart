import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/shared/widgets/brand_header.dart';

/// Persistent [Scaffold] hosting the trainer bottom navigation bar.
/// Tabs mirror the On-Care Figma trainer app (고객 / 스케줄 / AI루틴 / MY)
/// with the trainer orange active tint.
class MainShell extends StatelessWidget {
  /// Creates the shell around the current [navigationShell] branch.
  const MainShell({required this.navigationShell, super.key});

  /// The indexed-stack shell driving branch switching + state retention.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BrandHeader(),
      // Each tab page frames (centers + caps) its own content — the
      // 고객 탭 needs a wider cap for the master-detail split, so the
      // shell no longer imposes a single width here.
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.borderStrong)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.contentMaxWidth,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _Destination(
                      icon: Icons.people_outline,
                      activeIcon: Icons.people,
                      label: '고객',
                      selected: navigationShell.currentIndex == 0,
                      onTap: () => _onTap(0),
                    ),
                    _Destination(
                      icon: Icons.calendar_today_outlined,
                      activeIcon: Icons.calendar_today,
                      label: '스케줄',
                      selected: navigationShell.currentIndex == 1,
                      onTap: () => _onTap(1),
                    ),
                    _Destination(
                      icon: Icons.auto_awesome_outlined,
                      activeIcon: Icons.auto_awesome,
                      label: 'AI루틴',
                      selected: navigationShell.currentIndex == 2,
                      onTap: () => _onTap(2),
                    ),
                    _Destination(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'MY',
                      selected: navigationShell.currentIndex == 3,
                      onTap: () => _onTap(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(int index) {
    // Tapping the active tab resets it to its initial location; tapping
    // another switches branch (indexedStack retains each branch's state).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.subtleForeground;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(selected ? activeIcon : icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
