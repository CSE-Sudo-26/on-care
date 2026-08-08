enum ChatRole { user, coach }

/// One message in the coach conversation. [pending] marks the transient
/// "typing…" placeholder shown while awaiting the coach's reply.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.sources = const <String>[],
    this.pending = false,
  });

  final ChatRole role;
  final String content;
  final List<String> sources; // 근거 공공 가이드라인 제목(코치 메시지에만)
  final bool pending;

  bool get isUser => role == ChatRole.user;

  /// Request shape sent as chat history to the server (snake_case-safe).
  Map<String, Object?> toJson() => <String, Object?>{
    'role': isUser ? 'user' : 'coach',
    'content': content,
  };

  /// Parse a stored turn from `GET /ai-coach/messages` → `{ role, content, sources }`.
  factory ChatMessage.fromStored(Map<String, Object?> json) => ChatMessage(
    role: (json['role'] as String?) == 'user' ? ChatRole.user : ChatRole.coach,
    content: ((json['content'] as String?) ?? '').trim(),
    sources: <String>[
      for (final Object? s
          in (json['sources'] as List<Object?>?) ?? const <Object?>[])
        s.toString(),
    ],
  );

  /// Parse a coach reply from `POST /ai-coach/chat` → `{ reply, sources }`.
  factory ChatMessage.coachFromReply(Map<String, Object?> json) => ChatMessage(
    role: ChatRole.coach,
    content: ((json['reply'] as String?) ?? '').trim(),
    sources: <String>[
      for (final Object? s in (json['sources'] as List<Object?>?) ?? const <Object?>[])
        s.toString(),
    ],
  );
}
