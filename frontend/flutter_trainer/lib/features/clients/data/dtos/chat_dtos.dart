import 'package:oncare_trainer/shared/models/client_chat_message.dart';

/// Maps a `ChatMessageOut` JSON element (trainer chat endpoints) into the
/// domain [ClientChatMessage]. Kept separate from the Dio repository so the
/// DTO ↔ domain mapping is unit-testable.
///
/// Shape: `{ id, sender, body, time_label, created_at }`. From the trainer's
/// viewpoint `sender` is `trainer` | `client`; anything that isn't
/// `trainer` maps to [ChatSender.client].
ClientChatMessage chatMessageFromJson(Map<String, Object?> json) {
  return ClientChatMessage(
    id: json['id'] is String ? json['id']! as String : '',
    sender: json['sender'] == 'trainer' ? ChatSender.trainer : ChatSender.client,
    body: json['body'] is String ? json['body']! as String : '',
    timeLabel: json['time_label'] is String ? json['time_label']! as String : '',
    createdAt: _parseTime(json['created_at']),
  );
}

/// Parses the ISO `created_at` cursor; falls back to epoch so a malformed
/// value sorts oldest rather than throwing.
DateTime _parseTime(Object? v) {
  if (v is String) {
    final parsed = DateTime.tryParse(v);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
