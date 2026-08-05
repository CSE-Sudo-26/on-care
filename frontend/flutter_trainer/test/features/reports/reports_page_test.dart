import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';

import '../../helpers/pump_app.dart';

/// 리포트 against the seeded roster — the trainer's own week plus one
/// client's report, and sending it into their chat thread.
void main() {
  Future<ProviderContainer> openReports(
    WidgetTester tester, {
    String? clientId,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: clientId == null ? AppRoutes.reports : AppRoutes.reportFor(clientId),
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

    // The preview box is the message body itself, so the trainer can
    // read it before sending rather than discovering it in the thread.
    expect(find.textContaining('주간 리포트'), findsWidgets);
    expect(find.textContaining('PT 세션'), findsWidgets);
    expect(find.text('고객에게 전송'), findsOneWidget);
  });

  testWidgets('전송 delivers the report into the client chat thread', (
    tester,
  ) async {
    final container = await openReports(tester);

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
