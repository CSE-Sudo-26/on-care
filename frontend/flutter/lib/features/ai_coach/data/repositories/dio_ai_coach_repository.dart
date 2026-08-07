import 'package:dio/dio.dart';

import 'package:oncare/features/ai_coach/domain/entities/ai_coach_state.dart';
import 'package:oncare/features/ai_coach/domain/entities/chat_message.dart';
import 'package:oncare/features/ai_coach/domain/repositories/ai_coach_repository.dart';

class DioAiCoachRepository implements AiCoachRepository {
  DioAiCoachRepository(this._dio);
  final Dio _dio;

  @override
  Future<AiCoachState> fetchState() async {
    final res = await _dio.get<Map<String, Object?>>('/ai-coach/feedback');
    return AiCoachState.fromJson(res.data!);
  }

  @override
  Future<List<ChatMessage>> fetchHistory() async {
    final res = await _dio.get<Map<String, Object?>>('/ai-coach/messages');
    final raw = (res.data?['messages'] as List<Object?>?) ?? const <Object?>[];
    return <ChatMessage>[
      for (final Object? m in raw)
        ChatMessage.fromStored(m! as Map<String, Object?>),
    ];
  }

  @override
  Future<ChatMessage> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final res = await _dio.post<Map<String, Object?>>(
      '/ai-coach/chat',
      data: <String, Object?>{
        'message': message,
        'history': <Map<String, Object?>>[for (final m in history) m.toJson()],
      },
    );
    return ChatMessage.coachFromReply(res.data!);
  }
}
