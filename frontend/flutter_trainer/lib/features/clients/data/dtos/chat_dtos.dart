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
    attachment: _attachment(json['attachment']),
  );
}

ChatAttachment? _attachment(Object? value) {
  if (value == null) return null;
  if (value is! Map<String, Object?>) {
    throw const FormatException('Invalid trainer chat attachment.');
  }
  // 모르는 종류는 조용히 지나치지 않는다 — 화면이 그릴 방법을 모르는 첨부를
  // 빈 자리로 두면, 보낸 사람은 보냈다고 믿고 받은 사람은 아무것도 못 본다.
  final kind = ChatAttachmentKind.parse(value['type']);
  if (kind == null) {
    throw const FormatException('Invalid trainer chat attachment.');
  }
  final size = value['file_size'];
  if (size is! int || size < 0) {
    throw const FormatException('Invalid trainer chat attachment size.');
  }
  return ChatAttachment(
    kind: kind,
    fileName: _requiredString(value, 'file_name'),
    fileId: _requiredString(value, 'file_id'),
    fileSize: size,
    downloadPath: _requiredString(value, 'download_path'),
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
