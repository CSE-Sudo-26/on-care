import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/diet/presentation/widgets/diet_flows.dart';
import 'package:oncare/features/exercise/presentation/widgets/exercise_flows.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/coaching_sheet.dart';
import 'package:oncare/shared/widgets/oni_fab.dart';

/// Persistent `Scaffold` hosting the bottom navigation bar. Icons and
/// labels mirror the original React `BottomNav.tsx` (Home / 식단 /
/// 운동 / My).
class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    const double barHeight = 64;
    const double lift = 24; // headroom so the + button floats above the bar
    return Scaffold(
      body: navigationShell,
      floatingActionButton: OniFab(onTap: () => showCoachingSheet(context)),
      bottomNavigationBar: SizedBox(
        height: barHeight + lift + bottomInset,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Nav bar pinned to the bottom. The middle slot is left empty
                // so the floating + button has room between 식단 and 운동.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: barHeight + bottomInset,
                    padding: EdgeInsets.only(bottom: bottomInset),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: <Widget>[
                        _Destination(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home,
                          label: l.navDashboard,
                          selected: navigationShell.currentIndex == 0,
                          onTap: () => _onTap(0),
                        ),
                        _Destination(
                          icon: Icons.restaurant_outlined,
                          activeIcon: Icons.restaurant,
                          label: l.navDiet,
                          selected: navigationShell.currentIndex == 1,
                          onTap: () => _onTap(1),
                        ),
                        const SizedBox(width: 64),
                        _Destination(
                          icon: Icons.fitness_center_outlined,
                          activeIcon: Icons.fitness_center,
                          label: l.navExercise,
                          selected: navigationShell.currentIndex == 2,
                          onTap: () => _onTap(2),
                        ),
                        _Destination(
                          icon: Icons.person_outline,
                          activeIcon: Icons.person,
                          label: l.navMyHealth,
                          selected: navigationShell.currentIndex == 3,
                          onTap: () => _onTap(3),
                        ),
                      ],
                    ),
                  ),
                ),
                // Floating + button straddling the bar's top edge.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _NavAddButton(
                      onTap: () => _showRecordAddSheet(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(int index) {
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
    final color = selected ? AppColors.primary : AppColors.mutedForeground;
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
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The circular "+" button docked in the centre of the bottom nav bar, between
/// 식단 and 운동. Opens the "새 기록 추가" chooser. Mirrors the Figma bottom-nav FAB.
class _NavAddButton extends StatelessWidget {
  const _NavAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: FigmaColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

/// "새 기록 추가" chooser opened by the bottom-nav + button. Routes to the diet
/// or exercise add flow. Mirrors the Figma add sheet.
Future<void> _showRecordAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => _RecordAddSheet(
      onDiet: () {
        Navigator.of(ctx).pop();
        showDietAddSheet(context);
      },
      onExercise: () {
        Navigator.of(ctx).pop();
        showExerciseAddSheet(context);
      },
    ),
  );
}

class _RecordAddSheet extends StatelessWidget {
  const _RecordAddSheet({required this.onDiet, required this.onExercise});

  final VoidCallback onDiet;
  final VoidCallback onExercise;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        // Match the main content width so the sheet scales with the viewport
        // like the tab pages. The theme lifts the modal route cap to this
        // width too (see AppTheme._bottomSheetTheme); this centres the child.
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE3EA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l.navAddRecordTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: FigmaColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.navAddRecordSubtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: FigmaColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SheetCloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _RecordOption(
                        icon: Icons.restaurant,
                        iconColor: FigmaColors.primary,
                        iconBg: FigmaColors.softBlue,
                        borderColor: FigmaColors.primary.withValues(
                          alpha: 0.35,
                        ),
                        title: l.navDiet,
                        subtitle: l.navDietOptionSub,
                        onTap: onDiet,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _RecordOption(
                        icon: Icons.fitness_center,
                        iconColor: FigmaColors.green,
                        iconBg: const Color(0xFFEAF8F2),
                        borderColor: FigmaColors.green.withValues(alpha: 0.35),
                        title: l.navExercise,
                        subtitle: l.navExerciseOptionSub,
                        onTap: onExercise,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordOption extends StatelessWidget {
  const _RecordOption({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color borderColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: FigmaColors.textSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F6F8),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.close, size: 16, color: FigmaColors.textSub),
        ),
      ),
    );
  }
}
