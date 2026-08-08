import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/atoms/app_badge.dart';
import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/notification/domain/entities/alert_item.dart';
import 'package:oncare/features/notification/presentation/controllers/notification_controller.dart';

/// Body of the right-slide notification panel triggered by the bell
/// in `OncareHeader`. Same data as `NotificationPage` but presented
/// as an overlay.
class NotificationPanelBody extends ConsumerStatefulWidget {
  const NotificationPanelBody({super.key});

  @override
  ConsumerState<NotificationPanelBody> createState() =>
      _NotificationPanelBodyState();
}

class _NotificationPanelBodyState extends ConsumerState<NotificationPanelBody> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(notificationControllerProvider);
    final notifier = ref.read(notificationControllerProvider.notifier);

    final items = _unreadOnly
        ? state.items.where((AlertItem i) => !i.read).toList()
        : state.items;

    return Column(
      children: <Widget>[
        // Sticky header.
        Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '알림',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: state.unreadCount == 0
                      ? null
                      : notifier.markAllRead,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text('모두 읽음'),
                ),
                Material(
                  color: AppColors.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.close, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Text(
                '안 읽음만 보기',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              Switch(
                value: _unreadOnly,
                activeThumbColor: AppColors.primary,
                onChanged: (bool v) => setState(() => _unreadOnly = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    '표시할 알림이 없습니다',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.foreground,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext _, int i) {
                    final item = items[i];
                    return _NotificationTile(
                      item: item,
                      onTap: () => notifier.markRead(item.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

({String label, AppBadgeTone tone}) _categoryDisplay(AlertCategory c) =>
    switch (c) {
      AlertCategory.reminder => (label: '리마인더', tone: AppBadgeTone.info),
      AlertCategory.healthCheck => (label: '건강', tone: AppBadgeTone.warning),
      AlertCategory.achievement => (label: '달성', tone: AppBadgeTone.success),
      AlertCategory.system => (label: '시스템', tone: AppBadgeTone.neutral),
    };

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final AlertItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = _categoryDisplay(item.category);
    return AppCard(
      onTap: onTap,
      color: item.read ? null : AppColors.primary.withValues(alpha: 0.05),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.read ? Colors.transparent : AppColors.primary,
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
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
