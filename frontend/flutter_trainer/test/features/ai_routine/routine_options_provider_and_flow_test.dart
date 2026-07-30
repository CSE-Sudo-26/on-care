import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/trainer_routine_options_repository.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/assigned_routine.dart';
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

  testWidgets('3-step flow: steer → generate → compare → select → edit/send', (
    tester,
  ) async {
    // Tall viewport so every step's content fits (buttons sit at the bottom
    // of a scrolling list otherwise, and taps miss off-screen).
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final assigned = _CapturingRoutineRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_mockConfig),
          trainerRoutineRepositoryProvider.overrideWithValue(assigned),
        ],
        child: const MaterialApp(home: AiRoutineOptionsFlow(client: _client)),
      ),
    );

    // Step 1 — steering visible.
    expect(find.text('회원 분석'), findsOneWidget);
    expect(find.text('✦ AI로 A/B 루틴 생성'), findsOneWidget);

    // Generate (mock has a short delay). The button sits below the fold in
    // the default test viewport — scroll it in first.
    await tester.ensureVisible(find.text('✦ AI로 A/B 루틴 생성'));
    await tester.tap(find.text('✦ AI로 A/B 루틴 생성'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Step 2 — both plans shown.
    expect(find.textContaining('A안 · 회복·지속 중심'), findsOneWidget);
    expect(find.textContaining('B안 · 강도·운동량 중심'), findsOneWidget);

    // Select B, then move to edit/send.
    await tester.tap(find.textContaining('B안 · 강도·운동량 중심'));
    await tester.pump();
    await tester.ensureVisible(find.text('B안 선택하고 수정'));
    await tester.tap(find.text('B안 선택하고 수정'));
    await tester.pumpAndSettle();

    // Step 3 — edit the selected plan, then send the exact edited summary.
    expect(find.text('회원에게 전송'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('routine-minute-plus-0')),
    );
    await tester.enterText(find.byType(TextField), '무릎 충격 주의');
    await tester.tap(find.text('회원에게 전송'));
    await tester.pumpAndSettle();

    expect(assigned.memberId, 'm1');
    expect(assigned.assigned, isNotNull);
    expect(assigned.assigned!.name, 'AI 맞춤 루틴 (B안)');
    expect(assigned.assigned!.minutes, 35);
    expect(assigned.assigned!.reason, contains('무릎 충격 주의'));
    expect(assigned.assigned!.reason, contains('인터벌 러닝 20분'));
  });
}
