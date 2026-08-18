/// Who sent a chat message.
enum ChatSender {
  /// The trainer (right-aligned bubble).
  trainer,

  /// The client (left-aligned bubble).
  client,
}

/// A single chat message in a client thread. Decoded from the drift
/// `ClientChatMessages` row.
class ClientChatMessage {
  /// Creates a chat message.
  const ClientChatMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.timeLabel,
    required this.createdAt,
    this.attachment,
  });

  /// Row id (`seed-chat-…` for seeds, `chat-…` for runtime replies).
  final String id;

  /// Who sent it.
  final ChatSender sender;

  /// Message text.
  final String body;

  /// Display time label (e.g. 18:10).
  final String timeLabel;

  /// Ordering key.
  final DateTime createdAt;
  final ChatPdfAttachment? attachment;

  /// Whether this message was sent by the trainer.
  bool get fromTrainer => sender == ChatSender.trainer;
}

class ChatPdfAttachment {
  const ChatPdfAttachment({
    required this.fileName,
    required this.fileId,
    required this.fileSize,
    required this.downloadPath,
  });

  final String fileName;
  final String fileId;
  final int fileSize;
  final String downloadPath;
}
