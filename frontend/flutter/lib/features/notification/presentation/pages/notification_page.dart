import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/atoms/app_badge.dart';
import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/theme/app_theme.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/notification/domain/entities/alert_item.dart';
import 'package:oncare/features/notification/presentation/alert_navigation.dart';
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

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

/// 화면이 살아 있는 동안 서버 상태를 따라간다.
///
/// 진입할 때 한 번, 그리고 앱이 앞으로 돌아올 때마다 다시 조회한다. 트레이너가
/// 무언가 해도 회원 앱을 재시작해야 보이던 문제를 없앤다 — 알림함을 열어 둔 채
/// 잠깐 다른 앱을 다녀오는 것이 실제로 자주 하는 동작이다.
class _NotificationPageState extends ConsumerState<NotificationPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 첫 프레임 뒤에 부른다 — build 중에 provider 를 건드리지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() {
    if (!mounted) return Future<void>.value();
    return ref.read(notificationControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final state = ref.watch(notificationControllerProvider);
    final notifier = ref.read(notificationControllerProvider.notifier);
    final bool showRetry = state.failedToLoad;

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
      // 목록이 비어 있어도 당겨서 새로고침할 수 있어야 한다 — 빈 화면이야말로
      // 다시 받아 보고 싶은 순간이다. 그래서 본문은 항상 스크롤 가능하다.
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount:
              (showRetry ? 1 : 0) +
              (state.items.isEmpty ? 1 : state.items.length),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (BuildContext ctx, int i) {
            // 조회가 실패해도 **받아 둔 목록은 그대로 둔다.** 맨 위에 사정과 재시도만
            // 얹는다 — 목록이 사라지면 읽지 않은 알림이 있었는지조차 알 수 없다.
            if (showRetry && i == 0) {
              return _RetryBanner(onRetry: _refresh);
            }
            if (state.items.isEmpty) {
              return const SizedBox(
                height: 320,
                child: EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: '알림이 없습니다',
                ),
              );
            }
            final AlertItem item = state.items[i - (showRetry ? 1 : 0)];
            return _AlertTile(
              item: item,
              // 읽음 처리를 기다리지 않고 이동한다 — 서버 왕복 동안 화면이 멈춰
              // 있으면 누른 것이 먹지 않은 것처럼 보인다.
              onTap: () {
                notifier.markRead(item.id);
                openAlertTarget(context, ref, item);
              },
            );
          },
        ),
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


/// 조회 실패를 알리고 다시 시도하게 한다.
class _RetryBanner extends StatelessWidget {
  const _RetryBanner({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('notificationRetryBanner'),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, size: 20),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('최신 알림을 불러오지 못했어요')),
          TextButton(
            onPressed: () => onRetry(),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
