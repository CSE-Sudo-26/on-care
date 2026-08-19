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
  final ChatAttachment? attachment;

  /// Whether this message was sent by the trainer.
  bool get fromTrainer => sender == ChatSender.trainer;
}

/// 첨부의 종류. 화면이 그릴 방법을 이 값으로 정한다.
///
/// 주간 리포트 PDF(#778)로 시작해 코칭 사진(#921)이 더해졌다. **둘뿐이다** —
/// 임의 파일 공유는 이 대화의 목적이 아니고, 그릴 수 없는 형식이 오면 화면에는
/// 아이콘 하나만 남는다.
enum ChatAttachmentKind {
  /// 내려받는다.
  pdf,

  /// 대화 안에서 그린다.
  image;

  static ChatAttachmentKind? parse(Object? value) => switch (value) {
    'pdf' => ChatAttachmentKind.pdf,
    'image' => ChatAttachmentKind.image,
    _ => null,
  };
}

/// 채팅 메시지에 딸린 파일.
class ChatAttachment {
  const ChatAttachment({
    required this.kind,
    required this.fileName,
    required this.fileId,
    required this.fileSize,
    required this.downloadPath,
  });

  final ChatAttachmentKind kind;
  final String fileName;
  final String fileId;
  final int fileSize;
  final String downloadPath;

  bool get isImage => kind == ChatAttachmentKind.image;
}
