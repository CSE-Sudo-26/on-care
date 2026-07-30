import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/notification/data/repositories/dio_notification_repository.dart';
import 'package:oncare/features/notification/data/repositories/mock_notification_repository.dart';
import 'package:oncare/features/notification/domain/entities/alert_item.dart';
import 'package:oncare/features/notification/domain/repositories/notification_repository.dart';

class NotificationController extends StateNotifier<NotificationState> {
  /// [seed] 가 주어지면(데모/목 모드) 즉시 노출하고 네트워크 로드를 건너뛴다 —
  /// 데모 둘러보기 화면이 기존과 동일하게 보이도록 유지한다. 실모드는 seed=null
  /// 로 생성해 백엔드(`/notifications`)에서 최신 알림을 불러온다.
  NotificationController(this._repo, {List<AlertItem>? seed})
    : super(NotificationState(items: seed ?? const <AlertItem>[])) {
    if (seed == null) {
      _load();
    }
  }

  final NotificationRepository _repo;

  Future<void> _load() async {
    try {
      final items = await _repo.fetchAll();
      if (mounted) {
        state = NotificationState(items: items);
      }
    } catch (_) {
      // 알림 로드 실패는 화면 접근을 막지 않는다(빈 목록 유지).
    }
  }

  /// 실모드에서 서버 알림을 다시 불러온다.
  Future<void> refresh() => _load();

  Future<void> markRead(String id) async {
    state = NotificationState(
      items: state.items
          .map((AlertItem i) => i.id == id ? i.copyWith(read: true) : i)
          .toList(),
    );
    try {
      await _repo.markRead(id);
    } catch (_) {
      // 낙관적 업데이트 유지 — 영속화 실패는 다음 로드에서 정정된다.
    }
  }

  Future<void> markAllRead() async {
    state = NotificationState(
      items: state.items.map((AlertItem i) => i.copyWith(read: true)).toList(),
    );
    try {
      await _repo.markAllRead();
    } catch (_) {
      // 낙관적 업데이트 유지.
    }
  }

  /// Q9: in-app panel + simulated push. Inserts a new unread item
  /// at the top, as if a real FCM notification had landed. 실모드에서도
  /// 로컬로만 주입한다(서버 미전송, 개발/데모용).
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

/// 데모/로컬 모드는 목, 실모드는 백엔드(`/notifications`) 리포.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return const MockNotificationRepository();
  }
  return DioNotificationRepository(ref.watch(dioProvider));
}, name: 'notificationRepository');

/// 알림 목록 + 세션 변이(읽음/전체읽음/가상푸시)를 담는 컨트롤러.
/// 목 모드는 [demoAlerts] 를 즉시 시드로 사용하고, 실모드는 백엔드에서 로드한다.
final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
      final useMock = ref.watch(appConfigProvider).useMockApi;
      final repo = ref.watch(notificationRepositoryProvider);
      return NotificationController(repo, seed: useMock ? demoAlerts : null);
    }, name: 'notifications');

/// 안읽음 배지 등 가벼운 소비처용 목록(리포 직접). 컨트롤러와 별개로 유지한다.
final notificationListProvider = FutureProvider.autoDispose<List<AlertItem>>(
  (ref) => ref.watch(notificationRepositoryProvider).fetchAll(),
  name: 'notificationList',
);
