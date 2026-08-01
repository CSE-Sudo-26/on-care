import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/trainer_routine_options_repository.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/routine_options.dart';
import 'package:oncare_trainer/features/ai_routine/presentation/pages/ai_routine_options_flow.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

const _mockConfig = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'http://localhost/v1',
  useMockApi: true,
);

const _client = TrainerClient(
  id: 'm1',
  name: '김민수',
  avatar: '김',
  goal: '혈압 관리 · 체중 감량',
  lastMessage: '',
  lastTime: '',
  active: true,
  calories: 1800,
  sodiumMg: 2100,
  sugarG: 40,
  lastRoutine: '저강도 유산소',
  weekCompletion: <int>[100, 0, 60, 0, 0, 0, 0],
  sodiumWeek: <int>[],
);

class _CapturingRoutineRepository implements TrainerRoutineRepository {
  AssignedRoutine? assigned;
  String? memberId;

  @override
  Future<void> assignRoutine(String memberId, AssignedRoutine routine) async {
    this.memberId = memberId;
    assigned = routine;
  }

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) =>
      Stream<List<AssignedRoutine>>.value(const <AssignedRoutine>[]);
}

/// Always throws [error] from `assignRoutine`, to exercise the send
/// button's failure-message branching (network vs. other).
class _ThrowingRoutineRepository implements TrainerRoutineRepository {
  _ThrowingRoutineRepository(this.error);

  final Object error;

  @override
  Future<void> assignRoutine(String memberId, AssignedRoutine routine) async {
    throw error;
  }

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) =>
      Stream<List<AssignedRoutine>>.value(const <AssignedRoutine>[]);
}

/// Drives the flow from the initial analysis stage to the send button
/// being visible and tappable, without actually tapping it — mirrors the
/// setup half of the "inline flow" test above.
Future<void> _driveToSendReady(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey<String>('generate-routine-options')),
  );
  await tester.tap(
    find.byKey(const ValueKey<String>('generate-routine-options')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('routine-option-B')));
  await tester.pumpAndSettle();

  await tester.ensureVisible(
    find.byKey(const ValueKey<String>('complete-routine-review')),
  );
  await tester.tap(
    find.byKey(const ValueKey<String>('complete-routine-review')),
  );
  await tester.pumpAndSettle();

  await tester.ensureVisible(
    find.byKey(const ValueKey<String>('send-selected-routine')),
  );
}

void main() {
  group('trainerRoutineOptionsRepositoryProvider', () {
    test('mock when USE_MOCK_API=true', () {
      final c = ProviderContainer(
        overrides: <Override>[appConfigProvider.overrideWithValue(_mockConfig)],
      );
      addTearDown(c.dispose);
      expect(
        c.read(trainerRoutineOptionsRepositoryProvider),
        isA<MockTrainerRoutineOptionsRepository>(),
      );
    });

    test('mock generator produces a shorter A and a stronger B', () async {
      final repo = const MockTrainerRoutineOptionsRepository();
      final o = await repo.generate(
        'm1',
        availableMinutes: 40,
        intensityPreference: 'moderate',
        trainerNote: '무릎',
      );
      expect(o.planA.key, 'A');
      expect(o.planB.key, 'B');
      expect(o.planA.totalMinutes, lessThan(o.planB.totalMinutes));
      expect(o.planA.rationale, contains('2100mg'));
      expect(o.planA.rationale, contains('무릎')); // trainer note reflected
    });
  });

  testWidgets('inline flow: analyse → horizontal options → edit/send', (
    tester,
  ) async {
    // Tall viewport so every step's content fits (buttons sit at the bottom
    // of a scrolling list otherwise, and taps miss off-screen).
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final assigned = _CapturingRoutineRepository();
    List<RoutineExercise>? reviewed;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_mockConfig),
          trainerRoutineRepositoryProvider.overrideWithValue(assigned),
        ],
        child: MaterialApp(
          home: AiRoutineOptionsFlow(
            client: _client,
            recommendedExercises: <RoutineExercise>[
              RoutineExercise(name: '실내 자전거', minutes: 20, type: '유산소'),
            ],
            recommendedReason: '기존 회원 데이터 기반 추천',
            onReviewCompleted: (exercises) => reviewed = exercises,
          ),
        ),
      ),
    );

    // The assistant analysis is editable, while its suggestion remains a
    // muted placeholder until the trainer types a memo.
    expect(find.text('회원 데이터를 분석했어요'), findsOneWidget);
    final initialMemo = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('analysis-trainer-memo')),
    );
    expect(initialMemo.decoration?.hintStyle?.color, AppColors.mutedForeground);
    await tester.enterText(
      find.byKey(const ValueKey<String>('analysis-trainer-memo')),
      '무릎 충격 주의',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('generate-routine-options')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('generate-routine-options')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // A/B + the existing recommendation share one horizontal option rail.
    expect(
      find.byKey(const ValueKey<String>('routine-options-horizontal-scroll')),
      findsOneWidget,
    );
    expect(find.textContaining('회복안 · 회복·지속 중심'), findsOneWidget);
    expect(find.textContaining('강화안 · 강도·운동량 중심'), findsOneWidget);
    expect(find.textContaining('기존안 · 기존 AI 추천'), findsOneWidget);
    final optionHeights = <String>['A', 'B', '추천']
        .map(
          (key) => tester
              .getSize(find.byKey(ValueKey<String>('routine-option-$key')))
              .height,
        )
        .toSet();
    expect(optionHeights, hasLength(1));

    // Select B and edit its first exercise in the common inline editor.
    await tester.tap(find.byKey(const ValueKey<String>('routine-option-B')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '인터벌 걷기');
    final minutesSlider = find.descendant(
      of: find.byKey(const ValueKey<String>('routine-minutes-0')),
      matching: find.byType(Slider),
    );
    tester.widget<Slider>(minutesSlider).onChanged?.call(20);
    await tester.pump();
    expect(find.text('20분'), findsWidgets);
    for (final category in <String>['걷기', '유산소', '근력', '요가', '스트레칭', '기타']) {
      expect(
        find.byKey(ValueKey<String>('routine-category-B-0-$category')),
        findsOneWidget,
      );
    }
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('complete-routine-review')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('complete-routine-review')),
    );
    await tester.pumpAndSettle();
    expect(reviewed, isNotNull);
    expect(reviewed!.first.name, '인터벌 걷기');
    expect(
      find.byKey(const ValueKey<String>('reviewed-routine-list')),
      findsOneWidget,
    );

    expect(assigned.memberId, isNull);
    expect(assigned.assigned, isNull);
    expect(
      find.byKey(const ValueKey<String>('open-client-chat')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('send-selected-routine')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('send-selected-routine')),
    );
    await tester.pumpAndSettle();

    expect(assigned.memberId, 'm1');
    expect(assigned.assigned, isNotNull);
    expect(assigned.assigned!.name, 'AI 맞춤 루틴 (강화안)');
    expect(assigned.assigned!.minutes, 35);
    expect(assigned.assigned!.reason, contains('무릎 충격 주의'));
    expect(assigned.assigned!.reason, contains('인터벌 걷기 20분'));
    expect(
      find.byKey(const ValueKey<String>('routine-sent-confirmation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('open-client-chat')),
      findsOneWidget,
    );
  });

  testWidgets(
    'a network/timeout assign failure shows the ambiguous verify-first '
    "message, not '다시 시도' (assign is not idempotent — retrying on an "
    'ambiguous failure risks a duplicate routine)',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_mockConfig),
            trainerRoutineRepositoryProvider.overrideWithValue(
              _ThrowingRoutineRepository(const NetworkError()),
            ),
          ],
          child: MaterialApp(
            home: AiRoutineOptionsFlow(
              client: _client,
              recommendedExercises: <RoutineExercise>[
                RoutineExercise(name: '실내 자전거', minutes: 20, type: '유산소'),
              ],
              recommendedReason: '기존 회원 데이터 기반 추천',
            ),
          ),
        ),
      );

      await _driveToSendReady(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('send-selected-routine')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('응답을 받지 못했어요. 고객의 받은 루틴을 확인한 뒤 필요한 경우에만 다시 보내주세요'),
        findsOneWidget,
      );
      expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsNothing);
    },
  );

  testWidgets('a non-network assign failure shows the generic retry message '
      '(a clear failure, safe to retry)', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_mockConfig),
          trainerRoutineRepositoryProvider.overrideWithValue(
            _ThrowingRoutineRepository(const ServerError()),
          ),
        ],
        child: MaterialApp(
          home: AiRoutineOptionsFlow(
            client: _client,
            recommendedExercises: <RoutineExercise>[
              RoutineExercise(name: '실내 자전거', minutes: 20, type: '유산소'),
            ],
            recommendedReason: '기존 회원 데이터 기반 추천',
          ),
        ),
      ),
    );

    await _driveToSendReady(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('send-selected-routine')),
    );
    await tester.pumpAndSettle();

    expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
    expect(
      find.text('응답을 받지 못했어요. 고객의 받은 루틴을 확인한 뒤 필요한 경우에만 다시 보내주세요'),
      findsNothing,
    );
  });
}
