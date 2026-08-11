import 'package:dio/dio.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/active_polling_stream.dart';
import 'package:oncare_trainer/core/utils/request_id.dart';
import 'package:oncare_trainer/features/clients/data/dtos/chat_dtos.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';

/// Trainer↔member chat against the FastAPI backend. The thread is the same
/// row set the member app reads via `/me/coach/chat`, so a trainer message
/// is received in the member app and vice versa.
///
/// The thread is polled only while its screen is subscribed and the app is in
/// the foreground. Selected when `USE_MOCK_API=false` (see
/// [chatRepositoryProvider]).
class DioChatRepository implements ChatRepository {
  DioChatRepository(
    this._dio, {
    this.pollInterval = const Duration(seconds: 3),
    this.requestIdFactory = newClientRequestId,
  });

  final Dio _dio;
  final Duration pollInterval;
  final String Function() requestIdFactory;
  final Map<({String clientId, String text}), String> _pendingRequestIds =
      <({String clientId, String text}), String>{};

  @override
  Stream<List<ClientChatMessage>> watchThread(String clientId) =>
      activePollingStream<List<ClientChatMessage>>(
        load: () => _fetchThread(clientId),
        interval: pollInterval,
      );

  Future<List<ClientChatMessage>> _fetchThread(String clientId) async {
    final encodedId = Uri.encodeComponent(clientId);
    try {
      final res = await _dio.get<List<dynamic>>(
        '/trainer/clients/$encodedId/chat',
      );
      final data = res.data ?? const <dynamic>[];
      return data
          .map((item) {
            if (item is! Map<String, Object?>) {
              throw const FormatException(
                'Expected an object in the trainer chat response.',
              );
            }
            return chatMessageFromJson(item);
          })
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
    final encodedId = Uri.encodeComponent(clientId);
    final payload = (clientId: clientId, text: trimmed);
    final requestId = _pendingRequestIds.putIfAbsent(payload, requestIdFactory);
    try {
      await _dio.post<Map<String, Object?>>(
        '/trainer/clients/$encodedId/chat',
        data: <String, Object?>{
          'text': trimmed,
          'client_request_id': requestId,
        },
      );
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
    if (_pendingRequestIds[payload] == requestId) {
      _pendingRequestIds.remove(payload);
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
          // Fail loud on a non-numeric count instead of silently dropping
          // it, matching every other response parser in this class —
          // a malformed entry here previously vanished from the roster
          // badges with no signal (review).
          entry.key: switch (entry.value) {
            final num n => n.toInt(),
            _ => throw FormatException(
              'Expected a numeric unread count for "${entry.key}".',
            ),
          },
      };
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<void> markThreadRead(String clientId) async {
    final encodedId = Uri.encodeComponent(clientId);
    try {
      await _dio.post<Map<String, Object?>>(
        '/trainer/clients/$encodedId/chat/read',
      );
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }
}
