/// Where a memo came from.
///
/// Both kinds live in one list on the client detail screen — the trainer
/// cares about "what did I record about this member", not about which screen
/// created the row.
enum TrainerMemoSource {
  /// Written by the trainer on the client detail screen.
  trainer,

  /// Saved from a signal detected in the member's chat messages.
  chatInsight;

  /// The backend wire value (`source` on `/trainer/clients/{id}/memos`).
  String get wire =>
      this == TrainerMemoSource.chatInsight ? 'chat_insight' : 'trainer';

  static TrainerMemoSource fromWire(String? value) => value == 'chat_insight'
      ? TrainerMemoSource.chatInsight
      : TrainerMemoSource.trainer;
}

/// A memo a trainer keeps about one member. Never shown to the member.
class TrainerMemo {
  const TrainerMemo({
    required this.id,
    required this.body,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.insightId,
    this.insightKind = '',
  });

  final String id;
  final String body;
  final TrainerMemoSource source;

  /// Identifier of the chat insight this memo was saved from. Memos written
  /// by hand have none — saving the same insight twice must not add a second
  /// memo, and this is the key that enforces it (server-side and locally).
  final String? insightId;

  /// `discomfort` / `negativeFeedback` for chat-insight memos, empty
  /// otherwise. Kept so the demo's local memos keep their label.
  final String insightKind;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory TrainerMemo.fromJson(Map<String, Object?> json) => TrainerMemo(
    id: json['id']! as String,
    body: json['body'] as String? ?? '',
    source: TrainerMemoSource.fromWire(json['source'] as String?),
    insightId: json['insight_id'] as String?,
    insightKind: json['insight_kind'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at']! as String),
    updatedAt: DateTime.parse(
      json['updated_at'] as String? ?? json['created_at']! as String,
    ),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'body': body,
    'source': source.wire,
    'insight_id': insightId,
    'insight_kind': insightKind,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  TrainerMemo copyWith({String? body, DateTime? updatedAt}) => TrainerMemo(
    id: id,
    body: body ?? this.body,
    source: source,
    insightId: insightId,
    insightKind: insightKind,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
