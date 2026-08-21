import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/trainer_memo.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/services/trainer_memo_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('messages route renders the two-pane conversation workspace', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');
      await goTo(tester, AppRoutes.messagesFor('seed-client-1'));

      expect(find.text('대화'), findsOneWidget);
      expect(find.textContaining('읽지 않음'), findsOneWidget);
      final detail = find.byKey(
        const ValueKey<String>('messages-client-detail-button'),
      );
      expect(
        find.descendant(of: detail, matching: find.text('고객 상세')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: detail, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsWidgets);

      final selectedTile = find.byKey(
        const ValueKey<String>('messages-conversation-seed-client-1'),
      );
      final avatar = tester.widget<ClientAvatar>(
        find.descendant(of: selectedTile, matching: find.byType(ClientAvatar)),
      );
      expect(avatar.showStatus, isFalse);
      expect(avatar.size, 36);
      final surface = tester.widget<Material>(
        find
            .descendant(of: selectedTile, matching: find.byType(Material))
            .first,
      );
      expect(surface.color, AppColors.accentSurface);
      final tappable = tester.widget<InkWell>(
        find.descendant(of: selectedTile, matching: find.byType(InkWell)),
      );
      expect(tappable.borderRadius, const BorderRadius.all(AppRadius.card));
      final cardBody = tester.widget<Container>(
        find
            .descendant(of: selectedTile, matching: find.byType(Container))
            .first,
      );
      expect(cardBody.padding, const EdgeInsets.all(AppSpacing.lg));
      expect(cardBody.constraints?.minHeight, 88);

      final listColumn = tester.widget<SizedBox>(
        find.ancestor(
          of: selectedTile,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox && widget.width == AppLayout.splitListWidth,
          ),
        ),
      );
      expect(listColumn.width, AppLayout.splitListWidth);
    });
  });

  testWidgets('conversation list keeps unread and status information', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      // 박성호의 배지는 요일에 따라 뒤집힌다. 시드가 주간 계열을 오늘까지만
      // 채우므로, 화요일에는 그 주에 기록된 날이 33% 하루뿐이라 이행률 저조가
      // 나트륨 초과보다 급한 신호가 된다. 주가 끝난 일요일로 고정해 어느 날
      // 돌려도 같은 상태를 본다.
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token-existing',
        seedClock: DateTime(2026, 8, 16), // 일요일
      );
      await goTo(tester, AppRoutes.messages);

      final conversation = find.byKey(
        const ValueKey<String>('messages-conversation-seed-client-3'),
      );
      expect(conversation, findsOneWidget);
      // 미리보기는 스레드의 **마지막** 메시지다 — 회원이 보낸 옛 메시지가
      // 아니라, 트레이너가 마지막으로 보낸 답장이 뜬다.
      expect(
        find.descendant(
          of: conversation,
          matching: find.textContaining('이해해요! 대신 AI 식단 분석'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('messages-unread-seed-client-3')),
        findsOneWidget,
      );
      // 목록은 어느 대화를 열까를 정하는 자리다 — 이름 · 시각 · 마지막
      // 말 · 안읽음뿐이고, 목표도 상태도 없다.
      expect(
        find.descendant(of: conversation, matching: find.text('근력 향상')),
        findsNothing,
      );
      expect(
        find.descendant(of: conversation, matching: find.text('나트륨 초과')),
        findsNothing,
      );
      // 목표 자리를 미리보기가 가져갔다 — 두 줄이면 뒤에 무엇이 붙는지까지
      // 읽히고, 열어 볼 대화인지 목록에서 판단할 수 있다.
      final preview = tester.widget<Text>(
        find.descendant(
          of: conversation,
          matching: find.textContaining('이해해요! 대신 AI 식단 분석'),
        ),
      );
      expect(preview.maxLines, 2);
    });
  });

  testWidgets('conversation without a thread still shows a preview line', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      // 실 API 는 대화가 없는 고객의 `last_message` 를 빈 문자열로 준다.
      // 그대로 그리면 미리보기 줄이 통째로 사라져 타일 높이가 고객마다
      // 달라졌다 — 빈 값도 뜻을 갖고 한 줄을 지켜야 한다.
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token-existing',
        extraOverrides: <Override>[
          clientsProvider.overrideWith(
            (ref) => Stream<List<TrainerClient>>.value(<TrainerClient>[
              const TrainerClient(
                id: 'quiet-client',
                name: '한조용',
                avatar: '한',
                goal: '목표 설정 전',
                lastMessage: '',
                lastTime: '-',
                active: true,
                calories: 0,
                sodiumMg: 0,
                sugarG: 0,
                lastRoutine: '-',
                weekCompletion: <int>[],
                sodiumWeek: <int>[],
              ),
            ]),
          ),
        ],
      );
      await goTo(tester, AppRoutes.messages);

      final conversation = find.byKey(
        const ValueKey<String>('messages-conversation-quiet-client'),
      );
      expect(conversation, findsOneWidget);
      expect(
        find.descendant(of: conversation, matching: find.text('아직 대화가 없어요')),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'narrowest desktop split keeps message and time without overflow',
    (tester) async {
      await withWideSurface(tester, size: const Size(1024, 760), () async {
        await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');
        await goTo(tester, AppRoutes.messagesFor('seed-client-1'));

        final conversation = find.byKey(
          const ValueKey<String>('messages-conversation-seed-client-1'),
        );
        expect(
          find.descendant(
            of: conversation,
            matching: find.textContaining('확인했어요.'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: conversation, matching: find.text('18:18')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('thread header is the detailed side: status and every alert', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      // 배지 우선순위는 요일에 따라 뒤집힌다 — 주가 끝난 일요일로 고정한다.
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token-existing',
        seedClock: DateTime(2026, 8, 16), // 일요일
      );
      await goTo(tester, AppRoutes.messagesFor('seed-client-3'));

      final identity = find.byKey(
        const ValueKey<String>('messages-thread-identity'),
      );
      expect(identity, findsOneWidget);
      // 활성/휴면은 메시지 탭 어디에도 없다 — 이 사람과 지금 이야기하는
      // 데 쓰이지 않는 값이고, 바꿀 수 있는 자리도 고객 탭이다.
      expect(
        find.byKey(const ValueKey<String>('messages-thread-status')),
        findsNothing,
      );
      expect(find.text('휴면'), findsNothing);
      expect(find.text('활성'), findsNothing);
      // 주의 배지는 **전부** 선다 — 나트륨이 넘쳤다는 사실은 지금 이
      // 대화에서 할 말을 바꾼다.
      expect(
        find.descendant(of: identity, matching: find.text('나트륨 초과')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: identity, matching: find.text('당류 초과')),
        findsOneWidget,
      );
      // 대화 화면은 대화만 한다 — 운동 데이터는 고객 탭이 보여 준다.
      expect(find.textContaining('최근 운동'), findsNothing);
      expect(find.textContaining('주간 이행률'), findsNothing);
    });
  });

  testWidgets('client query keeps the selected member in the thread', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');
      await goTo(tester, AppRoutes.messagesFor('seed-client-2'));

      expect(
        find.byKey(const ValueKey<String>('messages-thread-seed-client-2')),
        findsOneWidget,
      );
    });
  });

  testWidgets('new workspace labels render in English locale', (tester) async {
    await withWideSurface(tester, () async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token-existing',
        locale: const Locale('en'),
      );
      await goTo(tester, AppRoutes.messagesFor('seed-client-1'));

      expect(find.text('Messages'), findsWidgets);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.textContaining('Unread'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('messages-client-detail-button'),
          ),
          matching: find.text('Client details'),
        ),
        findsOneWidget,
      );
      expect(find.text('대화'), findsNothing);
      expect(find.text('프로그램'), findsNothing);
    });
  });

  testWidgets('mobile back keeps the active conversation filter', (
    tester,
  ) async {
    await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');
    await goTo(
      tester,
      AppRoutes.messagesFor('seed-client-1', filter: 'unread'),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    final context = tester.element(find.byType(Navigator).first);
    expect(
      GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.uri.queryParameters['f'],
      'unread',
    );
  });

  testWidgets('detected discomfort can be persisted as a trainer memo', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token-existing',
      );
      await goTo(tester, AppRoutes.messagesFor('seed-client-1'));

      expect(find.text('무릎 불편 표현 감지'), findsOneWidget);
      final addButton = find.byKey(
        const ValueKey<String>('chat-insight-add-seed-chat-1-16:discomfort'),
      );
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await settle(tester);

      expect(find.text('메모 추가됨'), findsOneWidget);
      // 옮겨 적은 뒤에는 바탕만 비운다 — 붉은 바탕은 "아직 볼 것이 있다"
      // 는 신호라, 처리한 배너와 안 한 배너가 똑같이 붉으면 안 된다.
      // 윤곽선과 버튼의 붉은색은 무슨 일이 있었는지를 남긴다.
      final banner = tester.widget<Container>(
        find.byKey(
          const ValueKey<String>('chat-insight-banner-seed-chat-1-16'),
        ),
      );
      final decoration = banner.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.card);
      expect(
        (decoration.border! as Border).top.color,
        AppColors.warning.withValues(alpha: 0.28),
      );
      expect(
        tester.widget<Text>(find.text('메모 추가됨')).style?.color,
        AppColors.warning,
      );
      // 채팅에서 저장한 메모는 회원 상세가 읽는 것과 **같은** 메모 목록에 들어간다.
      final memos = await container
          .read(trainerMemoRepositoryProvider)
          .fetch('seed-client-1');
      expect(memos, hasLength(1));
      expect(memos.single.body, '무릎이 가볍게 당기긴 했는데 괜찮아요');
      expect(memos.single.source, TrainerMemoSource.chatInsight);
    });
  });
}
