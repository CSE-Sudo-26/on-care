import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/notification/data/repositories/dio_notification_repository.dart';
import 'package:oncare/features/notification/domain/entities/alert_item.dart';
import 'package:oncare/features/notification/domain/repositories/notification_repository.dart';

class NotificationController extends StateNotifier<NotificationState> {
  NotificationController() : super(_seed());

  static NotificationState _seed() {
    return const NotificationState(
      items: <AlertItem>[
        AlertItem(
          id: 'a1',
          title: '나트륨 섭취 주의',
          body: '점심 짬뽕으로 오늘 나트륨이 3,421mg까지 올랐어요. 물을 충분히 드세요.',
          timeAgo: '10분 전',
          category: AlertCategory.reminder,
        ),
        AlertItem(
          id: 'a2',
          title: 'PT 수업 완료',
          body: '오늘 18:00 김트레이너와 12회차 PT를 마쳤어요!',
          timeAgo: '1시간 전',
          category: AlertCategory.achievement,
        ),
        AlertItem(
          id: 'a3',
          title: '트레이너 피드백 도착',
          body: '마무리로 어깨 회전근개 스트레칭을 꼭 해주세요.',
          timeAgo: '2시간 전',
          category: AlertCategory.reminder,
        ),
        AlertItem(
          id: 'a4',
          title: '서비스 점검 안내',
          body: '내일 02:00~03:00 점검 예정입니다.',
          timeAgo: '어제',
          category: AlertCategory.system,
          read: true,
        ),
      ],
    );
  }

  void markRead(String id) {
    state = NotificationState(
      items: state.items
          .map((AlertItem i) => i.id == id ? i.copyWith(read: true) : i)
          .toList(),
    );
  }

  void markAllRead() {
    state = NotificationState(
      items: state.items.map((AlertItem i) => i.copyWith(read: true)).toList(),
    );
  }

  /// Q9: in-app panel + simulated push. Inserts a new unread item
  /// at the top, as if a real FCM notification had landed.
  void simulatePush() {
    final id = 'sim-${DateTime.now().millisecondsSinceEpoch}';
    final injected = AlertItem(
      id: id,
      title: '시뮬레이션 알림',
      body: '지금 막 가상 푸시가 도착했어요.',
      timeAgo: '방금',
      category: AlertCategory.reminder,
    );
    state = NotificationState(items: <AlertItem>[injected, ...state.items]);
  }
}

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>(
      (ref) => NotificationController(),
      name: 'notifications',
    );

/// Network-side notification source. Production code talks to dio →
/// LocalApiInterceptor (drift) → FastAPI. Tests override this with a
/// `MockNotificationRepository`.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => DioNotificationRepository(ref.watch(dioProvider)),
  name: 'notificationRepository',
);

/// FutureProvider variant of the notifications list, sourced from the
/// repo. The legacy [notificationControllerProvider] still holds the
/// in-session mutations (markRead / simulatePush) — wholesale unifying
/// is intentionally deferred to keep the UI/test surface stable.
final notificationListProvider = FutureProvider.autoDispose<List<AlertItem>>(
  (ref) => ref.watch(notificationRepositoryProvider).fetchAll(),
  name: 'notificationList',
);
