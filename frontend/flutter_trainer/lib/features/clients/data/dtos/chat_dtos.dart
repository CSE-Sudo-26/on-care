import 'package:oncare_trainer/shared/models/client_chat_message.dart';

/// Maps a `ChatMessageOut` JSON element (trainer chat endpoints) into the
/// domain [ClientChatMessage]. Kept separate from the Dio repository so the
/// DTO ↔ domain mapping is unit-testable.
///
/// Shape: `{ id, sender, body, time_label, created_at }`. From the trainer's
/// viewpoint `sender` is `trainer` | `client`.
ClientChatMessage chatMessageFromJson(Map<String, Object?> json) {
  final sender = switch (json['sender']) {
    'trainer' => ChatSender.trainer,
    'client' => ChatSender.client,
    _ => throw const FormatException('Invalid trainer chat sender.'),
  };
  return ClientChatMessage(
    id: _requiredString(json, 'id'),
    sender: sender,
    body: _requiredString(json, 'body'),
    timeLabel: _requiredString(json, 'time_label'),
    createdAt: _parseTime(json['created_at']),
  );
}

DateTime _parseTime(Object? v) {
  if (v is String) {
    final parsed = DateTime.tryParse(v);
    if (parsed != null) return parsed;
  }
  throw const FormatException('Invalid trainer chat created_at.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Invalid trainer chat $key.');
}
