import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/messages/data/chat_insight_memo_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
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
      expect(find.widgetWithText(ActionButton, '고객 상세 보기'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);

      final selectedTile = find.byKey(
        const ValueKey<String>('messages-conversation-seed-client-1'),
      );
      final avatar = tester.widget<ClientAvatar>(
        find.descendant(of: selectedTile, matching: find.byType(ClientAvatar)),
      );
      expect(avatar.showStatus, isTrue);
      expect(avatar.size, 36);
      final surface = tester.widget<Material>(
        find
            .descendant(of: selectedTile, matching: find.byType(Material))
            .first,
      );
      expect(surface.color, AppColors.accentSurface);
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
        find.widgetWithText(ActionButton, 'View client details'),
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
      final memos = container
          .read(chatInsightMemoRepositoryProvider)
          .read('seed-client-1');
      expect(memos, hasLength(1));
      expect(memos.single.message, '무릎이 가볍게 당기긴 했는데 괜찮아요');
    });
  });
}
