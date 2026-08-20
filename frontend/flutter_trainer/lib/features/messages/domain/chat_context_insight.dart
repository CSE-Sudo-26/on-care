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
    if (_matches(_discomfortPatterns, text)) {
      return ChatContextInsight(
        id: '${message.id}:discomfort',
        messageId: message.id,
        kind: ChatInsightKind.discomfort,
        evidence: message.body,
        bodyPart: part,
      );
    }

    if (_matches(_negativePatterns, text)) {
      return ChatContextInsight(
        id: '${message.id}:negative',
        messageId: message.id,
        kind: ChatInsightKind.negativeFeedback,
        evidence: message.body,
      );
    }
    return null;
  }

  static bool _matches(List<RegExp> patterns, String text) =>
      patterns.any((RegExp p) => p.hasMatch(text));

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

  /// 통증을 말하는 표현. 부위와 **같은 규칙**을 쓴다(#963) — 어간을 부분
  /// 문자열로 찾으면 `아프리카` 의 `아프` 까지 통증이 되고, 어간 하나만 두면
  /// `아프네요` 는 잡으면서 한국어에서 가장 흔한 `아파요` 를 지나친다. 활용형과
  /// 경계 규칙은 함께 가야 한다(#975).
  ///
  /// 앞 음절이 한글이면 다른 낱말의 꼬리로 본다(`(?<![가-힣])`). 뒤쪽은 조사와
  /// 어미가 붙어야 하므로 한글을 막을 수 없어, 그 음절로 시작하는 **다른
  /// 낱말**을 명시해 배제한다.
  static final List<RegExp> _discomfortPatterns = <RegExp>[
    // 아프다·아파요·아팠어요·아픈·아픔·아픕니다.
    // `아파트` 와 `아프리카` 는 통증이 아니다.
    RegExp(r'(?<![가-힣])아(?:프(?!리카|리칸|간)|파(?!트)|팠|픈|픔|픕)'),
    // 앞을 막지 않는 유일한 한국어 항목이다 — `근육통증`·`관절통증` 처럼 다른
    // 낱말 뒤에 붙어도 뜻이 그대로다.
    RegExp(r'통증'),
    // 당기다·당겨요·당겼어요·당김.
    RegExp(r'(?<![가-힣])당(?:기|겨|겼|김)'),
    RegExp(r'(?<![가-힣])불편'),
    // 저리다·저려요·저렸어요·저릿하다. `저리 가` 는 통증이 아니라 방향이다.
    RegExp(r'(?<![가-힣])저(?:리(?!\s*가)|려|렸|릿)'),
    // 쑤시다·쑤셔요. 어간 `쑤` 만 두면 다른 낱말의 첫 음절까지 걸린다.
    RegExp(r'(?<![가-힣])쑤(?:시|셔|셨|신)'),
    // 붓다·부어요·부었어요·붓기.
    RegExp(r'(?<![가-힣])(?:붓|부어|부었|부기)'),
    RegExp(r'(?<![가-힣])뻐근'),
    // 영어는 낱말 경계로 가른다. 부위의 `back` 과 달리 이 낱말들은 문맥 없이도
    // 통증을 뜻한다.
    RegExp(r'\bpain(?:s|ful|fully)?\b'),
    RegExp(r'\bhurt(?:s|ing)?\b'),
    RegExp(r'\bsore(?:s|ness)?\b'),
    RegExp(r'\bdiscomforts?\b'),
    RegExp(r'\bstiff(?:ness)?\b'),
    // 부위 규칙이 `back ache` 를 부위로 읽으면서도 통증어 목록에는 없어,
    // `my back aches` 가 아무 신호도 만들지 않고 있었다.
    RegExp(r'\bach(?:e|es|ed|ing|y)\b'),
  ];

  /// 운동을 못 했다는 보고. 같은 경계 규칙을 쓴다.
  static final List<RegExp> _negativePatterns = <RegExp>[
    RegExp(r'너무\s*힘들'),
    // 못 갔어요·못했어요·못하겠어요. `연못 근처` 의 꼬리는 아니다.
    RegExp(r'(?<![가-힣])못(?:\s|했|하|해)'),
    RegExp(r'(?<![가-힣])포기'),
    RegExp(r'(?<![가-힣])별로'),
    // 프로그램이 준비운동·본운동·마무리로 나뉘어 있어(#934) `마무리` 는 이
    // 대화에서 흔한 말이다. 그 꼬리를 무리로 읽으면 **잘 마쳤다는 보고가
    // 경고 배너로 뜬다**. `아무리` 도 같은 이유로 걸러진다.
    RegExp(r'(?<![가-힣])무리(?!수)'),
    RegExp(r'(?<![가-힣])부담'),
    // 지쳐요·지쳤어요. `지침`(안내)은 지친 것이 아니다.
    RegExp(r'(?<![가-힣])지(?:쳐|쳤)'),
    RegExp(r'\btoo hard\b'),
    RegExp(r"\bcouldn'?t\b"),
    RegExp(r'\bcannot\b'),
    RegExp(r'\bgave up\b'),
    RegExp(r'\bexhausted\b'),
  ];
}
