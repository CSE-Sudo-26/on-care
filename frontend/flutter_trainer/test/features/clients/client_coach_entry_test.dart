import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_coach_repository.dart';

import '../../helpers/pump_app.dart';

/// 시드된 고객 id — 상세는 id 로 주소를 갖는다.
const String _minsuId = 'seed-client-1';

/// 질문을 기록하고 정해진 답을 주는 페이크.
class _FakeCoachRepository implements ClientCoachRepository {
  _FakeCoachRepository({this.answer, this.failure});

  final ClientCoachAnswer? answer;
  final AppError? failure;
  final List<(String, String)> asked = <(String, String)>[];

  @override
  bool get supportsAsk => true;

  @override
  Future<ClientCoachAnswer> ask({
    required String memberId,
    required String message,
  }) async {
    asked.add((memberId, message));
    if (failure != null) throw failure!;
    return answer ?? const ClientCoachAnswer(reply: 'ok');
  }
}

Future<void> _openClient(
  WidgetTester tester, {
  ClientCoachRepository? coach,
}) async {
  await pumpTrainerApp(
    tester,
    token: 'demo-trainer-token',
    at: AppRoutes.clientDetail(_minsuId, section: 'diet'),
    extraOverrides: <Override>[
      if (coach != null)
        clientCoachRepositoryProvider.overrideWithValue(coach),
    ],
  );
}

void main() {
  testWidgets('데모 고객 상세에는 AI 상담 버튼이 없다', (WidgetTester tester) async {
    // 데모에는 근거로 삼을 회원 기록이 없다. 화면이 지금과 같아야 한다.
    await _openClient(tester);

    expect(find.text('AI에게 묻기'), findsNothing);
    // 기존 두 액션은 그대로다.
    expect(find.text('AI 루틴 만들기'), findsWidgets);
    expect(find.text('주간 리포트'), findsWidgets);
  });

  testWidgets('실 API 모드에서는 버튼이 보인다', (WidgetTester tester) async {
    await _openClient(tester, coach: _FakeCoachRepository());

    expect(find.text('AI에게 묻기'), findsOneWidget);
  });

  testWidgets('질문을 보내고 답변과 근거를 보여준다', (WidgetTester tester) async {
    final repo = _FakeCoachRepository(
      answer: const ClientCoachAnswer(
        reply: '국물을 남기도록 안내해 보세요.',
        sources: <String>['고혈압 식이 가이드'],
      ),
    );
    await _openClient(tester, coach: repo);

    await tester.tap(find.text('AI에게 묻기'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '나트륨이 높아요');
    await tester.tap(find.text('물어보기'));
    await settle(tester);

    expect(repo.asked.single.$2, '나트륨이 높아요');
    expect(find.text('국물을 남기도록 안내해 보세요.'), findsOneWidget);
    // 근거 없이 답만 보여 주면 트레이너가 믿어도 되는지 판단할 수 없다.
    expect(find.text('· 고혈압 식이 가이드'), findsOneWidget);
  });

  testWidgets('빈 질문은 서버로 보내지 않는다', (WidgetTester tester) async {
    final repo = _FakeCoachRepository();
    await _openClient(tester, coach: repo);

    await tester.tap(find.text('AI에게 묻기'));
    await settle(tester);
    await tester.tap(find.text('물어보기'));
    await settle(tester);

    expect(repo.asked, isEmpty);
  });

  testWidgets('실패하면 사유를 보여준다', (WidgetTester tester) async {
    final repo = _FakeCoachRepository(
      failure: const NotFoundError(message: '담당 고객이 아니에요'),
    );
    await _openClient(tester, coach: repo);

    await tester.tap(find.text('AI에게 묻기'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '질문');
    await tester.tap(find.text('물어보기'));
    await settle(tester);

    expect(find.text('담당 고객이 아니에요'), findsOneWidget);
  });
}
