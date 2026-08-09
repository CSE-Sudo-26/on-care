import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/atoms/app_badge.dart';
import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/theme/app_theme.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/notification/domain/entities/alert_item.dart';
import 'package:oncare/features/notification/presentation/controllers/notification_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/empty_state.dart';

({String label, AppBadgeTone tone}) _categoryDisplay(AlertCategory c) =>
    switch (c) {
      AlertCategory.reminder => (label: '리마인더', tone: AppBadgeTone.info),
      AlertCategory.healthCheck => (label: '건강', tone: AppBadgeTone.warning),
      AlertCategory.achievement => (label: '달성', tone: AppBadgeTone.success),
      AlertCategory.system => (label: '시스템', tone: AppBadgeTone.neutral),
    };

class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final state = ref.watch(notificationControllerProvider);
    final notifier = ref.read(notificationControllerProvider.notifier);

    final Widget page = Scaffold(
      key: const Key('notificationPage'),
      appBar: AppBar(
        title: Text(l.pageNotificationTitle),
        actions: <Widget>[
          TextButton(
            onPressed: state.unreadCount == 0 ? null : notifier.markAllRead,
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: state.items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: '알림이 없습니다',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext ctx, int i) {
                final item = state.items[i];
                return _AlertTile(
                  item: item,
                  onTap: () => notifier.markRead(item.id),
                );
              },
            ),
      // 가상 푸시는 목/데모 모드 전용 개발 도구 — 실모드에서는 버튼을 숨긴다
      // (서버에 없는 팬텀 알림 방지, 죽은 버튼 방지).
      floatingActionButton: config.useMockApi
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.notification_add_outlined),
              label: const Text('Simulate push'),
              onPressed: notifier.simulatePush,
            )
          : null,
    );
    // The product currently has a light-only design. Keep this route on the
    // shared light theme even when ThemeMode.system selects the dark theme.
    return Theme(data: AppTheme.light(), child: page);
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.item, required this.onTap});
  final AlertItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = _categoryDisplay(item.category);
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6, right: AppSpacing.md),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.read ? Colors.transparent : theme.colorScheme.primary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AppBadge(label: display.label, tone: display.tone),
                    const Spacer(),
                    Text(item.timeAgo, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(item.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(item.body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
