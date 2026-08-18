import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/presentation/widgets/trainer_chat_header_button.dart';
import 'package:oncare/features/my_health/domain/entities/health_history.dart';
import 'package:oncare/features/my_health/presentation/controllers/my_health_controller.dart';
import 'package:oncare/features/my_health/presentation/widgets/my_flows.dart';
import 'package:oncare/features/notification/presentation/controllers/notification_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// MY tab, rebuilt to the On-Care Figma redesign: profile, role toggle
/// (the trainer app is intentionally not built), an activity-points banner,
/// the settings list, and logout.
/// Stable identifiers for the settings rows, decoupled from their localized
/// display labels so the switch never keys off a translated string.
enum _MySetting { profile, goals, notif, support }

class MyHealthPage extends ConsumerWidget {
  const MyHealthPage({super.key});

  void _openSetting(BuildContext context, _MySetting id) {
    switch (id) {
      case _MySetting.profile:
        openProfilePage(context);
      case _MySetting.goals:
        openGoalsPage(context);
      case _MySetting.notif:
        openNotificationSettingsPage(context);
      case _MySetting.support:
        openSupportPage(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<MyHealthState> health = ref.watch(myHealthStateProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 108),
              children: <Widget>[
                FigmaTabHeader(
                  title: l.myTabTitle,
                  trailingAction: const TrainerChatHeaderButton(),
                  onBell: () => context.push(AppRoutes.notification),
                  bellHasUnread:
                      (ref.watch(notificationUnreadProvider).valueOrNull ?? 0) > 0,
                  onCalendar: () => showScheduleCalendarSheet(context),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _ProfileCard(profile: health.valueOrNull?.profile),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _PointsBanner(
                    points: health.valueOrNull?.activityPoints,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _TrainerGymSection(
                    onFindGym: () => context.go(AppRoutes.exerciseGym),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _Settings(
                    onTap: (_MySetting id) => _openSetting(context, id),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _LogoutButton(
                    onTap: () async {
                      final bool ok =
                          await showDialog<bool>(
                            context: context,
                            builder: (BuildContext ctx) => AlertDialog(
                              title: Text(l.myLogout),
                              content: Text(l.myLogoutConfirm),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(l.myCancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(l.myLogout),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!ok) return;
                      await ref
                          .read(sessionControllerProvider.notifier)
                          .signOut();
                      if (context.mounted) context.go(AppRoutes.signIn);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String name = profile?.name ?? '';
    final String email = profile?.email ?? '';
    final String initial = name.isNotEmpty ? name.substring(0, 1) : '·';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[FigmaColors.primary, FigmaColors.primaryDeep],
              ),
              border: Border.all(color: FigmaColors.primary, width: 2.5),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name.isEmpty ? l.myDefaultUserName : name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsBanner extends StatelessWidget {
  const _PointsBanner({required this.points});

  final int? points;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('pointsBanner'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPointsBenefitsPage(context, points),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: FigmaColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.star_border_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              points != null ? '${points}P' : '—P',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            const _PointsInfoButton(),
            const Spacer(),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens point benefits as a full page above the member tab shell.
Future<void> _openPointsBenefitsPage(BuildContext context, int? points) {
  return context.push<void>(AppRoutes.myPoints, extra: points);
}

/// A point redemption option shown in the benefits sheet.
class _PointBenefit {
  const _PointBenefit({
    required this.icon,
    required this.title,
    required this.desc,
    required this.cost,
  });
  final IconData icon;
  final String title;
  final String desc;
  final String cost;
}

List<_PointBenefit> _pointBenefitsOf(AppLocalizations l) => <_PointBenefit>[
  _PointBenefit(
    icon: Icons.savings_rounded,
    title: l.myPointsDiscountTitle,
    desc: l.myPointsDiscountDescription,
    cost: l.myPointsDiscountCost,
  ),
  _PointBenefit(
    icon: Icons.lock_open_rounded,
    title: l.myPointsReportTitle,
    desc: l.myPointsReportDescription,
    cost: l.myPointsReportCost,
  ),
  _PointBenefit(
    icon: Icons.menu_book_rounded,
    title: l.myPointsRecipeTitle,
    desc: l.myPointsRecipeDescription,
    cost: l.myPointsRecipeCost,
  ),
];

class PointsBenefitsPage extends StatelessWidget {
  const PointsBenefitsPage({super.key, required this.points});

  final int? points;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<_PointBenefit> benefits = _pointBenefitsOf(l);
    return Scaffold(
      key: const Key('pointsBenefitsPage'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          l.myPointsBenefitsTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: <Widget>[
                Text(
                  points != null
                      ? l.myPointsBalance(points!)
                      : l.myPointsBenefitsSubtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < benefits.length; i++) ...<Widget>[
                  _PointBenefitCard(benefit: benefits[i]),
                  if (i < benefits.length - 1) const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: FigmaColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.myPointsBenefitsHint,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.foreground,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PointBenefitCard extends StatelessWidget {
  const _PointBenefitCard({required this.benefit});

  final _PointBenefit benefit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FigmaColors.iconTint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(benefit.icon, size: 22, color: FigmaColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        benefit.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: FigmaColors.primaryA(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        benefit.cost,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  benefit.desc,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.foreground,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular "i" button on the points banner — taps open a sheet explaining how
/// points are earned.
class _PointsInfoButton extends StatelessWidget {
  const _PointsInfoButton();

  void _show(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.myPointsGuideTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PointRule(
              icon: Icons.restaurant_rounded,
              text: l.myPointsDietAdd,
              points: '+50P',
            ),
            const SizedBox(height: 10),
            _PointRule(
              icon: Icons.auto_awesome,
              text: l.myPointsAiExercise,
              points: '+50P',
            ),
            const SizedBox(height: 10),
            _PointRule(
              icon: Icons.fitness_center_rounded,
              text: l.myPointsExerciseAdd,
              points: '+20P',
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: FigmaColors.primary),
            child: Text(l.actionConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _show(context),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.info_outline, size: 15, color: Colors.white),
      ),
    );
  }
}

class _PointRule extends StatelessWidget {
  const _PointRule({
    required this.icon,
    required this.text,
    required this.points,
  });

  final IconData icon;
  final String text;
  final String points;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FigmaColors.primaryA(0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: FigmaColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FigmaColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          points,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: FigmaColors.primary,
          ),
        ),
      ],
    );
  }
}

class _SettingItem {
  const _SettingItem(this.icon, this.id);
  final IconData icon;
  final _MySetting id;
}

class _Settings extends StatelessWidget {
  const _Settings({required this.onTap});
  final ValueChanged<_MySetting> onTap;

  static const List<_SettingItem> _items = <_SettingItem>[
    _SettingItem(Icons.person_outline, _MySetting.profile),
    _SettingItem(Icons.flag_outlined, _MySetting.goals),
    _SettingItem(Icons.notifications_none_rounded, _MySetting.notif),
    _SettingItem(Icons.chat_bubble_outline_rounded, _MySetting.support),
  ];

  static String _label(AppLocalizations l, _MySetting id) {
    switch (id) {
      case _MySetting.profile:
        return l.myProfileTitle;
      case _MySetting.goals:
        return l.myHealthGoalsTitle;
      case _MySetting.notif:
        return l.myNotifTitle;
      case _MySetting.support:
        return l.mySupportTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l.mySettingsTitle,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FigmaColors.hairline),
            boxShadow: kCardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < _items.length; i++) ...<Widget>[
                _SettingRow(
                  icon: _items[i].icon,
                  label: _label(l, _items[i].id),
                  onTap: () => onTap(_items[i].id),
                ),
                if (i < _items.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 56),
                    child: Divider(height: 1, color: FigmaColors.hairline),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: FigmaColors.softBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: FigmaColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.ink,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: FigmaColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0x14FF3B30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout,
                  size: 16,
                  color: Color(0xFFFF3B30),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l.myLogout,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF3B30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 내 트레이너 · 헬스장 섹션
// ──────────────────────────────────────────────

class _TrainerGymSection extends ConsumerWidget {
  const _TrainerGymSection({required this.onFindGym});

  /// 연결된 헬스장이 없을 때 "헬스장 찾기"로 보낼 콜백.
  final VoidCallback onFindGym;

  /// 확인 창을 띄우고, 승인되면 [disconnect] 를 실행한 뒤 연결 상태를 새로
  /// 읽는다. 헬스장·트레이너 두 삭제가 같은 흐름을 쓴다.
  Future<void> _confirmDisconnect(
    BuildContext context,
    WidgetRef ref, {
    required String message,
    required Future<void> Function(GymRepository repo) disconnect,
  }) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              l.myConnectionDeleteTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: FigmaColors.ink,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 14.5,
                color: AppColors.foreground,
                height: 1.4,
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mutedForeground,
                ),
                child: Text(l.myCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                ),
                child: Text(l.myDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await disconnect(ref.read(gymRepositoryProvider));
    // 해제를 기다리는 동안 탭을 벗어났다면 ref 가 이미 폐기됐을 수 있다.
    if (!context.mounted) return;
    // 헬스장 해제는 트레이너까지 끊으므로 두 provider 를 함께 새로 읽는다.
    ref.invalidate(myGymProvider);
    ref.invalidate(myTrainerProvider);
  }

  /// 헬스장 연결 삭제. 담당 트레이너가 있으면 함께 사라진다는 것을 알린다.
  Future<void> _removeGym(
    BuildContext context,
    WidgetRef ref,
    Gym gym,
    Trainer? trainer,
  ) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _confirmDisconnect(
      context,
      ref,
      message: trainer == null
          ? l.myGymDisconnectConfirm(gym.name)
          : l.myGymDisconnectWithTrainerConfirm(gym.name, trainer.name),
      disconnect: (GymRepository repo) => repo.disconnectMyGym(),
    );
  }

  /// 헬스장은 그대로 두고 담당 트레이너 연결만 삭제.
  Future<void> _removeTrainer(
    BuildContext context,
    WidgetRef ref,
    Gym gym,
    Trainer trainer,
  ) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _confirmDisconnect(
      context,
      ref,
      message: l.myTrainerDisconnectConfirm(trainer.name, gym.name),
      disconnect: (GymRepository repo) => repo.disconnectMyTrainer(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<Gym?> gymAsync = ref.watch(myGymProvider);
    final Trainer? trainer = ref.watch(myTrainerProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l.myTrainerGymTitle,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        gymAsync.when(
          loading: () => const _GymSectionLoading(),
          error: (_, _) =>
              _GymSectionError(onRetry: () => ref.invalidate(myGymProvider)),
          data: (Gym? gym) => gym == null
              ? _GymSectionEmpty(onFind: onFindGym)
              : _GymSummaryCard(
                  gym: gym,
                  trainer: trainer,
                  onRemoveGym: () => _removeGym(context, ref, gym, trainer),
                  onRemoveTrainer: trainer == null
                      ? null
                      : () => _removeTrainer(context, ref, gym, trainer),
                  // 헬스장은 이미 연결돼 있고 트레이너만 없는 상태다. 헬스장을
                  // 찾는 화면이 아니라 **그 헬스장의 소속 트레이너**로 보낸다 —
                  // 예전에는 라벨이 '트레이너 찾기'인데 헬스장 탭으로 갔다(#793).
                  onFindTrainer: () =>
                      context.push(AppRoutes.gymDetailPath(gym.id)),
                ),
        ),
      ],
    );
  }
}

/// 연결된 헬스장과 담당 트레이너를 각각 한 줄로 보여준다. 두 연결은 따로
/// 관리된다 — 트레이너만 떼거나, 헬스장을 떼면서 함께 정리하거나.
class _GymSummaryCard extends StatelessWidget {
  const _GymSummaryCard({
    required this.gym,
    required this.trainer,
    required this.onRemoveGym,
    required this.onRemoveTrainer,
    required this.onFindTrainer,
  });

  final Gym gym;

  /// 담당 트레이너. null 이면 "담당 트레이너 없음" 행으로 대체된다.
  final Trainer? trainer;
  final VoidCallback onRemoveGym;
  final VoidCallback? onRemoveTrainer;

  /// 헬스장은 있는데 담당 트레이너가 없을 때 트레이너를 찾으러 보낸다.
  final VoidCallback onFindTrainer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Trainer? trainer = this.trainer;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FigmaColors.primaryA(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 18,
                    color: FigmaColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        gym.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.ink,
                        ),
                      ),
                      Text(
                        '${gym.address} · ${gym.distanceKm.toStringAsFixed(1)}km',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                _RemoveLinkButton(
                  tooltip: l.myGymDisconnectTooltip,
                  onTap: onRemoveGym,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: FigmaColors.hairline),
            const SizedBox(height: 12),
            if (trainer != null)
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.person_outline,
                    size: 15,
                    color: FigmaColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${trainer.name} · ${trainer.role ?? l.exTrainerDedicated}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  if (onRemoveTrainer != null)
                    _RemoveLinkButton(
                      tooltip: l.myTrainerDisconnectTooltip,
                      onTap: onRemoveTrainer!,
                    ),
                ],
              )
            else
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.person_off_outlined,
                    size: 15,
                    color: FigmaColors.textFaint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.myNoTrainer,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onFindTrainer,
                    style: TextButton.styleFrom(
                      foregroundColor: FigmaColors.primary,
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      l.exFindTrainer,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 한 줄짜리 연결(헬스장 또는 트레이너)을 끊는 버튼. 시각적 아이콘은 20이지만
/// 탭 영역은 접근성 최소 44×44 를 지킨다.
class _RemoveLinkButton extends StatelessWidget {
  const _RemoveLinkButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: FigmaColors.textFaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GymSectionEmpty extends StatelessWidget {
  const _GymSectionEmpty({required this.onFind});

  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: <Widget>[
          Text(
            l.myNoGymConnected,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onFind,
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.primary,
              side: BorderSide(color: FigmaColors.primaryA(0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.search, size: 16),
            label: Text(
              l.exFindGym,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GymSectionLoading extends StatelessWidget {
  const _GymSectionLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _GymSectionError extends StatelessWidget {
  const _GymSectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: <Widget>[
          Text(
            l.myGymLoadFailed,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.foreground),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(l.actionRetry)),
        ],
      ),
    );
  }
}
