import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:oncare/features/diet/presentation/pages/diet_record_page.dart';
import 'package:oncare/features/diet/presentation/widgets/diet_flows.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/pages/exercise_page.dart';
import 'package:oncare/features/exercise/presentation/widgets/exercise_flows.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/coaching_sheet.dart';
import 'package:oncare/shared/widgets/oni_fab.dart';

/// Persistent `Scaffold` hosting the bottom navigation bar. Icons and
/// labels mirror the original React `BottomNav.tsx` (Home / 식단 /
/// 운동 / My).
/// AI 조언 플로팅 버튼을 회원 화면에 띄울지. (#862)
///
/// **기능을 지우지 않고 노출만 끈 상태다.** AI 조언 화면·라우트(`/ai-coach`)·
/// 시트(`showCoachingSheet`)·배지(`coachingBadgeCountProvider`)는 모두 그대로고,
/// 홈의 `AI 조언` 배너가 같은 시트를 여는 진입점으로 남아 있다.
///
/// 이 기능의 최종 위치와 역할이 정해지면 값을 `true` 로 되돌리는 것으로 복원된다.
/// 지우지 않고 상수 하나로 둔 까닭이 그것이다 — 방향이 바뀌었을 때 다시 만드는
/// 비용을 치르지 않기 위해서다. 설정 화면이나 feature flag 체계를 새로 들이지도
/// 않는다: 지금 필요한 것은 "잠시 감춘다" 하나뿐이다.
const bool kShowCoachingFab = false;

class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  late int _lastIndex = widget.navigationShell.currentIndex;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int nextIndex = navigationShell.currentIndex;
    if (_lastIndex == nextIndex) return;
    _lastIndex = nextIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshBranch(nextIndex);
      _resetTransientUiState(nextIndex);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshMemberData();
  }

  void _refreshMemberData() {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(exerciseWeekProvider);
    ref.invalidate(coachRoutinesProvider);
    ref.invalidate(coachSessionsProvider);
  }

  void _refreshBranch(int index) {
    switch (index) {
      case 0:
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(coachSessionsProvider);
        break;
      case 2:
        ref.invalidate(exerciseWeekProvider);
        ref.invalidate(coachRoutinesProvider);
        ref.invalidate(coachSessionsProvider);
        break;
      default:
        break;
    }
  }

  /// 하단 탭을 다시 들어올 때 임시 UI 상태만 기본값으로 되돌린다(#861). 실제
  /// 기록·서버 데이터·설정·트레이너 프로그램은 각 탭의 provider 가 따로 들고
  /// 있어 여기서 건드리지 않는다 — 탭마다 무엇을 되돌릴지는 그 탭의 페이지가
  /// 정의한 `resetXxxTransientUiState` 가 안다.
  void _resetTransientUiState(int index) {
    switch (index) {
      case 0:
        resetDashboardTransientUiState(ref);
        break;
      case 1:
        resetDietTransientUiState(ref);
        break;
      case 2:
        resetExerciseTransientUiState(ref);
        break;
      // 3(MY)은 일부러 아무 것도 하지 않는다 — MY 탭은 펼침/접힘·임시 선택·
      // 일회성 필터 같은 화면 전용 위젯 상태(`StatefulWidget`/`setState`)를
      // 두지 않는다(`my_health_page.dart` 점검 결과, #861). 보이는 값은 전부
      // `myHealthStateProvider` 가 들고 있는 실제 저장 데이터라 초기화 대상이
      // 아니다.
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    const double maxNavBottomPadding = 22;
    final double navBottomPadding = bottomInset > maxNavBottomPadding
        ? maxNavBottomPadding
        : bottomInset;
    // 예전에는 라벨을 4dp 아래로 '그려서' 미는 바람에 바닥 여백이 0 인 웹에서
    // 글자 아래가 잘렸고, 그만큼을 웹에서만 따로 확보하고 있었다. 이제
    // 목적지 열이 바 높이 안에서 가운데 정렬되므로 그 보정은 필요 없다(#840).
    final double effectiveBottomPadding = navBottomPadding;
    // The larger navigation labels need a little more vertical room.
    const double barHeight = 58;
    const double lift = 24; // headroom so the + button floats above the bar
    return Scaffold(
      // Let the page continue behind the transparent FAB headroom instead of
      // showing a separate white strip above the navigation bar.
      extendBody: true,
      body: navigationShell,
      // AI 조언 진입점이 이 자리에 있을지가 아직 정해지지 않아 **노출만** 끈다
      // (#862). 기능·라우트·provider 는 그대로라, 자리가 정해지면 이 상수를
      // 되돌리는 것으로 복원된다 — 아래 [kShowCoachingFab] 주석 참고.
      floatingActionButton: kShowCoachingFab
          ? OniFab(
              key: const Key('coachingFab'),
              // 배지는 시트가 실제로 보여 줄 카드 수를 따른다. 열어서 확인하면
              // 내려간다.
              badgeCount: ref.watch(coachingBadgeCountProvider),
              onTap: () => showCoachingSheet(context, ref: ref),
            )
          : null,
      bottomNavigationBar: SizedBox(
        height: barHeight + lift + effectiveBottomPadding,
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
                    height: barHeight + effectiveBottomPadding,
                    padding: EdgeInsets.only(bottom: effectiveBottomPadding),
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
                          key: const ValueKey<String>('nav-exercise'),
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
    // 다른 탭에서 넘어올 때만 "재진입"이다 — 이미 보고 있는 탭을 다시 누른
    // 것뿐이면 사용자가 탭을 떠난 적이 없으므로 임시 UI 상태를 그대로 둔다.
    final bool isReentry = index != navigationShell.currentIndex;
    _lastIndex = index;
    _refreshBranch(index);
    if (isReentry) _resetTransientUiState(index);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    super.key,
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
        // 아이콘+라벨을 바 높이 안에서 가운데 정렬한다. 예전에는 위쪽 여백
        // 8dp 로 아래로 민 뒤 `Transform.translate` 로 4dp 더 밀었는데, 앞의
        // 여백이 열이 쓸 높이를 줄여 배율을 조금만 올려도 넘쳤고(#840), 뒤의
        // 밀기는 그리기 단계라 라벨 아래가 잘렸다.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(selected ? activeIcon : icon, size: 24, color: color),
            const SizedBox(height: 4),
            // 접근성 배율에서 라벨이 커져도 열이 넘치지 않게 줄여서 그린다 —
            // 잘라내면 '대시보드' 가 '대시…' 로 읽힌다.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
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
    // `GestureDetector` 는 버튼으로 인식되지 않고, 안에 있는 것은 `+` 아이콘
    // 하나뿐이라 무엇을 여는 자리인지 말할 데가 없다(#972).
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).navAddRecordTitle,
      child: GestureDetector(
        key: const Key('recordAddButton'),
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
      ),
    );
  }
}

/// "새 기록 추가" chooser opened by the bottom-nav + button. Routes to the diet
/// or exercise add flow. Mirrors the Figma add sheet.
Future<void> _showRecordAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // 하단 바·+ 버튼이 시트 위로 올라오지 않도록 루트에 올린다(#791).
    useRootNavigator: true,
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
    return ConstrainedBox(
      // Match the main content width so the sheet scales with the viewport
      // like the tab pages. The theme lifts the modal route cap to this
      // width too (see AppTheme._bottomSheetTheme); this centres the child.
      constraints: const BoxConstraints(
        maxWidth: AppBreakpoints.contentMaxWidth,
      ),
      child: Container(
        key: const Key('recordAddSheet'),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
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
                              fontSize: 14,
                              color: AppColors.mutedForeground,
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
                key: const Key('recordOptions'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: <Widget>[
                    // 식단은 초록, 운동은 파랑이다 (#1060). 앱 안에서 식단
                    // 그래프가 초록, 운동 그래프가 파랑인데 이 메뉴만 뒤집혀
                    // 있어, 같은 두 영역이 자리마다 색이 바뀌었다.
                    Expanded(
                      child: _RecordOption(
                        icon: Icons.restaurant,
                        iconColor: FigmaColors.green,
                        iconBg: const Color(0xFFEAF8F2),
                        borderColor: FigmaColors.green.withValues(alpha: 0.35),
                        title: l.navDiet,
                        subtitle: l.navDietOptionSub,
                        onTap: onDiet,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _RecordOption(
                        icon: Icons.fitness_center,
                        iconColor: FigmaColors.primary,
                        iconBg: FigmaColors.softBlue,
                        borderColor: FigmaColors.primary.withValues(
                          alpha: 0.35,
                        ),
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
                  fontSize: 13.5,
                  color: AppColors.mutedForeground,
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
        // 아이콘만 있는 버튼이라 무엇을 닫는지 말할 데가 없다(#972). 닫기는
        // 플랫폼이 이미 제 언어로 부르는 이름이 있다.
        child: Tooltip(
          message: MaterialLocalizations.of(context).closeButtonTooltip,
          child: const SizedBox(
            width: 32,
            height: 32,
            child: Icon(Icons.close, size: 16, color: FigmaColors.textSub),
          ),
        ),
      ),
    );
  }
}
