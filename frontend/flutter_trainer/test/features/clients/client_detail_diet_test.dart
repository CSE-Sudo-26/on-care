import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

/// Seeded client ids by display name — the detail is addressed by id.
const Map<String, String> seedClientIds = <String, String>{
  '김민수': 'seed-client-1',
  '이지수': 'seed-client-2',
  '박성호': 'seed-client-3',
  '강서연': 'seed-client-6',
  // The brand-new client: no meals, no history, no sodium series.
  '임도현': 'seed-client-7',
};

class _DietFailsOnceRepository extends DriftClientRepository {
  _DietFailsOnceRepository(super.db);

  int watchDietCalls = 0;

  @override
  Stream<List<ClientDietEntry>> watchDiet(String clientId) {
    watchDietCalls++;
    if (watchDietCalls == 1) {
      return Stream<List<ClientDietEntry>>.error(
        StateError('diet transport detail'),
      );
    }
    return super.watchDiet(clientId);
  }
}

void main() {
  group('ClientRepository.watchDiet', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('returns the 3 meals in seeded order for a client', () async {
      final meals = await DriftClientRepository(
        db,
      ).watchDiet('seed-client-1').first;
      expect(meals.map((m) => m.meal).toList(), <String>['아침', '점심', '간식']);
      expect(meals.first.items, '스크램블 에그, 딸기');
      expect(meals.first.calories, 217);
      expect(meals.first.sodiumMg, 221);
      expect(meals.first.carbsG, 10);
      expect(meals.first.proteinG, 13.5);
      expect(meals.first.fatG, 14.5);
      expect(meals[1].items, '짬뽕');
      expect(meals[1].calories, 750);
      expect(meals[1].sodiumMg, 3200);
      expect(meals[1].carbsG, 107);
      expect(meals[1].proteinG, 29);
      expect(meals[1].fatG, 22.5);
      expect(meals[2].items, '아이스 아메리카노, 견과류 한 봉');
      expect(meals[2].calories, 100);
      expect(meals[2].sodiumMg, 7);
      expect(meals[2].carbsG, 3);
      expect(meals[2].proteinG, 2.5);
      expect(meals[2].fatG, 8);

      final minsu = (await DriftClientRepository(db).watchClients().first)
          .firstWhere((client) => client.id == 'seed-client-1');
      expect(minsu.calories, 1067);
      expect(minsu.sodiumMg, 3428);
      expect(minsu.sugarG, 17.8);
      expect(minsu.carbsG, 120);
      expect(minsu.proteinG, 45);
      expect(minsu.fatG, 45);
    });

    test('returns per-client data (clients differ)', () async {
      final repo = DriftClientRepository(db);
      final jisu = await repo.watchDiet('seed-client-2').first;
      final seongho = await repo.watchDiet('seed-client-3').first;
      expect(jisu.first.items, '그릭요거트, 과일');
      expect(seongho[1].items, '짜장면'); // 점심
    });
  });

  group('seeded weekly series', () {
    // 계열은 이번 주 월→일이다(#746). 아래 두 테스트는 시드 시계를 고정한다 —
    // 무엇이 이번 주에 남는지는 요일마다 다르므로, 실행한 날에 기대값을 맡기면
    // 코드를 건드리지 않아도 월·화요일에 깨진다(#826).
    Future<List<TrainerClient>> seededOn(DateTime pinned) async {
      // 이 그룹의 `db` 와 겹쳐 열어 두면 drift 가 인스턴스 중복을 경고한다.
      // 로스터를 읽고 나면 볼 일이 없으므로 그 자리에서 닫는다.
      final pinnedDb = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        await seedIfEmpty(pinnedDb, clock: pinned);
        return await DriftClientRepository(pinnedDb).watchClients().first;
      } finally {
        await pinnedDb.close();
      }
    }

    test(
      'client rows carry this week\'s sodium history on its weekdays',
      () async {
        // 2026-08-19 은 수요일, 2026-08-17 은 월요일이다.
        for (final pinned in <DateTime>[
          DateTime(2026, 8, 19, 10),
          DateTime(2026, 8, 17, 10),
        ]) {
          final clients = await seededOn(pinned);
          final todayIndex = pinned.weekday - 1;
          for (final c in clients) {
            // 요일 라벨과 함께 그리므로 길이는 늘 7이고, 오늘 값은 마지막 칸이
            // 아니라 오늘 요일 칸에 놓인다.
            expect(c.sodiumWeek, hasLength(7), reason: '${c.name} on $pinned');
            expect(
              c.sodiumWeek[todayIndex],
              c.sodiumMg,
              reason: '${c.name} on $pinned',
            );
            // 아직 오지 않은 요일은 누구에게나 0 — 기록 없음과 같은 표현이다.
            expect(
              c.sodiumWeek.skip(todayIndex + 1),
              everyElement(0),
              reason: '${c.name} on $pinned',
            );
          }
        }
      },
    );

    test('a seeded day from before Monday stays in last week', () async {
      // 이지수의 시드에서 목표를 넘는 날은 2100 하나뿐이고, 그 값은 오늘에서
      // 이틀 앞이다. 수요일에는 이번 주에 남고 월요일에는 잘려 나간다 — 잘린
      // 날이 집계에 남으면 지난주 기록을 이번 주로 세는 것이다.
      final onWednesday = await seededOn(DateTime(2026, 8, 19, 10));
      final jisuWed = onWednesday.firstWhere((c) => c.name == '이지수');
      expect(jisuWed.sodiumWeek.first, 2100);
      expect(jisuWed.sodiumOverDays, 1);

      final onMonday = await seededOn(DateTime(2026, 8, 17, 10));
      final jisuMon = onMonday.firstWhere((c) => c.name == '이지수');
      expect(jisuMon.sodiumWeek.where((mg) => mg > 0), hasLength(1));
      expect(jisuMon.sodiumOverDays, 0);

      // 픽스처가 정하는 김민수는 자기 날짜대로 놓이므로, 오늘까지의 기록이
      // 있는 한 주 평균이 잡힌다.
      final minsu = onWednesday.firstWhere((c) => c.name == '김민수');
      expect(minsu.sodiumOverDays, greaterThan(0));
      expect(minsu.sodiumWeekAvg, isNotNull);
    });
  });

  group('DietView', () {
    Finder detailScrollable(String clientId) => find
        .descendant(
          of: find
              .descendant(
                of: find.byKey(ValueKey<String>('diet-$clientId')),
                matching: find.byType(ListView),
              )
              .first,
          matching: find.byType(Scrollable),
        )
        .first;

    Future<void> openDiet(WidgetTester tester, String clientName) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail(seedClientIds[clientName]!, section: 'diet'),
      );
    }

    testWidgets('a failed diet retries in place on a narrow viewport', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(480, 700);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail('seed-client-1', section: 'diet'),
        extraOverrides: <Override>[
          clientRepositoryProvider.overrideWith(
            (ref) => _DietFailsOnceRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );

      expect(find.text('식단을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('아직 기록된 식단이 없어요'), findsNothing);
      expect(find.text('diet transport detail'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('diet-retry-seed-client-1')),
      );
      await settle(tester);

      final repository =
          container.read(clientRepositoryProvider) as _DietFailsOnceRepository;
      final context = tester.element(find.byType(Navigator).first);
      expect(repository.watchDietCalls, 2);
      expect(
        GoRouter.of(context).routeInformationProvider.value.uri.toString(),
        AppRoutes.clientDetail('seed-client-1', section: 'diet'),
      );
      expect(find.text('오늘 영양 요약'), findsOneWidget);
      // 회원 앱과 같은 카드다(#698): 칼로리 링 + 탄단지 진행 바 + 나트륨·당류
      // 상태 카드. 예전의 MetricTile 6칸 묶음은 없어졌다.
      expect(
        find.byKey(const Key('client-nutrition-summary-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('client-nutrition-calorie-progress')),
        findsOneWidget,
      );
      final calorieProgress = tester.widget<CircularProgressIndicator>(
        find.byKey(const Key('client-nutrition-calorie-progress')),
      );
      expect(calorieProgress.valueColor?.value, AppColors.primary);
      for (final String label in <String>['탄수화물', '단백질', '지방']) {
        expect(
          find.byKey(Key('client-nutrition-macro-$label')),
          findsOneWidget,
          reason: label,
        );
        expect(
          tester
              .widgetList<ColoredBox>(
                find.descendant(
                  of: find.byKey(Key('client-nutrition-macro-$label')),
                  matching: find.byType(ColoredBox),
                ),
              )
              .any(
                (box) => box.color == AppColors.primary.withValues(alpha: 0.65),
              ),
          isTrue,
          reason: '$label 그래프가 기존 트레이너 앱 색상을 써야 합니다.',
        );
      }
      Finder inMacro(String label, String text) => find.descendant(
        of: find.byKey(Key('client-nutrition-macro-$label')),
        matching: find.textContaining(text),
      );
      expect(inMacro('탄수화물', '120'), findsOneWidget);
      expect(inMacro('단백질', '45'), findsOneWidget);
      expect(inMacro('지방', '45'), findsOneWidget);

      expect(find.text('나트륨 초과'), findsOneWidget);
      final Finder sodiumStatus = find.byKey(
        const Key('client-nutrition-sodium-status'),
      );
      expect(sodiumStatus, findsOneWidget);
      // 천 단위 구분이 들어간다 — 회원 앱과 같은 형식.
      expect(
        find.descendant(
          of: sodiumStatus,
          matching: find.textContaining('3,428', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sodiumStatus, matching: find.textContaining('많아요')),
        findsOneWidget,
        reason: '목표를 넘겼는데 초과 문구가 없습니다.',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('client-nutrition-sugar-status')),
          matching: find.textContaining('17.8', findRichText: true),
        ),
        findsOneWidget,
      );
      // The detail header plus the 7-day trend card push every meal card
      // down, so reach them by scrolling.
      await tester.scrollUntilVisible(
        find.text('아침'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.text('아침'), findsOneWidget);
      expect(find.text('스크램블 에그, 딸기'), findsOneWidget);
      expect(find.text('217 kcal'), findsOneWidget);
      expect(find.text('탄수화물 10g'), findsOneWidget);
      expect(find.text('단백질 13.5g'), findsOneWidget);
      expect(find.text('지방 14.5g'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('점심'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.text('점심'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('간식'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.text('간식'), findsOneWidget);
      // Over-target AI comment (3428 − 2000 = 1428mg) — last list item,
      // built lazily, so scroll it into view first.
      await tester.scrollUntilVisible(
        find.textContaining('나트륨이 목표치를 1428mg 초과했어요'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.textContaining('나트륨이 목표치를 1428mg 초과했어요'), findsOneWidget);
    });

    testWidgets('normal sodium and sugar use the user app sugar green', (
      tester,
    ) async {
      await openDiet(tester, '이지수');

      for (final Key key in <Key>[
        const Key('client-nutrition-sodium-status'),
        const Key('client-nutrition-sugar-status'),
      ]) {
        expect(
          tester
              .widgetList<ColoredBox>(
                find.descendant(
                  of: find.byKey(key),
                  matching: find.byType(ColoredBox),
                ),
              )
              .any((box) => box.color == AppColors.userSugarGreen),
          isTrue,
          reason: '$key 정상 그래프가 사용자 앱 당류 초록색을 써야 합니다.',
        );
      }
    });

    testWidgets('integer-valued sugar keeps the existing compact format', (
      tester,
    ) async {
      await openDiet(tester, '이지수');

      expect(
        find.descendant(
          of: find.byKey(const Key('client-nutrition-sugar-status')),
          matching: find.textContaining('38', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(find.text('38.0'), findsNothing);
    });

    testWidgets('a recorded 0g meal remains a meal instead of empty state', (
      tester,
    ) async {
      await openDiet(tester, '강서연');

      await tester.scrollUntilVisible(
        find.text('거름'),
        150,
        scrollable: detailScrollable('seed-client-6'),
      );
      expect(find.text('아직 기록된 식단이 없어요'), findsNothing);
      expect(find.text('탄수화물 0g'), findsWidgets);
      expect(find.text('단백질 0g'), findsWidgets);
      expect(find.text('지방 0g'), findsWidgets);
    });

    testWidgets('macro values wrap without overflow on a narrow screen', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(480, 700);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await openDiet(tester, '김민수');
      await tester.scrollUntilVisible(
        find.text('탄수화물 10g'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a client with no logged meals gets a hint, not a verdict', (
      tester,
    ) async {
      // 임도현 has not recorded anything yet. The tiles read 0 either
      // way, so without this the tab silently praised a blank day.
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail(seedClientIds['임도현']!, section: 'diet'),
      );

      await tester.scrollUntilVisible(
        find.text('아직 기록된 식단이 없어요'),
        150,
        scrollable: detailScrollable('seed-client-7'),
      );
      expect(find.text('아직 기록된 식단이 없어요'), findsOneWidget);
      expect(find.textContaining('균형이 잘 맞아요'), findsNothing);
      expect(find.textContaining('나트륨이 목표치를'), findsNothing);
      // The trend card is skipped too — there is no series to draw.
      expect(find.text('최근 7일 나트륨 추이'), findsNothing);
    });

    testWidgets('이지수 (sodium under target) shows the balanced AI comment', (
      tester,
    ) async {
      await openDiet(tester, '이지수');

      // The detail header sits above the list, so her 아침 card can start
      // below the fold on the test viewport.
      await tester.scrollUntilVisible(
        find.text('그릭요거트, 과일'),
        150,
        scrollable: detailScrollable('seed-client-2'),
      );
      expect(find.text('그릭요거트, 과일'), findsOneWidget);
      // Under target in the diet summary.
      expect(find.text('mg 초과'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('오늘 식단은 균형이 잘 맞아요'),
        150,
        scrollable: detailScrollable('seed-client-2'),
      );
      expect(find.textContaining('오늘 식단은 균형이 잘 맞아요'), findsOneWidget);
    });
  });
}
