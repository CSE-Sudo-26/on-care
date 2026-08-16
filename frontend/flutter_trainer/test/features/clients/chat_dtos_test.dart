import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/clients/data/dtos/chat_dtos.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';

void main() {
  group('chatMessageFromJson', () {
    test('maps a trainer message', () {
      final m = chatMessageFromJson(<String, Object?>{
        'id': 'c1',
        'sender': 'trainer',
        'body': '오늘 컨디션 어때요?',
        'time_label': '18:10',
        'created_at': '2026-07-30T18:10:00',
      });
      expect(m.id, 'c1');
      expect(m.sender, ChatSender.trainer);
      expect(m.fromTrainer, isTrue);
      expect(m.timeLabel, '18:10');
      expect(m.createdAt, DateTime.parse('2026-07-30T18:10:00'));
      expect(m.attachment, isNull);
    });

    test('maps an optional PDF attachment', () {
      final m = chatMessageFromJson(<String, Object?>{
        'id': 'pdf-1',
        'sender': 'trainer',
        'body': '이번 주 리포트입니다.',
        'time_label': '18:10',
        'created_at': '2026-07-30T18:10:00',
        'attachment': <String, Object?>{
          'type': 'pdf',
          'file_name': '김고객_주간리포트.pdf',
          'file_id': 'abc123',
          'file_size': 2048,
          'download_path': '/chat/attachments/abc123',
        },
      });
      expect(m.attachment?.fileName, '김고객_주간리포트.pdf');
      expect(m.attachment?.fileSize, 2048);
    });

    test('maps the client sender', () {
      final m = chatMessageFromJson(<String, Object?>{
        'id': 'c2',
        'sender': 'client',
        'body': '좋아요!',
        'time_label': '18:12',
        'created_at': '2026-07-30T18:12:00',
      });
      expect(m.sender, ChatSender.client);
      expect(m.fromTrainer, isFalse);
    });

    test('rejects malformed sender and created_at values', () {
      Map<String, Object?> message({
        Object? sender = 'client',
        Object? createdAt = '2026-07-30T18:12:00',
      }) => <String, Object?>{
        'id': 'c3',
        'sender': sender,
        'body': 'x',
        'time_label': '',
        'created_at': createdAt,
      };

      expect(
        () => chatMessageFromJson(message(sender: 'me')),
        throwsFormatException,
      );
      expect(
        () => chatMessageFromJson(message(createdAt: 'not-a-date')),
        throwsFormatException,
      );
    });
  });
}
