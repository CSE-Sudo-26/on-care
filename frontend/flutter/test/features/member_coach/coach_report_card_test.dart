/// 리포트 등록 안내 카드 (#1421).
///
/// 트레이너 앱은 같은 사건을 `ReportRegisteredCard` 로 그린다 — 상태 문구,
/// 대상 주, 다음 행동 한 줄. 짝은
/// `frontend/flutter_trainer/test/features/clients/client_detail_chat_test.dart`
/// 의 `리포트 전송 메시지는 …` 테스트다. 한쪽 문구만 고치면 여기서 깨진다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_report_card.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required Widget child,
    String lang = 'ko',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpChat(WidgetTester tester, {String lang = 'ko'}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_config),
          memberCoachRepositoryProvider.overrideWithValue(
            MockMemberCoachRepository(),
          ),
        ],
        child: MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TrainerChatPage(trainerName: '김트레이너'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('리포트 등록 카드 (#1421)', () {
    testWidgets('상태 문구·대상 주·다음 행동을 한 카드에 담는다', (WidgetTester tester) async {
      var opened = 0;
      await pumpCard(
        tester,
        child: CoachReportCard(
          weekStart: DateTime(2026, 8, 17),
          onOpenPdf: () => opened++,
        ),
      );

      expect(find.text('리포트가 등록되었어요'), findsOneWidget);
      expect(find.text('8월 17일 – 8월 23일'), findsOneWidget);
      expect(find.text('PDF 열기'), findsOneWidget);

      await tester.tap(find.text('PDF 열기'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('열 파일이 없으면 `PDF 열기` 를 그리지 않는다', (WidgetTester tester) async {
      await pumpCard(tester, child: CoachReportCard(weekStart: DateTime(2026, 8, 17)));

      // 상태와 주는 그대로 알려 준다 — 사라지는 것은 동작뿐이다.
      expect(find.text('리포트가 등록되었어요'), findsOneWidget);
      expect(find.text('8월 17일 – 8월 23일'), findsOneWidget);
      expect(find.text('PDF 열기'), findsNothing);
    });

    testWidgets('영어 로케일도 같은 정보 구조다', (WidgetTester tester) async {
      await pumpCard(
        tester,
        lang: 'en',
        child: CoachReportCard(
          weekStart: DateTime(2026, 8, 17),
          onOpenPdf: () {},
        ),
      );

      expect(find.text('Weekly report added'), findsOneWidget);
      expect(find.text('8/17 – 8/23'), findsOneWidget);
      expect(find.text('Open PDF'), findsOneWidget);
    });

    testWidgets('좁은 화면에서 글자를 키워도 넘치지 않는다', (WidgetTester tester) async {
      // `setSurfaceSize` 는 MediaQuery 를 바꾸지 않는다 — 카드가 화면 폭으로
      // 최대 너비를 잡으므로 뷰를 직접 세운다.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpCard(
        tester,
        child: CoachReportCard(
          weekStart: DateTime(2026, 8, 17),
          onOpenPdf: () {},
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('데모 대화의 리포트 등록 (#1421)', () {
    testWidgets('데모 스레드에 카드로 뜨고, 본문은 말풍선으로 겹쳐 그리지 않는다', (
      WidgetTester tester,
    ) async {
      await pumpChat(tester);

      expect(find.byType(CoachReportCard), findsOneWidget);
      expect(find.text('리포트가 등록되었어요'), findsOneWidget);
      expect(find.text('이번 주 리포트 등록해 뒀어요. 확인해 보세요'), findsNothing);
    });

    testWidgets('데모에는 내려받을 파일이 없어 `PDF 열기` 를 보여 주지 않는다', (
      WidgetTester tester,
    ) async {
      await pumpChat(tester);

      expect(find.text('PDF 열기'), findsNothing);
    });

    testWidgets('리포트가 아닌 메시지는 파일명이 무엇이든 카드가 되지 않는다', (
      WidgetTester tester,
    ) async {
      // 파일명으로 리포트 여부를 추측하면, 트레이너가 보낸 `weekly-report.pdf`
      // 라는 이름의 사진도 리포트 카드가 된다.
      final List<CoachMessage> chat = await MockMemberCoachRepository()
          .fetchChat();
      final int cards = chat
          .where((CoachMessage m) => m.reportWeekStart != null)
          .length;

      expect(cards, 1);
      expect(
        chat.where((CoachMessage m) => m.attachment != null),
        isEmpty,
        reason: '데모에는 첨부가 없다 — 카드는 첨부가 아니라 표시로 갈린다',
      );
    });
  });
}
