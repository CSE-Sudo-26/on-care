import 'package:dio/dio.dart';

import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';
import 'package:oncare/features/schedule/domain/repositories/schedule_repository.dart';

/// Network-side [ScheduleRepository]. dev/local builds get served by
/// `LocalApiInterceptor`; prod hits FastAPI's `GET /schedule/events`.
class DioScheduleRepository implements ScheduleRepository {
  DioScheduleRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<ScheduleEvent>> fetchByDate(String date) async {
    final res = await _dio.get<List<Object?>>(
      '/schedule/events',
      queryParameters: <String, Object?>{'date': date},
    );
    final rows = res.data ?? const <Object?>[];
    return rows
        .cast<Map<String, Object?>>()
        .map(ScheduleEvent.fromJson)
        .toList();
  }

  @override
  Future<List<ScheduleEvent>> fetchByMonth(String month) async {
    final res = await _dio.get<List<Object?>>(
      '/schedule/events',
      queryParameters: <String, Object?>{'month': month},
    );
    final rows = res.data ?? const <Object?>[];
    return rows
        .cast<Map<String, Object?>>()
        .map(ScheduleEvent.fromJson)
        .toList();
  }

  @override
  Future<ScheduleEvent> createEvent({
    required String date,
    required String title,
    String time = '',
    ScheduleCategory category = ScheduleCategory.other,
  }) async {
    final res = await _dio.post<Map<String, Object?>>(
      '/schedule/events',
      data: <String, Object?>{
        'date': date,
        'time': time,
        'title': title,
        'category': category.name,
      },
    );
    return ScheduleEvent.fromJson(res.data!);
  }

  @override
  Future<ScheduleEvent> updateEvent(
    String id, {
    String? date,
    String? time,
    String? title,
    ScheduleCategory? category,
  }) async {
    // 준 것만 담는다. 서버는 `exclude_unset` 로 받으므로, null 을 실어 보내면
    // "지워라" 로 읽힐 여지가 있다 — 아예 키를 넣지 않는다.
    final Map<String, Object?> body = <String, Object?>{
      'date': ?date,
      'time': ?time,
      'title': ?title,
      if (category != null) 'category': category.name,
    };
    final res = await _dio.put<Map<String, Object?>>(
      '/schedule/events/$id',
      data: body,
    );
    return ScheduleEvent.fromJson(res.data!);
  }

  @override
  Future<void> deleteEvent(String id) async {
    await _dio.delete<Object?>('/schedule/events/$id');
  }
}
