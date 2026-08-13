import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

import '../../helpers/client_factory.dart';
import '../../helpers/pump_app.dart';

class _ReportFailsOncePerKeyRepository implements ReportRepository {
  final Map<String, int> _attempts = <String, int>{};
  final List<ReportKey> calls = <ReportKey>[];

  @override
  Stream<WeeklyReport> watch({
    required TrainerClient client,
    required DateTime weekStart,
  }) {
    final key = '${client.id}/${weekStart.toIso8601String()}';
    calls.add((client: client, weekStart: weekStart));
    final attempt = (_attempts[key] ?? 0) + 1;
    _attempts[key] = attempt;
    if (attempt == 1) {
      return Stream<WeeklyReport>.error(StateError('report transport detail'));
    }
    return Stream<WeeklyReport>.value(
      buildWeeklyReport(
        client: client,
        sessions: const [],
        weekStart: weekStart,
      ),
    );
  }

  @override
  Future<void> send({
    required String clientId,
    required DateTime weekStart,
    required String message,
  }) async {}
}

/// 리포트 against the seeded roster — the trainer's own week plus one
/// client's report, and sending it into their chat thread.
void main() {
  Future<void> revealSendAction(WidgetTester tester) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      if (find.text('고객에게 전송').evaluate().isNotEmpty) break;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
      await tester.pump();
    }
    if (find.text('고객에게 전송').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('고객에게 전송'));
      await tester.pump();
    }
  }

  Future<ProviderContainer> openReports(
    WidgetTester tester, {
    String? clientId,
    List<Override> extraOverrides = const <Override>[],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: clientId == null ? AppRoutes.reports : AppRoutes.reportFor(clientId),
      extraOverrides: extraOverrides,
    );
  }

  testWidgets('shows the trainer week alongside a client report', (
    tester,
  ) async {
    await openReports(tester);

    expect(find.text('리포트'), findsWidgets);
    expect(find.text('이번 주 세션'), findsOneWidget);
    expect(find.text('완료'), findsWidgets);
    expect(find.text('프로그램 준비'), findsOneWidget);
    // Defaults to the first client rather than an empty right pane.
    expect(find.text('김민수님 주간 리포트'), findsOneWidget);
  });

  testWidgets('the client query parameter focuses that client', (tester) async {
    await openReports(tester, clientId: 'seed-client-3');
    expect(find.text('박성호님 주간 리포트'), findsOneWidget);
  });

  testWidgets('a failed client roster retries independently', (tester) async {
    int attempts = 0;
    await openReports(
      tester,
      clientId: 'seed-client-3',
      extraOverrides: <Override>[
        clientsProvider.overrideWith((ref) {
          attempts++;
          return attempts == 1
              ? Stream<List<TrainerClient>>.error(
                  StateError('client transport detail'),
                )
              : Stream<List<TrainerClient>>.value(<TrainerClient>[
                  makeClient(id: 'seed-client-1', name: '첫 고객'),
                  makeClient(id: 'seed-client-3', name: '복구 고객'),
                ]);
        }),
      ],
    );

    expect(find.text('리포트를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('client transport detail'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('reports-clients-retry')),
    );
    await settle(tester);

    expect(attempts, 2);
    expect(find.text('복구 고객님 주간 리포트'), findsOneWidget);
  });

  testWidgets('weekly report retry keeps the selected client and week', (
    tester,
  ) async {
    final repository = _ReportFailsOncePerKeyRepository();
    await openReports(
      tester,
      clientId: 'seed-client-3',
      extraOverrides: <Override>[
        reportRepositoryProvider.overrideWithValue(repository),
      ],
    );

    await tester.tap(find.text('이전 주'));
    await settle(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('reports-weekly-retry')),
    );
    await settle(tester);

    final selectedWeek = weekStartOf(
      DateTime.now(),
    ).subtract(const Duration(days: 7));
    final selectedCalls = repository.calls
        .where(
          (call) =>
              call.client.id == 'seed-client-3' &&
              call.weekStart == selectedWeek,
        )
        .toList();
    // Comparison/trend cards legitimately request adjacent weeks too. The
    // failed selected week itself must still be retried without losing scope.
    expect(selectedCalls.length, greaterThanOrEqualTo(2));
    expect(find.text('박성호님 주간 리포트'), findsOneWidget);
    expect(find.text('report transport detail'), findsNothing);
  });

  testWidgets('picking another client swaps the report', (tester) async {
    await openReports(tester);

    await tester.tap(find.text('이지수').last);
    await settle(tester);
    expect(find.text('이지수님 주간 리포트'), findsOneWidget);
  });

  testWidgets('the report previews exactly what the member will receive', (
    tester,
  ) async {
    await openReports(tester);
    await revealSendAction(tester);

    // The preview box is the message body itself, so the trainer can
    // read it before sending rather than discovering it in the thread.
    expect(find.textContaining('주간 리포트'), findsWidgets);
    expect(find.textContaining('PT 세션'), findsWidgets);
    expect(find.text('고객에게 전송'), findsOneWidget);
  });

  testWidgets('empty feedback cannot be sent', (tester) async {
    await openReports(tester);
    await revealSendAction(tester);

    final feedback = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '회원에게 전달할 코칭 피드백을 작성하세요.',
    );
    await tester.enterText(feedback, '   ');
    await tester.pump();

    final button = tester.widget<ActionButton>(
      find.widgetWithText(ActionButton, '고객에게 전송'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('전송 delivers the report into the client chat thread', (
    tester,
  ) async {
    final container = await openReports(tester);
    await revealSendAction(tester);

    await tester.tap(find.text('고객에게 전송'));
    await settle(tester);

    // Button latches so a second tap can't double-send.
    expect(find.text('전송됨'), findsOneWidget);

    final messages = await tester.runAsync(
      () => container
          .read(chatRepositoryProvider)
          .watchThread('seed-client-1')
          .first,
    );
    expect(
      messages!.map((m) => m.body).where((t) => t.contains('주간 리포트')),
      isNotEmpty,
    );
  });

  testWidgets('a failed send keeps the button actionable and warns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.reports,
      extraOverrides: <Override>[
        chatRepositoryProvider.overrideWith(
          (ref) => _FailingChatRepository(ref.watch(appDatabaseProvider)),
        ),
      ],
    );
    await revealSendAction(tester);

    await tester.tap(find.text('고객에게 전송'));
    await settle(tester);

    // No false "전송됨" — the trainer would otherwise believe the member
    // got a report that never arrived.
    expect(find.text('전송됨'), findsNothing);
    expect(find.text('고객에게 전송'), findsOneWidget);
    expect(find.text('리포트 전송에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
  });
}

/// Chat repository whose sends always fail.
class _FailingChatRepository extends DriftChatRepository {
  const _FailingChatRepository(super.db);

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async {
    throw StateError('send failed');
  }
}
