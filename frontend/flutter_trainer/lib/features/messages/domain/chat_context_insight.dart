import 'package:oncare_trainer/shared/models/client_chat_message.dart';

/// A coaching signal found in a message sent by a client.
enum ChatInsightKind { discomfort, negativeFeedback }

/// The small, explainable result rendered under the source message.
class ChatContextInsight {
  const ChatContextInsight({
    required this.id,
    required this.messageId,
    required this.kind,
    required this.evidence,
    this.bodyPart,
  });

  final String id;
  final String messageId;
  final ChatInsightKind kind;
  final String evidence;
  final String? bodyPart;
}

/// Lightweight fallback used by the web demo and while the insight API is
/// unavailable. Keeping it deterministic makes every highlighted signal
/// traceable to the exact member message instead of presenting a black-box
/// diagnosis.
class ChatContextInsightDetector {
  const ChatContextInsightDetector();

  ChatContextInsight? detect(ClientChatMessage message) {
    if (message.fromTrainer) return null;
    final text = message.body.toLowerCase();

    final part = _bodyParts.entries
        .where((entry) => text.contains(entry.key))
        .map((entry) => entry.value)
        .firstOrNull;
    if (_discomfortTerms.any(text.contains)) {
      return ChatContextInsight(
        id: '${message.id}:discomfort',
        messageId: message.id,
        kind: ChatInsightKind.discomfort,
        evidence: message.body,
        bodyPart: part,
      );
    }

    if (_negativeTerms.any(text.contains)) {
      return ChatContextInsight(
        id: '${message.id}:negative',
        messageId: message.id,
        kind: ChatInsightKind.negativeFeedback,
        evidence: message.body,
      );
    }
    return null;
  }

  static const Map<String, String> _bodyParts = <String, String>{
    '무릎': '무릎',
    '허리': '허리',
    '발목': '발목',
    '어깨': '어깨',
    '손목': '손목',
    '목': '목',
    'knee': 'Knee',
    'back': 'Back',
    'ankle': 'Ankle',
    'shoulder': 'Shoulder',
    'wrist': 'Wrist',
  };

  static const List<String> _discomfortTerms = <String>[
    '아프',
    '통증',
    '당기',
    '불편',
    '저리',
    '쑤',
    '붓',
    'pain',
    'hurt',
    'sore',
    'discomfort',
    'stiff',
  ];

  static const List<String> _negativeTerms = <String>[
    '너무 힘들',
    '못 ',
    '못 했',
    '못했',
    '포기',
    '별로',
    '무리',
    '부담',
    '지쳐',
    'too hard',
    'couldn\'t',
    'cannot',
    'gave up',
    'exhausted',
  ];
}
