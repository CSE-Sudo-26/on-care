import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/core/utils/active_polling_stream.dart';
import 'package:oncare/features/notification/data/repositories/dio_notification_repository.dart';
import 'package:oncare/features/notification/data/repositories/mock_notification_repository.dart';
import 'package:oncare/features/notification/domain/entities/alert_item.dart';
import 'package:oncare/features/notification/domain/repositories/notification_repository.dart';

class NotificationController extends StateNotifier<NotificationState> {
  /// [seed] 가 주어지면(데모/목 모드) 즉시 노출하고 네트워크 로드를 건너뛴다 —
  /// 데모 둘러보기 화면이 기존과 동일하게 보이도록 유지한다. 실모드는 seed=null
  /// 로 생성해 백엔드(`/notifications`)에서 최신 알림을 불러온다.
  NotificationController(this._repo, {List<AlertItem>? seed, this.onChanged})
    : _allowSimulatePush = seed != null,
      super(NotificationState(items: seed ?? const <AlertItem>[])) {
    if (seed == null) {
      _load();
    }
  }

  final NotificationRepository _repo;

  /// 목록이 바뀌면 호출된다. 헤더 배지가 목록과 같은 서버 상태를 보도록,
  /// 읽음 처리 직후 다음 폴링을 기다리지 않고 즉시 다시 세게 한다.
  final void Function()? onChanged;

  /// 가상 푸시 주입은 목/데모 모드에서만 허용한다(seed 가 주어진 경우).
  /// 실모드는 서버가 진실원본이라, 로컬 팬텀을 넣으면 다음 [refresh] 에서
  /// 사라져 상태가 어긋난다.
  final bool _allowSimulatePush;

  /// 진행 중인 조회. 화면 진입과 포그라운드 복귀가 겹쳐도 요청이 두 번 나가지 않게
  /// 같은 future 를 돌려준다 — 중복 조회는 목록이 두 번 흔들리는 것으로 보인다.
  Future<void>? _inFlight;

  Future<void> _load() {
    return _inFlight ??= _loadOnce().whenComplete(() => _inFlight = null);
  }

  Future<void> _loadOnce() async {
    if (mounted) state = state.copyWith(loading: true);
    try {
      final items = await _repo.fetchAll();
      if (!mounted) return;
      // 서버가 진실원본이다. 목록을 통째로 갈아 끼우므로 중복이 남지 않는다.
      state = NotificationState(items: items);
      onChanged?.call();
    } catch (_) {
      // 실패해도 **이미 받아 둔 목록은 지우지 않는다.** 화면이 재시도를 제안한다.
      if (!mounted) return;
      state = state.copyWith(loading: false, failedToLoad: true);
    }
  }

  /// 서버 알림을 다시 불러온다.
  ///
  /// 화면 진입·복귀·당겨서 새로고침이 모두 이 경로를 쓴다. 목 모드에서는 시드가
  /// 진실원본이라 아무 일도 하지 않는다 — 데모 화면이 네트워크를 타면 안 된다.
  Future<void> refresh() async {
    if (_allowSimulatePush) return;
    await _load();
  }

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
    } finally {
      // **쓰기가 끝난 뒤에** 다시 센다. 먼저 부르면 서버가 아직 옛 수를 답해,
      // 배지가 다음 폴링까지 틀린 채로 남는다(리뷰).
      onChanged?.call();
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
    } finally {
      onChanged?.call();
    }
  }

  /// Q9: in-app panel + simulated push. Inserts a new unread item
  /// at the top, as if a real FCM notification had landed. 목/데모 모드
  /// 전용(개발용) — 실모드에서는 서버에 없는 팬텀을 만들지 않도록 무시한다.
  /// 문구는 부른 쪽이 넘긴다 — 컨트롤러에는 로케일이 없다(#847).
  void simulatePush({
    required String title,
    required String body,
    required String timeAgo,
  }) {
    if (!_allowSimulatePush) return;
    final id = 'sim-${DateTime.now().millisecondsSinceEpoch}';
    final injected = AlertItem(
      id: id,
      title: title,
      body: body,
      timeAgo: timeAgo,
      category: AlertCategory.reminder,
    );
    state = NotificationState(items: <AlertItem>[injected, ...state.items]);
  }
}

/// 데모/로컬 모드는 목, 실모드는 백엔드(`/notifications`) 리포.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return MockNotificationRepository();
  }
  return DioNotificationRepository(ref.watch(dioProvider));
}, name: 'notificationRepository');

/// 알림 목록 + 세션 변이(읽음/전체읽음/가상푸시)를 담는 컨트롤러.
/// 목 모드는 [demoAlerts] 를 즉시 시드로 사용하고, 실모드는 백엔드에서 로드한다.
final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
      final useMock = ref.watch(appConfigProvider).useMockApi;
      final repo = ref.watch(notificationRepositoryProvider);
      return NotificationController(
        repo,
        seed: useMock ? demoAlerts : null,
        onChanged: () => ref.invalidate(notificationUnreadProvider),
      );
    }, name: 'notifications');

/// 헤더 벨 배지가 읽는 **서버 기준** 미읽음 수.
///
/// 목록 전체를 받아 세지 않는 이유: 배지는 모든 탭에 떠 있어서 알림을 열지 않아도
/// 최신이어야 하는데, 그때마다 전체 목록을 받는 것은 과하다.
///
/// 폴링은 앱이 앞에 있을 때만 돌고, 일시적 실패에는 마지막 값을 유지한다
/// (`activePollingStream`). 트레이너가 무언가 하면 회원 앱을 재시작하지 않아도
/// 배지가 따라온다.
final notificationUnreadProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  if (ref.watch(appConfigProvider).useMockApi) {
    // 데모에는 따라갈 서버가 없다. 시드 값을 한 번만 내보내고 폴링하지 않는다 —
    // 없는 서버를 15초마다 찌르는 타이머가 화면 수명 내내 남는다.
    return Stream<int>.fromFuture(repo.unreadCount());
  }
  return activePollingStream<int>(
    load: repo.unreadCount,
    interval: const Duration(seconds: 15),
  );
}, name: 'notificationUnread');

/// 안읽음 배지 등 가벼운 소비처용 목록(리포 직접). 컨트롤러와 별개로 유지한다.
final notificationListProvider = FutureProvider.autoDispose<List<AlertItem>>(
  (ref) => ref.watch(notificationRepositoryProvider).fetchAll(),
  name: 'notificationList',
);
