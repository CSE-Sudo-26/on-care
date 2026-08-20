import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/messages/domain/chat_context_insight.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';

void main() {
  const detector = ChatContextInsightDetector();
  final now = DateTime(2026, 8, 14);

  ClientChatMessage message(
    String body, {
    ChatSender sender = ChatSender.client,
  }) {
    return ClientChatMessage(
      id: 'message-1',
      sender: sender,
      body: body,
      timeLabel: '18:16',
      createdAt: now,
    );
  }

  test('detects a downplayed discomfort report and its body part', () {
    final insight = detector.detect(message('무릎이 가볍게 당기긴 했는데 괜찮아요'));

    expect(insight?.kind, ChatInsightKind.discomfort);
    expect(insight?.bodyPart, '무릎');
  });

  test('detects negative workout feedback', () {
    final insight = detector.detect(message('이번 주 일이 너무 많아서 운동을 못 갔어요'));

    expect(insight?.kind, ChatInsightKind.negativeFeedback);
  });

  test('does not flag a trainer message', () {
    final insight = detector.detect(
      message('무릎이 불편한지 확인해 보세요', sender: ChatSender.trainer),
    );

    expect(insight, isNull);
  });

  group('body part matching stops at word boundaries', () {
    test('a weekday is not the neck', () {
      final insight = detector.detect(message('목요일에 무리했더니 아직 아프네요'));

      expect(insight?.kind, ChatInsightKind.discomfort);
      expect(insight?.bodyPart, isNull);
    });

    test('a goal is not the neck', () {
      final insight = detector.detect(message('이번 주 목표를 못 했어요'));

      expect(insight?.kind, ChatInsightKind.negativeFeedback);
      expect(insight?.bodyPart, isNull);
    });

    test('a scarf is not the neck', () {
      final insight = detector.detect(message('목도리를 두르니 좀 불편해요'));

      expect(insight?.bodyPart, isNull);
    });

    test('the neck itself is still matched', () {
      final insight = detector.detect(message('목이 뻐근해요'));

      expect(insight?.kind, ChatInsightKind.discomfort);
      expect(insight?.bodyPart, '목');
    });

    test('the neck is matched with a particle attached', () {
      expect(detector.detect(message('목도 좀 아프네요'))?.bodyPart, '목');
    });

    test('ankle and wrist win over the neck regardless of rule order', () {
      expect(detector.detect(message('발목이 아프네요'))?.bodyPart, '발목');
      expect(detector.detect(message('손목이 불편해요'))?.bodyPart, '손목');
    });

    test('a wristwatch is not the wrist', () {
      expect(detector.detect(message('손목시계가 불편해요'))?.bodyPart, isNull);
    });
  });

  group('통증어·부정어도 낱말 경계에서 끊는다 (#975)', () {
    test('마무리 운동 보고는 아무 신호도 만들지 않는다', () {
      // 프로그램이 준비운동·본운동·마무리로 나뉘어 있어(#934) `마무리` 는 이
      // 대화에서 흔한 말이다. 잘 마쳤다는 보고가 경고 배너로 뜨면 안 된다.
      expect(detector.detect(message('마무리 운동까지 다 했어요')), isNull);
    });

    test('아무리 해도 라는 말이 무리로 읽히지 않는다', () {
      expect(detector.detect(message('아무리 해도 재밌네요')), isNull);
    });

    test('무리했다는 보고는 그대로 잡는다', () {
      expect(
        detector.detect(message('어제 좀 무리했어요'))?.kind,
        ChatInsightKind.negativeFeedback,
      );
    });

    test('아프리카는 통증이 아니다', () {
      expect(detector.detect(message('아프리카 다큐 보면서 걸었어요')), isNull);
    });

    test('아파트는 통증이 아니다', () {
      expect(detector.detect(message('아파트 계단으로 올라갔어요')), isNull);
    });

    test('연못은 못 갔다는 말이 아니다', () {
      expect(detector.detect(message('연못 근처를 한 바퀴 걸었어요')), isNull);
    });

    test('가장 흔한 통증 활용형을 모두 잡는다', () {
      // 어간 하나만 두면 `아프네요` 는 잡으면서 `아파요` 를 지나친다.
      for (final (String body, String? part) in <(String, String?)>[
        ('무릎이 아파요', '무릎'),
        ('어제부터 아팠어요', null),
        ('어깨가 저려요', '어깨'),
        ('허리가 당겨요', '허리'),
        ('발목이 부었어요', '발목'),
        ('종아리가 쑤셔요', null),
        ('오늘은 좀 아픔이 있어요', null),
      ]) {
        final insight = detector.detect(message(body));
        expect(
          insight?.kind,
          ChatInsightKind.discomfort,
          reason: '`$body` 를 통증으로 읽지 못했습니다.',
        );
        expect(insight?.bodyPart, part, reason: body);
      }
    });

    test('예전부터 잡히던 표현은 그대로 잡힌다', () {
      for (final (String body, ChatInsightKind kind)
          in <(String, ChatInsightKind)>[
            ('무릎이 아프네요', ChatInsightKind.discomfort),
            ('어깨가 불편해요', ChatInsightKind.discomfort),
            ('통증이 좀 있어요', ChatInsightKind.discomfort),
            ('목이 뻐근해요', ChatInsightKind.discomfort),
            ('운동을 못 갔어요', ChatInsightKind.negativeFeedback),
            ('오늘은 못했어요', ChatInsightKind.negativeFeedback),
            ('너무 힘들어서 포기했어요', ChatInsightKind.negativeFeedback),
            ('별로였어요', ChatInsightKind.negativeFeedback),
            ('오늘은 지쳤어요', ChatInsightKind.negativeFeedback),
            ('계단이 좀 부담돼요', ChatInsightKind.negativeFeedback),
          ]) {
        expect(detector.detect(message(body))?.kind, kind, reason: body);
      }
    });

    test('영어 통증어도 낱말 경계에서 끊는다', () {
      // `painting`·`sorely` 처럼 통증과 무관한 낱말에 어간이 들어 있다.
      expect(detector.detect(message('did some painting today')), isNull);
      expect(
        detector.detect(message('my knee hurts'))?.kind,
        ChatInsightKind.discomfort,
      );
      expect(
        detector.detect(message('my back aches since monday'))?.bodyPart,
        'Back',
      );
    });
  });

  group('english body parts need real word context', () {
    test('coming back to the gym is not the back', () {
      final insight = detector.detect(
        message('back at the gym today, legs are sore'),
      );

      expect(insight?.kind, ChatInsightKind.discomfort);
      expect(insight?.bodyPart, isNull);
    });

    test('a possessive marks the back as a body part', () {
      expect(detector.detect(message('my back is sore'))?.bodyPart, 'Back');
    });

    test('a pain word after it marks the back as a body part', () {
      expect(
        detector.detect(message('lower back pain since monday'))?.bodyPart,
        'Back',
      );
    });

    test('unambiguous parts match on their own, singular or plural', () {
      expect(detector.detect(message('my neck hurts'))?.bodyPart, 'Neck');
      expect(detector.detect(message('both knees are sore'))?.bodyPart, 'Knee');
    });
  });
}
