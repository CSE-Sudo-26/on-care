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

/// 문장에서 신체 부위 하나를 찾는 규칙.
///
/// 부위를 **부분 문자열**로 찾으면 다른 낱말 안에 우연히 든 음절까지 걸린다.
/// `목` 은 목요일·목표에, `back` 은 come back 에 들어 있다. 그래서 부위마다
/// "어디까지가 그 낱말인가" 를 규칙으로 갖는다.
class _BodyPartRule {
  const _BodyPartRule(this.display, this.pattern);

  /// 배너에 그대로 박히는 이름. 문장이 한국어면 한국어, 영어면 영어를 준다.
  final String display;
  final RegExp pattern;
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

    final part = _bodyPartIn(text);
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

  /// 문장이 가리키는 신체 부위. 짚을 것이 없으면 null 이고, 그때 배너는
  /// 부위 없는 문구로 뜬다.
  static String? _bodyPartIn(String text) {
    for (final rule in _bodyParts) {
      if (rule.pattern.hasMatch(text)) return rule.display;
    }
    return null;
  }

  /// 한국어는 앞 음절이 한글이면 **다른 낱말의 꼬리**로 본다 — `발목`·`손목`·
  /// `골목` 의 `목` 이 목으로 잡히지 않게 하는 것이 이 조건이고, 덕분에 이
  /// 목록의 순서가 정확성을 좌우하지 않는다(예전에는 `목` 을 맨 뒤에 둔 덕에
  /// 우연히 맞고 있었다).
  ///
  /// 뒤쪽은 조사가 붙어야 하므로(`목이`·`목만`) 한글을 막을 수 없다. 대신 그
  /// 음절로 시작하는 **다른 낱말**을 명시해 배제한다.
  static final List<_BodyPartRule> _bodyParts = <_BodyPartRule>[
    _BodyPartRule('무릎', RegExp(r'(?<![가-힣])무릎')),
    _BodyPartRule('허리', RegExp(r'(?<![가-힣])허리(?!띠|춤)')),
    _BodyPartRule('발목', RegExp(r'(?<![가-힣])발목')),
    _BodyPartRule('어깨', RegExp(r'(?<![가-힣])어깨')),
    _BodyPartRule('손목', RegExp(r'(?<![가-힣])손목(?!시계)')),
    // 목요일·목표·목적·목록·목소리·목도리·목걸이·목욕.
    _BodyPartRule('목', RegExp(r'(?<![가-힣])목(?!요일|표|적|록|소리|도리|걸이|욕)')),
    _BodyPartRule('Knee', RegExp(r'\bknees?\b')),
    _BodyPartRule('Ankle', RegExp(r'\bankles?\b')),
    _BodyPartRule('Shoulder', RegExp(r'\bshoulders?\b')),
    _BodyPartRule('Wrist', RegExp(r'\bwrists?\b')),
    _BodyPartRule('Neck', RegExp(r'\bnecks?\b')),
    // `back` 만 단어 경계로는 못 가른다 — "i'm back", "back at the gym" 이
    // 전부 온전한 낱말이다. 부위로 읽으려면 그 앞에 소유격·위치어가 오거나
    // 뒤에 통증어가 붙어야 한다.
    _BodyPartRule(
      'Back',
      RegExp(
        r'\b(?:my|your|his|her|their|our|the|lower|upper|mid|middle)\s+backs?\b'
        r'|\bbacks?\s+(?:pain|ache|aches|injury)\b',
      ),
    ),
  ];

  static const List<String> _discomfortTerms = <String>[
    '아프',
    '통증',
    '당기',
    '불편',
    '저리',
    '쑤',
    '붓',
    // 영어 쪽 `stiff` 와 짝이 없어 비어 있던 자리.
    '뻐근',
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
