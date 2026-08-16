import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/ai_coach/domain/entities/ai_coach_state.dart';
import 'package:oncare/features/ai_coach/domain/entities/chat_message.dart';
import 'package:oncare/features/ai_coach/domain/repositories/ai_coach_repository.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/ai_coach_controller.dart';
import 'package:oncare/features/ai_coach/presentation/pages/ai_coach_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 화면만 그리면 되므로 대화는 비워 둔다.
class _QuietRepository implements AiCoachRepository {
  const _QuietRepository();

  @override
  Future<AiCoachState> fetchState() async =>
      const AiCoachState(greeting: '', suggestions: <AiSuggestion>[]);

  @override
  Future<List<ChatMessage>> fetchHistory() async => const <ChatMessage>[];

  @override
  Future<ChatMessage> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async => const ChatMessage(role: ChatRole.coach, content: '네');
}

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          aiCoachRepositoryProvider.overrideWithValue(const _QuietRepository()),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AICoachPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 두 아이콘 모두 예전에는 눌리는 것처럼 보이면서 아무 동작이 없었다(#783).
  // 다시 그려 넣는다면 그때는 실제 동작을 달아야 하므로, 아이콘이 있다는 것
  // 자체를 실패로 잡는다.
  testWidgets('헤더에 동작 없는 더보기 버튼을 그리지 않는다', (WidgetTester tester) async {
    await pumpPage(tester);

    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });

  testWidgets('입력창에 동작 없는 추가 버튼을 그리지 않는다', (WidgetTester tester) async {
    await pumpPage(tester);

    // 보내기 버튼을 함께 확인한다 — 입력창이 그려지지도 않았는데 findsNothing
    // 이라 통과하는 빈 검사가 되지 않도록.
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('살아 있는 버튼은 그대로 남는다', (WidgetTester tester) async {
    await pumpPage(tester);

    // 죽은 버튼을 지우면서 뒤로 가기까지 함께 지우는 실수를 막는다.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });
}
