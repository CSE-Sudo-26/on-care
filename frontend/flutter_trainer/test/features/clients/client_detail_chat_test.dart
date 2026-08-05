import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/chat_view.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';

import '../../helpers/pump_app.dart';

/// Delays every insert so tests can act while a send is in flight.
class _SlowChatRepository extends DriftChatRepository {
  const _SlowChatRepository(super.db);

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return super.sendTrainerMessage(clientId: clientId, text: text);
  }
}

/// Blocks on a caller-controlled future so the test can decide exactly
/// when (and whether) the send fails — used to fail AFTER the widget is
/// disposed, deterministically exercising the catch path.
class _ControllableChatRepository extends DriftChatRepository {
  const _ControllableChatRepository(super.db, this.gate);

  final Future<void> gate;

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) => gate;
}

class _StaticLiveChatRepository implements ChatRepository {
  @override
  Stream<List<ClientChatMessage>> watchThread(String clientId) =>
      Stream<List<ClientChatMessage>>.value(<ClientChatMessage>[
        ClientChatMessage(
          id: 'live-1',
          sender: ChatSender.client,
          body: '실제 회원 답장',
          timeLabel: '09:00',
          createdAt: DateTime.utc(2026, 7, 31, 9),
        ),
      ]);

  @override
  Future<void> markThreadRead(String clientId) async {}

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async {}

  @override
  Stream<Map<String, int>> watchUnreadCounts() =>
      Stream<Map<String, int>>.value(const <String, int>{});
}

void main() {
  group('DriftChatRepository', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test(
      'watchThread returns a client thread in chronological order',
      () async {
        final thread = await DriftChatRepository(
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
        final repo = DriftChatRepository(db);
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

    test('sendTrainerMessage refreshes the client list preview', () async {
      final repo = DriftChatRepository(db);
      await repo.sendTrainerMessage(clientId: 'seed-client-2', text: '내일 봬요!');
      final row = await (db.select(
        db.trainerClients,
      )..where((t) => t.id.equals('seed-client-2'))).getSingle();
      expect(row.lastMessage, '내일 봬요!');
      expect(row.lastTime, '방금');
    });

    test(
      'watchUnreadCounts counts client messages until marked read',
      () async {
        final repo = DriftChatRepository(db);

        // Seeded client replies: 김민수 2 · 이지수 1 · 박성호 1.
        var counts = await repo.watchUnreadCounts().first;
        expect(counts['seed-client-1'], 2);
        expect(counts['seed-client-2'], 1);
        expect(counts['seed-client-3'], 1);

        // Opening 김민수's thread clears his badge only.
        await repo.markThreadRead('seed-client-1');
        counts = await repo.watchUnreadCounts().first;
        expect(counts.containsKey('seed-client-1'), isFalse);
        expect(counts['seed-client-2'], 1);

        // A trainer message never counts as unread.
        await repo.sendTrainerMessage(clientId: 'seed-client-1', text: '확인!');
        counts = await repo.watchUnreadCounts().first;
        expect(counts.containsKey('seed-client-1'), isFalse);

        // A NEW client reply after the marker counts again.
        await db
            .into(db.clientChatMessages)
            .insert(
              ClientChatMessagesCompanion.insert(
                id: 'chat-reply-1',
                clientId: 'seed-client-1',
                sender: 'client',
                body: '네 감사합니다!',
                timeLabel: '09:00',
                createdAt: DateTime.now().add(const Duration(seconds: 2)),
              ),
            );
        counts = await repo.watchUnreadCounts().first;
        expect(counts['seed-client-1'], 1);
      },
    );

    test('markThreadRead is idempotent and skips redundant writes', () async {
      final repo = DriftChatRepository(db);

      Future<String?> marker() => db.readValue('chat_read_seed-client-1');

      // First call stores the newest client message's rowid.
      await repo.markThreadRead('seed-client-1');
      final first = await marker();
      expect(first, isNotNull);
      expect((await repo.watchUnreadCounts().first)['seed-client-1'], isNull);

      // Repeat calls must produce the SAME value — an unconditional
      // write would emit on app_key_values and rebuild the list, which
      // is what the write→watch→build concern was about (review PR 241).
      for (var i = 0; i < 3; i++) {
        await repo.markThreadRead('seed-client-1');
      }
      expect(await marker(), first);

      // A trainer message doesn't move the marker (only client messages
      // can be unread).
      await repo.sendTrainerMessage(clientId: 'seed-client-1', text: '확인!');
      await repo.markThreadRead('seed-client-1');
      expect(await marker(), first);

      // A NEW client reply advances it exactly once.
      await db
          .into(db.clientChatMessages)
          .insert(
            ClientChatMessagesCompanion.insert(
              id: 'chat-reply-x',
              clientId: 'seed-client-1',
              sender: 'client',
              body: '넵!',
              timeLabel: '09:00',
              createdAt: DateTime.now().add(const Duration(seconds: 5)),
            ),
          );
      await repo.markThreadRead('seed-client-1');
      final second = await marker();
      expect(second, isNot(first));
      await repo.markThreadRead('seed-client-1');
      expect(await marker(), second);
    });

    test(
      'a same-second reply after markThreadRead still counts as unread',
      () async {
        final repo = DriftChatRepository(db);
        // A fresh client with no seeded messages, so the count is only
        // what this test inserts.
        const cid = 'rowid-test-client';
        final sameSecond = DateTime(2026, 1, 1, 9, 0, 0);

        // First client message, then mark the thread read.
        await db
            .into(db.clientChatMessages)
            .insert(
              ClientChatMessagesCompanion.insert(
                id: 'chat-ss-1',
                clientId: cid,
                sender: 'client',
                body: '첫 메시지',
                timeLabel: '09:00',
                createdAt: sameSecond,
              ),
            );
        await repo.markThreadRead(cid);
        expect((await repo.watchUnreadCounts().first)[cid], isNull);

        // A SECOND reply lands in the very same second. An epoch-second
        // marker (created_at > marker) would miss it because both share
        // the same second; the rowid marker still flags it (review 241).
        await db
            .into(db.clientChatMessages)
            .insert(
              ClientChatMessagesCompanion.insert(
                id: 'chat-ss-2',
                clientId: cid,
                sender: 'client',
                body: '같은 초에 온 두 번째 메시지',
                timeLabel: '09:00',
                createdAt: sameSecond,
              ),
            );
        expect((await repo.watchUnreadCounts().first)[cid], 1);
      },
    );

    test(
      'markThreadRead on a thread with no client message writes nothing',
      () async {
        await DriftChatRepository(db).markThreadRead('no-such-client');
        expect(await db.readValue('chat_read_no-such-client'), isNull);
      },
    );

    test('sendTrainerMessage ignores empty/whitespace input', () async {
      final repo = DriftChatRepository(db);
      final before = (await repo.watchThread('seed-client-1').first).length;
      await repo.sendTrainerMessage(clientId: 'seed-client-1', text: '   ');
      final after = (await repo.watchThread('seed-client-1').first).length;
      expect(after, before);
    });
  });

  group('ClientDetailPage chat', () {
    testWidgets('real chat omits demo-only analysis and sent banners', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(
              const AppConfig(
                environment: Environment.dev,
                apiBaseUrl: 'http://localhost/v1',
                useMockApi: false,
              ),
            ),
            chatRepositoryProvider.overrideWithValue(
              _StaticLiveChatRepository(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatView(
                clientId: 'user-demo',
                clientAvatar: '김',
                clientName: '김민수',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('실제 회원 답장'), findsOneWidget);
      expect(find.textContaining('AI가 김민수님의 식단'), findsNothing);
      expect(find.textContaining('AI 분석 기반 루틴'), findsNothing);
    });

    /// Opens 김민수's 채팅 section directly. The client detail defaults
    /// to 개요 now, so the chat has to be addressed explicitly.
    Future<void> openDetail(WidgetTester tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail('seed-client-1', section: 'chat'),
      );
    }

    testWidgets('shows the header, sub-tabs, and seeded chat', (tester) async {
      await openDetail(tester);

      expect(find.text('개요'), findsOneWidget);
      expect(find.text('채팅'), findsOneWidget);
      expect(find.text('식단'), findsOneWidget);
      expect(find.text('운동'), findsOneWidget);

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

    testWidgets('mashing send while an insert is in flight stores one '
        'message', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          chatRepositoryProvider.overrideWith(
            (ref) => _SlowChatRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(
        tester,
        AppRoutes.clientDetail('seed-client-1', section: 'chat'),
      );

      await tester.enterText(find.byType(TextField), '중복 방지 확인');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 50));
      // Second tap lands while the first insert is still awaiting.
      await tester.tap(
        find.byIcon(Icons.send),
        warnIfMissed: false, // button is disabled mid-flight
      );
      await settle(tester);

      expect(find.text('중복 방지 확인'), findsOneWidget);
    });

    testWidgets('leaving the screen during a slow send does not throw', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          chatRepositoryProvider.overrideWith(
            (ref) => _SlowChatRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(
        tester,
        AppRoutes.clientDetail('seed-client-1', section: 'chat'),
      );

      await tester.enterText(find.byType(TextField), '이탈 중 전송');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 50));
      // Navigate back while the insert is still in flight — the widget
      // is disposed before the await completes.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await settle(tester);

      // Back on the list without a disposed-controller exception.
      expect(find.text('고객'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a send that FAILS after the screen is disposed does not '
        'touch a disposed messenger', (tester) async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          chatRepositoryProvider.overrideWith(
            (ref) => _ControllableChatRepository(
              ref.watch(appDatabaseProvider),
              gate.future,
            ),
          ),
        ],
      );
      await goTo(
        tester,
        AppRoutes.clientDetail('seed-client-1', section: 'chat'),
      );

      await tester.enterText(find.byType(TextField), '이탈 중 실패');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 50));
      // Fully leave the chat (route popped + ChatView disposed) BEFORE
      // the send resolves.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await settle(tester);
      expect(find.text('고객'), findsWidgets);

      // Now fail — the catch must bail on !mounted, not show a snackbar.
      gate.completeError(Exception('send failed'));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('메시지 전송에 실패했어요. 다시 시도해 주세요'), findsNothing);
    });

    testWidgets('switching sub-tabs shows the 식단 and 운동 views', (tester) async {
      await openDetail(tester);

      await tester.tap(find.text('식단'));
      await settle(tester);
      expect(find.text('오늘 영양 요약'), findsOneWidget);

      await tester.tap(find.text('운동'));
      await settle(tester);
      expect(find.text('이번 주 완료율'), findsOneWidget);
    });
  });
}
