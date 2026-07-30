import 'package:dio/dio.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/clients/data/dtos/chat_dtos.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';

/// Trainer↔member chat against the FastAPI backend. The thread is the same
/// row set the member app reads via `/me/coach/chat`, so a trainer message
/// is received in the member app and vice versa.
///
/// Reads return single-emit streams (fetch → value); [ChatView] invalidates
/// the thread/unread providers after a send or read so the next fetch shows
/// the change. Selected when `USE_MOCK_API=false` (see
/// [chatRepositoryProvider]).
class DioChatRepository implements ChatRepository {
  DioChatRepository(this._dio);

  final Dio _dio;

  @override
  Stream<List<ClientChatMessage>> watchThread(String clientId) =>
      Stream<List<ClientChatMessage>>.fromFuture(_fetchThread(clientId));

  Future<List<ClientChatMessage>> _fetchThread(String clientId) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/trainer/clients/$clientId/chat',
      );
      final data = res.data ?? const <dynamic>[];
      return data
          .whereType<Map<String, Object?>>()
          .map(chatMessageFromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await _dio.post<Map<String, Object?>>(
        '/trainer/clients/$clientId/chat',
        data: <String, Object?>{'text': trimmed},
      );
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Stream<Map<String, int>> watchUnreadCounts() =>
      Stream<Map<String, int>>.fromFuture(_fetchUnread());

  Future<Map<String, int>> _fetchUnread() async {
    try {
      final res = await _dio.get<Map<String, Object?>>('/trainer/chat/unread');
      final data = res.data ?? const <String, Object?>{};
      return <String, int>{
        for (final entry in data.entries)
          if (entry.value is num) entry.key: (entry.value! as num).toInt(),
      };
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<void> markThreadRead(String clientId) async {
    try {
      await _dio.post<Map<String, Object?>>(
        '/trainer/clients/$clientId/chat/read',
      );
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }
}
