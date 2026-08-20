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
