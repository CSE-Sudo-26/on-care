import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oncare_trainer/core/storage/prefs_provider.dart';
import 'package:oncare_trainer/features/messages/domain/chat_context_insight.dart';

/// A trainer memo created from a detected chat signal.
class ChatInsightMemo {
  const ChatInsightMemo({
    required this.insightId,
    required this.message,
    required this.kind,
    required this.createdAt,
  });

  final String insightId;
  final String message;
  final ChatInsightKind kind;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'insight_id': insightId,
    'message': message,
    'kind': kind.name,
    'created_at': createdAt.toIso8601String(),
  };

  factory ChatInsightMemo.fromJson(Map<String, Object?> json) {
    return ChatInsightMemo(
      insightId: json['insight_id']! as String,
      message: json['message']! as String,
      kind: ChatInsightKind.values.byName(json['kind']! as String),
      createdAt: DateTime.parse(json['created_at']! as String),
    );
  }
}

/// Persists AI-created trainer memos locally per client. This works in both
/// demo and API modes while the backend's general trainer-memo endpoint is
/// still pending.
class ChatInsightMemoRepository {
  const ChatInsightMemoRepository(this._prefs);

  final SharedPreferences _prefs;

  List<ChatInsightMemo> read(String clientId) {
    final raw = _prefs.getString(_key(clientId));
    if (raw == null) return const <ChatInsightMemo>[];
    try {
      return (jsonDecode(raw) as List<Object?>)
          .map(
            (item) => ChatInsightMemo.fromJson(
              (item! as Map<Object?, Object?>).cast<String, Object?>(),
            ),
          )
          .toList(growable: false);
    } on Object {
      return const <ChatInsightMemo>[];
    }
  }

  Future<void> add(String clientId, ChatContextInsight insight) async {
    final memos = read(clientId);
    if (memos.any((memo) => memo.insightId == insight.id)) return;
    final updated = <ChatInsightMemo>[
      ...memos,
      ChatInsightMemo(
        insightId: insight.id,
        message: insight.evidence,
        kind: insight.kind,
        createdAt: DateTime.now(),
      ),
    ];
    await _prefs.setString(
      _key(clientId),
      jsonEncode(updated.map((memo) => memo.toJson()).toList()),
    );
  }

  static String _key(String clientId) => 'chat_insight_memos:$clientId';
}

final chatInsightMemoRepositoryProvider = Provider<ChatInsightMemoRepository>((
  ref,
) {
  return ChatInsightMemoRepository(ref.watch(sharedPreferencesProvider));
});

final chatInsightMemosProvider = FutureProvider.autoDispose
    .family<List<ChatInsightMemo>, String>((ref, clientId) async {
      return ref.watch(chatInsightMemoRepositoryProvider).read(clientId);
    });
