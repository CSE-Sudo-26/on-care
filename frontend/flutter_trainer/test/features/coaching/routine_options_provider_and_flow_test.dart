import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_options_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_options.dart';
import 'package:oncare_trainer/features/coaching/presentation/pages/ai_routine_options_flow.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
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
  @override
  Future<void> assignProgram(
    String memberId,
    Map<String, Object?> payload,
  ) async {}

  @override
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  }) async {}

  @override
  Future<void> deleteRoutine(String memberId, String routineId) async {}

  AssignedRoutine? assigned;
  String? memberId;
  String? lastClientRequestId;

  @override
  Future<void> assignRoutine(
    String memberId,
    AssignedRoutine routine, {
    String? clientRequestId,
  }) async {
    this.memberId = memberId;
    assigned = routine;
    lastClientRequestId = clientRequestId;
  }

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) =>
      Stream<List<AssignedRoutine>>.value(const <AssignedRoutine>[]);
}

/// Always throws [error] from `assignRoutine`, to exercise the send
/// button's failure-message branching (network vs. other).
class _ThrowingRoutineRepository implements TrainerRoutineRepository {
  @override
  Future<void> assignProgram(
    String memberId,
    Map<String, Object?> payload,
  ) async {}

  @override
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  }) async {}

  @override
  Future<void> deleteRoutine(String memberId, String routineId) async {}

  _ThrowingRoutineRepository(this.error);

  final Object error;

  /// 시도마다 넘어온 멱등키 — 재시도가 같은 키인지 확인한다(#581).
  final List<String?> attempts = <String?>[];

  @override
  Future<void> assignRoutine(
    String memberId,
    AssignedRoutine routine, {
    String? clientRequestId,
  }) async {
    attempts.add(clientRequestId);
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
  group('생성 실패 문구 분기', _rateLimitMessageTests);

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
      const repo = MockTrainerRoutineOptionsRepository();
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

    test('mock generator respects the requested time at both limits', () async {
      const repo = MockTrainerRoutineOptionsRepository();

      // 5 는 RoutineMinutesSlider 의 실제 최소값이다 — 예전엔 A안 하한이 10 이라
      // `clamp(10, 5)`로 죽었다.
      for (final minutes in <int>[5, 10, 180]) {
        final options = await repo.generate(
          'm1',
          availableMinutes: minutes,
          intensityPreference: 'low',
          trainerNote: '',
        );
        expect(options.planA.totalMinutes, lessThanOrEqualTo(minutes));
        expect(options.planB.totalMinutes, minutes);
        expect(
          options.planB.exercises.fold<int>(
            0,
            (sum, exercise) => sum + exercise.minutes,
          ),
          minutes,
        );
      }
    });

    test(
      '#776 — demo member has no real history, so the mock reports '
      'template (never claims to be personalized)',
      () async {
        const repo = MockTrainerRoutineOptionsRepository();
        final options = await repo.generate(
          'm1',
          availableMinutes: 40,
          intensityPreference: 'moderate',
          trainerNote: '',
        );
        expect(
          options.analysis.recommendationStatus,
          RecommendationStatus.template,
        );
        expect(options.analysis.frequentExercises, isEmpty);
      },
    );

    test(
      '#776 — null conditions fall back to the same default as the backend '
      '(30 minutes / moderate)',
      () async {
        const repo = MockTrainerRoutineOptionsRepository();
        final options = await repo.generate(
          'm1',
          availableMinutes: null,
          intensityPreference: null,
          trainerNote: '',
        );
        expect(options.planB.totalMinutes, 30);
      },
    );
  });

  group('#776 recommendation status', () {
    testWidgets(
      'first generation sends no explicit conditions, and the personalized '
      'banner + pattern-based labels show once the server responds',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _CapturingOptionsRepository(_personalizedOptions());
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              appConfigProvider.overrideWithValue(_mockConfig),
              trainerRoutineOptionsRepositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(
              locale: Locale('ko'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AiRoutineOptionsFlow(client: _client),
            ),
          ),
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('generate-routine-options')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // 트레이너가 조건을 건드리지 않았으니 서버가 알아서 채우도록 둘 다
        // 비워 보낸다 — 슬라이더 기본값(30/moderate)을 그대로 보냈다면
        // 서버의 자동 설정 분기가 아예 실행되지 않는다.
        expect(repo.lastAvailableMinutes, isNull);
        expect(repo.lastIntensityPreference, isNull);

        // 개인화 분석 배너와, 반복 패턴 기반 A/B 라벨이 그대로 보인다.
        expect(find.text('최근 패턴 분석 완료'), findsOneWidget);
        expect(find.textContaining('스쿼트'), findsWidgets);
        expect(find.textContaining('기존 패턴 유지형'), findsOneWidget);
        expect(find.textContaining('점진적 강화형'), findsOneWidget);

        // 서버가 실제로 쓴 조건(45분/높음)이 화면에도 반영돼, 되돌아가면
        // 그 값에서 바로 수정할 수 있다.
        await tester.tap(find.byKey(const ValueKey<String>('routine-stage-0')));
        await tester.pumpAndSettle();
        expect(find.text('45분'), findsWidgets);
        final highIntensityLabel = tester.widget<Text>(find.text('높음'));
        expect(highIntensityLabel.style?.color, AppColors.accent);
      },
    );

    testWidgets(
      'once the trainer edits a condition, that explicit value is sent '
      'instead of letting the server auto-fill',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _CapturingOptionsRepository(_personalizedOptions());
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              appConfigProvider.overrideWithValue(_mockConfig),
              trainerRoutineOptionsRepositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(
              locale: Locale('ko'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AiRoutineOptionsFlow(client: _client),
            ),
          ),
        );

        final minutesSlider = find.descendant(
          of: find.byKey(const ValueKey<String>('generation-minutes')),
          matching: find.byType(Slider),
        );
        tester.widget<Slider>(minutesSlider).onChanged?.call(60);
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey<String>('generate-routine-options')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        expect(repo.lastAvailableMinutes, 60);
        // 시간만 건드렸다 — 강도는 여전히 서버가 이력에서 계산하도록 비워
        // 보낸다. 한쪽을 고쳤다고 다른 쪽까지 트레이너 입력값으로 굳으면 안
        // 된다.
        expect(repo.lastIntensityPreference, isNull);
      },
    );

    testWidgets(
      'touching only intensity leaves minutes for the server to derive',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _CapturingOptionsRepository(_personalizedOptions());
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              appConfigProvider.overrideWithValue(_mockConfig),
              trainerRoutineOptionsRepositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(
              locale: Locale('ko'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AiRoutineOptionsFlow(client: _client),
            ),
          ),
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('routine-intensity-high')),
        );
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey<String>('generate-routine-options')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // 강도만 건드렸다 — 시간은 여전히 서버가 이력에서 계산하도록 비워
        // 보낸다.
        expect(repo.lastAvailableMinutes, isNull);
        expect(repo.lastIntensityPreference, 'high');
      },
    );
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
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiRoutineOptionsFlow(
            client: _client,
            recommendedExercises: const <RoutineExercise>[
              RoutineExercise(name: '실내 자전거', minutes: 20, type: '유산소'),
            ],
            recommendedReason: '기존 고객 데이터 기반 추천',
            onReviewCompleted: (exercises) => reviewed = exercises,
          ),
        ),
      ),
    );

    // The assistant analysis is editable, while its suggestion remains a
    // muted placeholder until the trainer types a memo.
    expect(find.text('고객 데이터를 분석했어요'), findsOneWidget);
    final initialMemo = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('analysis-trainer-memo')),
    );
    expect(initialMemo.decoration?.hintStyle?.color, AppColors.mutedForeground);
    final generationMinutes = find.byKey(
      const ValueKey<String>('generation-minutes'),
    );
    expect(
      find.descendant(of: generationMinutes, matching: find.text('총 운동시간')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: generationMinutes, matching: find.text('운동 시간')),
      findsNothing,
    );
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

    // A/B + the existing recommendation are shown together. The layout
    // adapts — side by side when the column is wide enough, a scrolling
    // rail when it isn't — so this asserts the three options themselves
    // rather than which of the two containers rendered them.
    expect(find.textContaining('회복안 · 회복·지속 중심'), findsOneWidget);
    expect(find.textContaining('강화안 · 강도·운동량 중심'), findsOneWidget);
    expect(find.textContaining('기존안 · 기존 AI 추천'), findsOneWidget);
    // 세 번째 후보의 key 는 선택 식별자다 — 화면 문구가 아니라서 로케일과
    // 무관하게 'recommended' 로 고정돼 있다(#501).
    final optionHeights = <String>['A', 'B', 'recommended']
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
    final categoryNameGap = tester.widget<SizedBox>(
      find.byKey(const ValueKey<String>('routine-category-name-gap-0')),
    );
    expect(categoryNameGap.height, AppSpacing.md);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('routine-minutes-0')),
        matching: find.text('운동 시간'),
      ),
      findsOneWidget,
    );

    final showAddExerciseForm = find.byKey(
      const ValueKey<String>('show-add-exercise-form'),
    );
    await tester.ensureVisible(showAddExerciseForm);
    await tester.tap(showAddExerciseForm);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('new-exercise-minutes')),
        matching: find.text('운동 시간'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('hide-add-exercise-form')),
    );
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
    '네트워크 실패도 재시도를 안내하고, 재시도는 같은 멱등키를 다시 보낸다 (#581)',
    (tester) async {
      // 서버가 (trainer_id, member_id, client_request_id) 로 중복 배정을 막으므로
      // 애매한 실패(서버는 커밋했는데 응답만 유실) 뒤에도 안전하게 다시 보낼 수
      // 있다. 예전에는 "먼저 확인하라"고 안내할 수밖에 없었다.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _ThrowingRoutineRepository(const NetworkError());
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_mockConfig),
            trainerRoutineRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
            home: AiRoutineOptionsFlow(
              client: _client,
              recommendedExercises: <RoutineExercise>[
                RoutineExercise(name: '실내 자전거', minutes: 20, type: '유산소'),
              ],
              recommendedReason: '기존 고객 데이터 기반 추천',
            ),
          ),
        ),
      );

      await _driveToSendReady(tester);
      final sendButton = find.byKey(
        const ValueKey<String>('send-selected-routine'),
      );
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsOneWidget);

      // 트레이너가 다시 누른다 — 같은 키가 나가야 중복 배정이 안 생긴다.
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(repository.attempts, hasLength(2));
      expect(repository.attempts.first, isNotNull);
      expect(
        repository.attempts.first,
        repository.attempts.last,
        reason: '재시도가 새 키를 만들면 서버가 중복을 막을 수 없다',
      );
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
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiRoutineOptionsFlow(
            client: _client,
            recommendedExercises: <RoutineExercise>[
              RoutineExercise(name: '실내 자전거', minutes: 20, type: '유산소'),
            ],
            recommendedReason: '기존 고객 데이터 기반 추천',
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

/// Records what conditions the flow actually sent, and returns a fixed
/// [RoutineOptions] regardless — used to check the "leave it blank, let the
/// server decide" contract (#776) without a real backend.
class _CapturingOptionsRepository implements TrainerRoutineOptionsRepository {
  _CapturingOptionsRepository(this._response);

  final RoutineOptions _response;
  int? lastAvailableMinutes;
  String? lastIntensityPreference;

  @override
  Future<RoutineOptions> generate(
    String memberId, {
    required int? availableMinutes,
    required String? intensityPreference,
    required String trainerNote,
  }) async {
    lastAvailableMinutes = availableMinutes;
    lastIntensityPreference = intensityPreference;
    return _response;
  }
}

/// A settled-history response: repeated squats over several weeks, so the
/// candidates read as "keep the pattern" / "grow it a little" (#776).
RoutineOptions _personalizedOptions() {
  const analysis = MemberAnalysis(
    goal: '체중 감량',
    sodiumTodayMg: 1800,
    sodiumOverTarget: false,
    avgCompletionRate: 70,
    latestRoutine: '스쿼트',
    note: '',
    recommendationStatus: RecommendationStatus.personalized,
    historySessionCount: 6,
    analysisPeriodDays: 42,
    frequentExercises: <String>['스쿼트'],
    suggestedAvailableMinutes: 45,
    suggestedIntensity: 'high',
  );
  const planA = RoutinePlan(
    key: 'A',
    label: '기존 패턴 유지형',
    totalMinutes: 45,
    intensity: '높음',
    exercises: <RoutineExercise>[
      RoutineExercise(name: '스쿼트', minutes: 45, type: '근력'),
    ],
    reason: '최근 자주 수행한 운동을 그대로 유지',
    rationale: '최근 기록에서 반복 확인된 운동(스쿼트)을 유지',
  );
  const planB = RoutinePlan(
    key: 'B',
    label: '점진적 강화형',
    totalMinutes: 45,
    intensity: '높음',
    exercises: <RoutineExercise>[
      RoutineExercise(name: '스쿼트', minutes: 30, type: '근력'),
      RoutineExercise(name: '인터벌 러닝', minutes: 15, type: '유산소'),
    ],
    reason: '기존 핵심 운동을 유지하며 운동량을 소폭 확대',
    rationale: '기존 핵심 운동(스쿼트)은 유지하고 인터벌 러닝을 더함',
  );
  return const RoutineOptions(
    analysis: analysis,
    planA: planA,
    planB: planB,
    generatedBy: 'rule',
  );
}

/// Always throws [error] from `generate`, to exercise the generate button's
/// failure-message branching (한도 초과 vs. 그 외).
class _ThrowingOptionsRepository implements TrainerRoutineOptionsRepository {
  _ThrowingOptionsRepository(this.error);

  final Object error;

  @override
  Future<RoutineOptions> generate(
    String memberId, {
    required int? availableMinutes,
    required String? intensityPreference,
    required String trainerNote,
  }) async {
    throw error;
  }
}

Future<void> _pumpFlowWithOptionsError(WidgetTester tester, Object error) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(_mockConfig),
        trainerRoutineOptionsRepositoryProvider.overrideWithValue(
          _ThrowingOptionsRepository(error),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiRoutineOptionsFlow(
          client: _client,
          recommendedExercises: <RoutineExercise>[
            RoutineExercise(name: '실내 자전거', minutes: 20, type: '유산소'),
          ],
          recommendedReason: '기존 고객 데이터 기반 추천',
        ),
      ),
    ),
  );

  await tester.ensureVisible(
    find.byKey(const ValueKey<String>('generate-routine-options')),
  );
  await tester.tap(
    find.byKey(const ValueKey<String>('generate-routine-options')),
  );
  await tester.pumpAndSettle();
}

void _rateLimitMessageTests() {
  testWidgets('한도 초과(429)는 고장이 아니라 기다리라고 안내한다 (#582)', (tester) async {
    // 429 를 다른 오류와 뭉뚱그리면 트레이너가 기능이 깨진 것으로 읽는다.
    await _pumpFlowWithOptionsError(tester, const RateLimitedError());

    expect(find.text('AI 생성을 너무 자주 요청했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
    expect(find.text('AI 생성에 실패했어요. 잠시 후 다시 시도해 주세요'), findsNothing);
  });

  testWidgets('그 밖의 실패는 기존 문구를 그대로 쓴다 (#582)', (tester) async {
    await _pumpFlowWithOptionsError(tester, const ServerError(statusCode: 500));

    expect(find.text('AI 생성에 실패했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
    expect(find.text('AI 생성을 너무 자주 요청했어요. 잠시 후 다시 시도해 주세요'), findsNothing);
  });
}
