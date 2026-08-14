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
}
