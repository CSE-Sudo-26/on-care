import 'package:dio/dio.dart';

import 'package:oncare/features/notification/domain/entities/alert_item.dart';
import 'package:oncare/features/notification/domain/repositories/notification_repository.dart';

/// Network-side [NotificationRepository]. Calls go through `Dio`; the
/// dev/local build short-circuits them in `LocalApiInterceptor`.
class DioNotificationRepository implements NotificationRepository {
  DioNotificationRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<AlertItem>> fetchAll() async {
    final res = await _dio.get<List<Object?>>('/notifications');
    final rows = res.data ?? const <Object?>[];
    return rows.cast<Map<String, Object?>>().map(_fromJson).toList();
  }

  @override
  Future<void> markRead(String id) async {
    await _dio.post<Object?>('/notifications/$id/read');
  }

  @override
  Future<void> markAllRead() async {
    await _dio.post<Object?>('/notifications/read-all');
  }

  @override
  Future<int> unreadCount() async {
    final res = await _dio.get<Map<String, Object?>>(
      '/notifications/unread-count',
    );
    final Object? raw = res.data?['count'];
    // 잘못된 응답을 0 으로 삼키면 **읽지 않은 알림이 있는데도 배지가 꺼진다.**
    // 던져서 폴링이 마지막 좋은 값을 유지하게 한다(연결 실패와 같은 취급).
    if (raw is! num || raw < 0) {
      throw const FormatException('unread-count 응답이 올바르지 않습니다');
    }
    return raw.toInt();
  }

  static AlertItem _fromJson(Map<String, Object?> json) {
    return AlertItem(
      id: json['id']! as String,
      title: json['title']! as String,
      body: json['body']! as String,
      timeAgo: (json['time_ago'] as String?) ?? '',
      category: _categoryFrom(json['category']! as String),
      read: (json['read'] as bool?) ?? false,
      action: _actionFrom(json['action']),
    );
  }

  /// 서버가 준 행동 유도. 없으면 null — 읽음 처리만 하는 알림이다.
  static AlertAction? _actionFrom(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final label = (raw['label'] as String?) ?? '';
    final target = raw['target'] as String?;
    if (label.isEmpty || target == null) return null;
    return AlertAction(label: label, target: _targetFrom(target));
  }

  /// 앱이 모르는 target 은 [AlertTarget.unknown] 이다. 목록에서 빼지 않고 이동만
  /// 하지 않는다 — 안 보이는 알림보다 갈 곳 없는 알림이 낫다(트레이너 웹과 같은 규칙).
  static AlertTarget _targetFrom(String s) => switch (s) {
    'dashboard' => AlertTarget.dashboard,
    'schedule' => AlertTarget.schedule,
    'coach_chat' => AlertTarget.coachChat,
    'exercise' => AlertTarget.exercise,
    'diet' => AlertTarget.diet,
    _ => AlertTarget.unknown,
  };

  static AlertCategory _categoryFrom(String s) => switch (s) {
    'reminder' => AlertCategory.reminder,
    'health_check' => AlertCategory.healthCheck,
    'achievement' => AlertCategory.achievement,
    _ => AlertCategory.system,
  };
}
