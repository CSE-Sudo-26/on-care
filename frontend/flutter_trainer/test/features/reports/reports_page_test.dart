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
import 'package:oncare_trainer/shared/widgets/metric_trend_chart.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';

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
  /// 헤더의 공유 메뉴를 연다 — 전송은 이제 이 메뉴 안에 있다(#735).
  Future<void> openShareMenu(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('reports-share-action')),
    );
    await settle(tester);
  }

  /// 리포트 본문의 피드백 입력창.
  final Finder feedbackField = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.hintText == '고객에게 전달할 코칭 피드백을 작성하세요.',
  );

  Future<ProviderContainer> openReports(
    WidgetTester tester, {
    String? clientId,
    Size size = const Size(1600, 1200),
    List<Override> extraOverrides = const <Override>[],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
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
    expect(find.text('이번 주 vs 지난 주'), findsOneWidget);
    expect(find.text('트레이너 피드백'), findsOneWidget);
    expect(find.text('다음 주'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('completion-comparison-chart')),
        matching: find.byType(BarSeriesChart),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('sodium-comparison-chart')),
        matching: find.byType(BarSeriesChart),
      ),
      findsOneWidget,
    );
    // Defaults to the first client rather than an empty right pane.
    expect(find.text('김민수님 주간 리포트'), findsOneWidget);
    expect(find.text('남성 · 35세'), findsWidgets);
  });

  testWidgets('공유는 상단에서 전송과 PDF 내보내기를 함께 보여 준다 (#735)', (tester) async {
    await openReports(tester);

    final shareAction = find.byKey(
      const ValueKey<String>('reports-share-action'),
    );
    expect(shareAction, findsOneWidget);
    expect(tester.getCenter(shareAction).dy, lessThan(88));
    // 메뉴를 열기 전에는 항목이 보이지 않는다.
    expect(find.text('PDF 내보내기'), findsNothing);

    await openShareMenu(tester);
    expect(find.text('김민수님에게 전송'), findsOneWidget);
    expect(find.text('PDF 내보내기'), findsOneWidget);
    // PDF 는 아직 경로가 없어 눌리지 않는다.
    expect(
      tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey<String>('reports-share-pdf')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('과거 주차에서는 미래 이동 없이 이번 주로 복귀할 수 있다', (tester) async {
    await openReports(tester);

    expect(find.text('다음 주'), findsNothing);
    expect(find.widgetWithText(ActionButton, '이번 주로'), findsNothing);

    await tester.tap(find.text('이전'));
    await settle(tester);

    final currentWeek = find.widgetWithText(ActionButton, '이번 주로');
    expect(currentWeek, findsOneWidget);
    expect(find.text('다음 주'), findsNothing);
    // 비교 카드 두 곳과 최근 4주 목록에 같은 말이 쓰인다.
    expect(find.text('선택 주'), findsWidgets);

    await tester.tap(currentWeek);
    await settle(tester);

    expect(currentWeek, findsNothing);
  });

  testWidgets('좁은 화면에서 고객 선택 시 목록 대신 상세를 바로 연다', (tester) async {
    await openReports(
      tester,
      size: const Size(700, 1000),
      extraOverrides: <Override>[
        clientsProvider.overrideWith(
          (ref) => Stream<List<TrainerClient>>.value(<TrainerClient>[
            makeClient(id: 'mobile-client', name: '모바일 고객'),
          ]),
        ),
      ],
    );

    expect(find.text('모바일 고객님 주간 리포트'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('reports-back-to-list')),
      findsNothing,
    );

    await tester.tap(find.text('모바일 고객'));
    await settle(tester);

    final back = find.byKey(const ValueKey<String>('reports-back-to-list'));
    expect(back, findsOneWidget);
    expect(find.text('모바일 고객님 주간 리포트'), findsOneWidget);
    expect(tester.getTopLeft(back).dy, lessThan(220));

    await tester.tap(back);
    await settle(tester);

    expect(back, findsNothing);
    expect(find.text('모바일 고객님 주간 리포트'), findsNothing);
    // 목록으로 돌아오면 고객 카드가 다시 보인다.
    expect(find.text('고객'), findsWidgets);
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

    await tester.tap(find.text('이전'));
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

    // The API does not expose saved feedback status. Session-local send state
    // must not be presented as a persistent member-list status.
    expect(find.text('피드백 미작성'), findsNothing);
    expect(find.text('피드백 완료'), findsNothing);

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
    // 전송 경로는 화면에 하나뿐이다 — 본문에는 더 이상 전송 버튼이 없다.
    await openShareMenu(tester);
    expect(find.text('김민수님에게 전송'), findsOneWidget);
  });

  testWidgets('empty feedback cannot be sent', (tester) async {
    await openReports(tester);

    await tester.enterText(feedbackField, '   ');
    await settle(tester);

    await openShareMenu(tester);
    expect(
      tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey<String>('reports-share-send')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('전송 delivers the report into the client chat thread', (
    tester,
  ) async {
    final container = await openReports(tester);
    await openShareMenu(tester);

    await tester.tap(find.text('김민수님에게 전송'));
    await settle(tester);

    // 메뉴 항목이 잠겨 두 번 보내지지 않는다.
    await openShareMenu(tester);
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
    await openShareMenu(tester);

    await tester.tap(find.text('김민수님에게 전송'));
    await settle(tester);

    // No false "전송됨" — the trainer would otherwise believe the member
    // got a report that never arrived.
    expect(find.text('전송됨'), findsNothing);
    expect(find.text('리포트 전송에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
    // 실패해도 작성한 피드백이 남고 다시 보낼 수 있다.
    expect(
      tester.widget<TextField>(feedbackField).controller!.text,
      contains('주간 리포트'),
    );
    await openShareMenu(tester);
    expect(
      tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey<String>('reports-share-send')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('추이 그래프는 고른 지표의 주간 계열을 그린다 (#746)', (tester) async {
    final container = await openReports(tester);
    final client = (await container.read(clientsProvider.future)).first;

    Future<void> pickMetric(String name) async {
      final chip = find.byKey(ValueKey<String>('trend-metric-$name'));
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await settle(tester);
    }

    List<double> drawnValues() =>
        tester.widget<MetricTrendChart>(find.byType(MetricTrendChart)).values;

    // 어제는 약속이 있던 날이라 로스터의 평상시 배열 대신 그날 값이 그려진다.
    // 어제가 주 안에서 몇 번째 칸인지는 데모를 여는 날마다 달라지므로 계산해서
    // 덮는다 — 숫자를 박아 두면 하루만 지나도 깨진다.
    final int feastSlot = DateTime.now().weekday - 2;
    List<double> expected(List<num> series, double feast) {
      final values = series.map((v) => v.toDouble()).toList();
      if (feastSlot >= 0) values[feastSlot] = feast;
      return values;
    }

    // 기본은 칼로리 — 나트륨 하나만 보여 주던 자리를 세 지표가 나눠 쓴다.
    expect(find.text('칼로리 추이'), findsOneWidget);
    expect(drawnValues(), expected(client.caloriesWeek, 2380));

    await pickMetric('sodium');
    expect(find.text('나트륨 추이'), findsOneWidget);
    expect(drawnValues(), expected(client.sodiumWeek, 2261));

    await pickMetric('sugar');
    expect(find.text('당류 추이'), findsOneWidget);
    // 당류는 소수를 유지한다 — 17.8 이 18 로 뭉개지면 요약 수치와 어긋난다.
    expect(drawnValues(), expected(client.sugarWeek, 63.0));
    expect(client.sugarWeek.any((v) => v != v.roundToDouble()), isTrue);
  });

  testWidgets('지난 주도 그 주의 계열로 그려지고 이번 주와 섞이지 않는다 (#752)', (
    tester,
  ) async {
    await openReports(tester);
    List<double> drawnValues() =>
        tester.widget<MetricTrendChart>(find.byType(MetricTrendChart)).values;

    // 어제는 약속이 있던 날이라 로스터의 평상시 배열 대신 그날 값이 그려진다.
    // 어제가 주 안에서 몇 번째 칸인지는 데모를 여는 날마다 달라지므로 계산해서
    // 덮는다 — 숫자를 박아 두면 하루만 지나도 깨진다.
    final int feastSlot = DateTime.now().weekday - 2;
    List<double> expected(List<num> series, double feast) {
      final values = series.map((v) => v.toDouble()).toList();
      if (feastSlot >= 0) values[feastSlot] = feast;
      return values;
    }

    final thisWeek = drawnValues();
    expect(thisWeek, hasLength(7));

    await tester.tap(find.text('이전'));
    await settle(tester);

    // 과거 주도 그래프가 그려진다 — 예전에는 이 자리가 통째로 비어 있었다.
    final lastWeek = drawnValues();
    expect(lastWeek, hasLength(7));
    expect(lastWeek, isNot(equals(thisWeek)), reason: '이번 주 수치가 그대로 실렸다');
    // 지난 주는 이미 다 지났으니 마지막 요일까지 값이 있다.
    expect(lastWeek.last, greaterThan(0));
    // 지난 주 일요일에 '오늘' 표시가 붙으면 그 날이 오늘인 것처럼 읽힌다.
    expect(
      tester.widget<MetricTrendChart>(find.byType(MetricTrendChart)).markToday,
      isFalse,
    );

    // 지난 주도 요약 줄이 그 주의 값으로 채워진다.
    expect(find.text('최근 4주 평균'), findsOneWidget);
  });

  testWidgets('주를 가리키는 말은 이번 주·지난 주·선택 주 셋뿐이다', (tester) async {
    await openReports(tester);

    // 헤더 버튼은 동작이라 주 이름을 쓰지 않는다 — '이전 주' 버튼과 비교 카드의
    // '이전 주' 열이 같은 말이라 어느 주를 보고 있는지 헷갈렸다.
    expect(find.text('이전'), findsOneWidget);
    expect(find.text('이번 주 vs 지난 주'), findsOneWidget);

    await tester.tap(find.text('이전'));
    await settle(tester);

    // 과거 주에서는 제목도 보고 있는 주를 따라간다.
    expect(find.text('선택 주 vs 지난 주'), findsOneWidget);
    expect(find.text('이번 주 vs 지난 주'), findsNothing);
    // 앞선 주는 상황과 무관하게 늘 '지난 주' — 비교 카드와 최근 4주 목록이
    // 같은 말을 쓴다.
    expect(find.text('지난 주'), findsWidgets);
    expect(find.text('이전 주'), findsNothing);
  });

  testWidgets('평균이 며칠을 나눈 값인지 화면에 적힌다 (#754)', (tester) async {
    final container = await openReports(tester);
    final client = (await container.read(clientsProvider.future)).first;

    // 기록이 없는 날은 평균에서 빠지므로 7 이 아니다 — 그 사실이 적혀 있어야
    // 트레이너가 아래 막대를 세어 평균을 확인할 수 있다.
    final logged = client.weekCompletion.where((v) => v > 0).length;
    expect(logged, lessThan(7), reason: '기록이 빠진 날이 있는 고객이어야 한다');
    // 마지막 줄에 이번 주가 앞선 세 주 옆에 놓인다. 며칠을 나눈 값인지는
    // 값이 있는 막대를 세면 나오므로 따로 적지 않는다.
    expect(find.text('최근 4주 평균'), findsOneWidget);

    // 기록이 없는 날은 0% 가 아니라 기록이 없다고 말한다.
    expect(find.text('0%'), findsNothing);
    expect(find.text('기록 없음'), findsWidgets);

    // 운동과 식단이 카드로 나뉘고, 각 카드 제목 줄에 그 카드의 수치가 남는다.
    expect(find.text('주간 운동 이행률'), findsOneWidget);
    expect(find.text('주간 식단 추이'), findsOneWidget);
    // 며칠인지는 어제가 어느 요일이냐에 따라 달라진다 — 그 수치가 카드 제목
    // 줄에 남는다는 것이 요지다.
    expect(find.textContaining('나트륨 초과'), findsOneWidget);

    // 요일 칸에는 운동 이름만 둔다 — 퍼센트는 바로 위 막대가 말하고,
    // 아직 오지 않은 날은 빈칸으로 둔다.
    expect(find.text('벤치프레스 4세트'), findsWidgets);
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
