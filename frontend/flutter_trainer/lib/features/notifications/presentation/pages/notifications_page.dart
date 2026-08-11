import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/notifications/data/repositories/notification_repository.dart';
import 'package:oncare_trainer/features/notifications/domain/entities/trainer_notification.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 알림함 — 트레이너가 놓친 변화를 나중에 확인하는 자리. (#503)
///
/// 전에는 사이드바 배지와 대시보드 강조뿐이라, 그 순간을 지나가면 다시 볼
/// 방법이 없었다. 회원의 메시지·상담 요청·예약은 트레이너가 그 화면에 직접
/// 들어가야만 알 수 있었다.
///
/// 데모 빌드는 이 화면에 닿지 않는다 — 저장소가 인박스 없음을 보고하고
/// 사이드바 진입점이 그려지지 않는다([notificationInboxEnabledProvider]).
class NotificationsPage extends ConsumerWidget {
  /// Creates the inbox page.
  const NotificationsPage({super.key});

  /// 알림 종류별 이동할 곳. 모르는 종류는 이동하지 않는다.
  static String? _targetOf(TrainerNotificationKind kind) => switch (kind) {
    TrainerNotificationKind.message => AppRoutes.clients,
    TrainerNotificationKind.consultation => AppRoutes.schedule,
    TrainerNotificationKind.reservation => AppRoutes.schedule,
    TrainerNotificationKind.other => null,
  };

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    TrainerNotification notification,
  ) async {
    final String? target = _targetOf(notification.kind);
    // 읽음 처리는 이동과 무관하게 먼저 한다 — 갈 곳이 없는 알림도 확인하면
    // 배지에서 빠져야 한다.
    if (!notification.read) {
      try {
        await ref
            .read(trainerNotificationRepositoryProvider)
            .markRead(notification.id);
        ref
          ..invalidate(trainerNotificationsProvider)
          ..invalidate(trainerUnreadNotificationsProvider);
      } catch (_) {
        // 읽음 처리 실패로 이동까지 막지 않는다. 다음 조회에서 다시 미읽음으로
        // 보이는 편이, 누른 알림이 아무 반응도 없는 것보다 낫다.
      }
    }
    if (target != null && context.mounted) context.go(target);
  }

  Future<void> _readAll(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // messenger 와 같이 await 전에 잡아 둔다.
    final AppLocalizations l = AppLocalizations.of(context);
    try {
      await ref.read(trainerNotificationRepositoryProvider).markAllRead();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.notifReadAllFailed)));
      return;
    }
    ref
      ..invalidate(trainerNotificationsProvider)
      ..invalidate(trainerUnreadNotificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final notifications = ref.watch(trainerNotificationsProvider);
    final unread = ref.watch(trainerUnreadNotificationsProvider).valueOrNull;

    return PageScaffold(
      title: l.notifTitle,
      subtitle: unread == null
          ? null
          : (unread > 0 ? l.notifUnreadCount(unread) : l.notifAllRead),
      actions: <Widget>[
        if (unread != null && unread > 0)
          ActionButton(
            label: l.notifReadAll,
            icon: Icons.done_all,
            onPressed: () => _readAll(context, ref),
          ),
      ],
      child: notifications.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl),
          child: EmptyHint(
            message: serverDetailOr(
              l,
              error is AppError ? error.message : null,
              l.notifLoadFailed,
            ),
            icon: Icons.error_outline,
            action: ActionButton(
              key: const ValueKey<String>('notifications-retry'),
              label: l.actionRetry,
              onPressed: notifications.isLoading
                  ? null
                  : () => ref.invalidate(trainerNotificationsProvider),
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxl),
              child: EmptyHint(
                message: l.notifEmpty,
                icon: Icons.notifications_none,
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final TrainerNotification row in rows) ...<Widget>[
                _NotificationTile(
                  notification: row,
                  onTap: () => _open(context, ref, row),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final TrainerNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.kind) {
    TrainerNotificationKind.message => Icons.chat_bubble_outline,
    TrainerNotificationKind.consultation => Icons.mark_email_unread_outlined,
    TrainerNotificationKind.reservation => Icons.event_available_outlined,
    TrainerNotificationKind.other => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    final bool unread = !notification.read;
    return Material(
      // 미읽음은 배경으로 구분한다 — 점 하나보다 목록에서 먼저 눈에 들어온다.
      color: unread ? AppColors.accent : AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: InkWell(
        key: ValueKey<String>('notification-${notification.id}'),
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                _icon,
                size: 18,
                color: unread ? AppColors.primary : AppColors.mutedForeground,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                notification.timeAgo,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtleForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
