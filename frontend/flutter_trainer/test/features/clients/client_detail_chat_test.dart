import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/clients/data/repositories/chat_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_chat_message.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('ChatRepository', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test(
      'watchThread returns a client thread in chronological order',
      () async {
        final thread = await ChatRepository(
          db,
        ).watchThread('seed-client-1').first;
        expect(thread, isNotEmpty);
        // Seeded 김민수 thread opens with the trainer's sodium question.
        expect(thread.first.sender, ChatSender.trainer);
        expect(thread.first.body, contains('AI 식단 분석'));
        // Sorted ascending by createdAt.
        for (var i = 1; i < thread.length; i++) {
          expect(
            thread[i].createdAt.isBefore(thread[i - 1].createdAt),
            isFalse,
          );
        }
      },
    );

    test(
      'sendTrainerMessage appends a trainer message that sorts last',
      () async {
        final repo = ChatRepository(db);
        await repo.sendTrainerMessage(
          clientId: 'seed-client-1',
          text: '  안녕하세요  ',
        );

        final thread = await repo.watchThread('seed-client-1').first;
        final last = thread.last;
        expect(last.sender, ChatSender.trainer);
        expect(last.body, '안녕하세요'); // trimmed
        expect(last.id.startsWith('seed-'), isFalse); // survives re-seed
      },
    );

    test('sendTrainerMessage ignores empty/whitespace input', () async {
      final repo = ChatRepository(db);
      final before = (await repo.watchThread('seed-client-1').first).length;
      await repo.sendTrainerMessage(clientId: 'seed-client-1', text: '   ');
      final after = (await repo.watchThread('seed-client-1').first).length;
      expect(after, before);
    });
  });

  group('ClientDetailPage chat', () {
    Future<void> openDetail(WidgetTester tester) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');
      await tester.tap(find.text('김민수'));
      await settle(tester);
    }

    testWidgets('shows the header, sub-tabs, and seeded chat', (tester) async {
      await openDetail(tester);

      expect(find.text('채팅'), findsOneWidget);
      expect(find.text('식단'), findsOneWidget);
      expect(find.text('운동기록'), findsOneWidget);

      // The thread auto-scrolls to the newest message; drag back up so
      // the lazily-built top of the thread (banner + early replies) exists.
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pump();
      expect(find.textContaining('AI가 김민수님의'), findsOneWidget);
      // A seeded client reply is present.
      expect(find.text('찌개 먹을 때 국물을 많이 마셨나봐요 😅'), findsOneWidget);
    });

    testWidgets('sending a message appends it to the thread', (tester) async {
      await openDetail(tester);

      await tester.enterText(find.byType(TextField), '다음 세션 때 봐요!');
      await tester.tap(find.byIcon(Icons.send));
      await settle(tester);

      expect(find.text('다음 세션 때 봐요!'), findsOneWidget);
    });

    testWidgets('switching sub-tabs shows the 식단 and 운동기록 views', (
      tester,
    ) async {
      await openDetail(tester);

      await tester.tap(find.text('식단'));
      await settle(tester);
      expect(find.text('오늘 영양 요약'), findsOneWidget);

      await tester.tap(find.text('운동기록'));
      await settle(tester);
      expect(find.text('이번 주 완료율'), findsOneWidget);
    });
  });
}
