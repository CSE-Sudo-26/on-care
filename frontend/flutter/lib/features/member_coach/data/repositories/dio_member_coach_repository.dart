import 'package:dio/dio.dart';

import 'package:oncare/core/errors/app_error.dart';
import 'package:oncare/features/member_coach/data/dtos/member_coach_dtos.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/repositories/member_coach_repository.dart';

/// Reads the member's coach + received routines + chat from the FastAPI
/// backend. The chat thread is the same one the trainer app writes to, so
/// messages and routines flow both ways.
class DioMemberCoachRepository implements MemberCoachRepository {
  DioMemberCoachRepository(this._dio);

  final Dio _dio;

  @override
  Future<MemberCoach?> fetchCoach() async {
    try {
      final res = await _dio.get<Map<String, Object?>>('/me/coach');
      final data = res.data;
      return data == null ? null : memberCoachFromJson(data);
    } on DioException catch (e) {
      // No assigned coach yet → 404 is an expected empty state, not an error.
      if (e.response?.statusCode == 404) return null;
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<List<CoachRoutine>> fetchRoutines() =>
      _getList('/me/coach/routines', coachRoutineFromJson);

  @override
  Future<List<CoachMessage>> fetchChat() =>
      _getList('/me/coach/chat', coachMessageFromJson);

  @override
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await _dio.post<Map<String, Object?>>(
        '/me/coach/chat',
        data: <String, Object?>{'text': trimmed},
      );
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<void> markRead() async {
    try {
      await _dio.post<Map<String, Object?>>('/me/coach/chat/read');
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<int> unreadCount() async {
    try {
      final res = await _dio.get<Map<String, Object?>>('/me/coach/chat/unread');
      final v = res.data?['unread'];
      return v is num ? v.toInt() : 0;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return 0;
      throw AppError.fromDio(e);
    }
  }

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, Object?>) fromJson,
  ) async {
    try {
      final res = await _dio.get<List<dynamic>>(path);
      final data = res.data ?? const <dynamic>[];
      return data
          .whereType<Map<String, Object?>>()
          .map(fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return <T>[];
      throw AppError.fromDio(e);
    }
  }
}
