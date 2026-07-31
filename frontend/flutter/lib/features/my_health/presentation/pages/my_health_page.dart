import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare/features/my_health/domain/entities/health_history.dart';
import 'package:oncare/features/my_health/presentation/controllers/my_health_controller.dart';
import 'package:oncare/features/my_health/presentation/widgets/my_flows.dart';
import 'package:oncare/features/notification/presentation/widgets/notification_panel.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/modals/right_slide_panel.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// MY tab, rebuilt to the On-Care Figma redesign: profile, role toggle
/// (the trainer app is intentionally not built), an activity-points banner,
/// the settings list, and logout.
/// Stable identifiers for the settings rows, decoupled from their localized
/// display labels so the switch never keys off a translated string.
enum _MySetting { profile, notif, support }

class MyHealthPage extends ConsumerWidget {
  const MyHealthPage({super.key});

  void _openSetting(BuildContext context, _MySetting id) {
    switch (id) {
      case _MySetting.profile:
        showProfileSheet(context);
      case _MySetting.notif:
        showNotifSheet(context);
      case _MySetting.support:
        showSupportSheet(context);
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
                  onBell: () => showRightSlidePanel<void>(
                    context,
                    content: const NotificationPanelBody(),
                  ),
                  onCalendar: () => showScheduleCalendarSheet(context),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _ProfileCard(
                    profile: health.valueOrNull?.profile,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _PointsBanner(
                    points: health.valueOrNull?.activityPoints,
                    rank: health.valueOrNull?.activityRank,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.textMuted,
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
  const _PointsBanner({required this.points, required this.rank});

  final int? points;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: FigmaColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.star_border_rounded, color: Colors.white, size: 24),
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
          const Spacer(),
          if (rank != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l.myRank(rank!),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          const SizedBox(width: 8),
          const _PointsInfoButton(),
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
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '포인트 적립 안내',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PointRule(
              icon: Icons.restaurant_rounded,
              text: '식단 추가',
              points: '+50P',
            ),
            SizedBox(height: 10),
            _PointRule(
              icon: Icons.auto_awesome,
              text: 'AI 추천 운동 완료',
              points: '+50P',
            ),
            SizedBox(height: 10),
            _PointRule(
              icon: Icons.fitness_center_rounded,
              text: '운동 직접 추가',
              points: '+20P',
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: FigmaColors.primary),
            child: const Text('확인'),
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FigmaColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          points,
          style: const TextStyle(
            fontSize: 14,
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
    _SettingItem(Icons.notifications_none_rounded, _MySetting.notif),
    _SettingItem(Icons.chat_bubble_outline_rounded, _MySetting.support),
  ];

  static String _label(AppLocalizations l, _MySetting id) {
    switch (id) {
      case _MySetting.profile:
        return l.myProfileTitle;
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
            fontSize: 14,
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
                  fontSize: 14,
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
                  fontSize: 14,
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
