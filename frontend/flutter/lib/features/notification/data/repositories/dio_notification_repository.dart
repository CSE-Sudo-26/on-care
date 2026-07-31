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

  static AlertItem _fromJson(Map<String, Object?> json) {
    return AlertItem(
      id: json['id']! as String,
      title: json['title']! as String,
      body: json['body']! as String,
      timeAgo: (json['time_ago'] as String?) ?? '',
      category: _categoryFrom(json['category']! as String),
      read: (json['read'] as bool?) ?? false,
    );
  }

  static AlertCategory _categoryFrom(String s) => switch (s) {
    'reminder' => AlertCategory.reminder,
    'health_check' => AlertCategory.healthCheck,
    'achievement' => AlertCategory.achievement,
    _ => AlertCategory.system,
  };
}
