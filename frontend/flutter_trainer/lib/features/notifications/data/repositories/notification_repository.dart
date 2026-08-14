import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/notifications/domain/entities/trainer_notification.dart';

/// 트레이너 알림함을 읽고 읽음 처리한다. (#503)
///
/// 두 구현이 [trainerNotificationRepositoryProvider] 뒤에 있고
/// [AppConfig.useMockApi] 로 갈린다.
///
///  * [DemoNotificationRepository] — 데모. 알림을 만드는 회원 백엔드가 없어
///    항상 비어 있다. 상담 인박스(#467)와 같은 이유로, 늘 "없어요"만 말하는
///    진입점을 데모에 남기지 않는다.
///  * [DioNotificationRepository] — 실 백엔드(`/trainer/notifications`).
///
/// 회원용 `/notifications` 를 쓰지 않는 이유: 그 경로는 트레이너 계정을 403 으로
/// 막는 **회원 전용**이다(역할 분리). 저장되는 행은 같은 테이블이다.
abstract interface class TrainerNotificationRepository {
  /// 이 빌드에서 알림함을 쓸 수 있는가. 데모에서는 진입점을 감춘다.
  bool get supportsInbox;

  /// 받은 알림(최신순).
  Future<List<TrainerNotification>> fetch();

  /// 사이드바 배지가 읽는 미읽음 수.
  Future<int> unreadCount();

  /// 한 건 읽음 처리.
  Future<void> markRead(String id);

  /// 전체 읽음 처리. 읽음으로 바뀐 건수를 돌려준다.
  Future<int> markAllRead();
}

/// 데모: 알림함이 없다. 읽기는 빈 결과로 성공해, 딥링크로 들어와도 오류가
/// 아니라 빈 화면이 된다.
class DemoNotificationRepository implements TrainerNotificationRepository {
  const DemoNotificationRepository();

  @override
  bool get supportsInbox => false;

  @override
  Future<List<TrainerNotification>> fetch() async =>
      const <TrainerNotification>[];

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<int> markAllRead() async => 0;
}

/// 실 백엔드 구현.
class DioNotificationRepository implements TrainerNotificationRepository {
  const DioNotificationRepository(this._dio);

  final Dio _dio;

  @override
  bool get supportsInbox => true;

  @override
  Future<List<TrainerNotification>> fetch() async {
    try {
      final res = await _dio.get<List<dynamic>>('/trainer/notifications');
      return (res.data ?? const <dynamic>[])
          .whereType<Map<String, Object?>>()
          .map(TrainerNotification.fromJson)
          .toList();
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<int> unreadCount() async {
    try {
      final res = await _dio.get<Map<String, Object?>>(
        '/trainer/notifications/unread-count',
      );
      final value = res.data?['unread'];
      return value is num ? value.toInt() : 0;
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _dio.post<void>('/trainer/notifications/$id/read');
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<int> markAllRead() async {
    try {
      final res = await _dio.post<Map<String, Object?>>(
        '/trainer/notifications/read-all',
      );
      final value = res.data?['marked_read'];
      return value is num ? value.toInt() : 0;
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }
}

/// 현재 모드에 맞는 저장소.
final trainerNotificationRepositoryProvider =
    Provider<TrainerNotificationRepository>((ref) {
      if (ref.watch(appConfigProvider).useMockApi) {
        return const DemoNotificationRepository();
      }
      return DioNotificationRepository(ref.watch(dioProvider));
    }, name: 'trainerNotificationRepository');

/// 알림함에 들어갈 수 있는 빌드인가 — 사이드바 진입점 노출 조건.
final notificationInboxEnabledProvider = Provider<bool>(
  (ref) => ref.watch(trainerNotificationRepositoryProvider).supportsInbox,
  name: 'notificationInboxEnabled',
);

/// 받은 알림 목록.
final trainerNotificationsProvider = FutureProvider<List<TrainerNotification>>((
  ref,
) {
  return ref.watch(trainerNotificationRepositoryProvider).fetch();
}, name: 'trainerNotifications');

/// 미읽음 수 — 사이드바 배지.
final trainerUnreadNotificationsProvider = FutureProvider<int>((ref) {
  return ref.watch(trainerNotificationRepositoryProvider).unreadCount();
}, name: 'trainerUnreadNotifications');
