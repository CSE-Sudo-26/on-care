import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/core/storage/app_database.dart';
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/pages/exercise_page.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/repositories/member_coach_repository.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/my_health/presentation/widgets/my_flows.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

class _GoalSyncHost extends StatefulWidget {
  const _GoalSyncHost();

  @override
  State<_GoalSyncHost> createState() => _GoalSyncHostState();
}

class _GoalSyncHostState extends State<_GoalSyncHost> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[DashboardContent(), ExercisePage()],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FilledButton(
            key: const Key('openGoals'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const HealthGoalsPage()),
            ),
            child: const Text('목표 수정'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('showExercise'),
            onPressed: () => setState(() => _index = 1),
            child: const Text('운동 탭'),
          ),
        ],
      ),
    );
  }
}

class _SessionMemberCoachRepository implements MemberCoachRepository {
  const _SessionMemberCoachRepository(this.sessions, {this.coach});

  final List<CoachSession> sessions;
  final MemberCoach? coach;

  @override
  Future<MemberCoach?> fetchCoach() async => coach;
  @override
  Future<List<CoachRoutine>> fetchRoutines() async => const <CoachRoutine>[];
  @override
  Future<CoachRoutine> completeRoutine(
    String routineId, {
    required int minutes,
    String intensity = 'moderate',
    String memberNote = '',
  }) async => throw UnsupportedError('not used');
  @override
  Future<List<CoachSession>> fetchSessions() async => sessions;
  @override
  Future<List<CoachMessage>> fetchChat() async => const <CoachMessage>[];
  @override
  Stream<List<CoachMessage>> watchChat() =>
      const Stream<List<CoachMessage>>.empty();
  @override
  Future<void> sendMessage(String text) async {}
  @override
  Future<void> markRead() async {}
  @override
  Future<int> unreadCount() async => 0;
}

void main() {
  const ExerciseWeek week = ExerciseWeek(
    sessions: <ExerciseSession>[],
    dailyMinutes: <double>[50, 0, 50, 0, 0, 0, 0],
    dailyCalories: <double>[150, 0, 150, 0, 0, 0, 0],
    dayLabels: <String>['월', '화', '수', '목', '금', '토', '일'],
    totalMinutes: 100,
    totalCalories: 300,
    streakDays: 1,
    aiCoachMessage: '꾸준히 운동해 보세요.',
  );
  const DashboardSummary dashboardSummary = DashboardSummary(
    indicators: <HealthIndicator>[],
    macros: DietMacros.zero(),
    dietEntries: 0,
    exerciseMinutes: 100,
    exerciseCalories: 300,
    exerciseCount: 2,
    todaySchedule: <ScheduleItem>[],
    weekScore: 0,
    weekScoreDelta: 0,
    sodiumWarning: null,
  );

  Future<void> pumpExercise(
    WidgetTester tester, {
    required UserProfile profile,
    MemberCoachRepository? coachRepository,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: Environment.dev,
              apiBaseUrl: 'https://example.test',
              useMockApi: coachRepository == null,
            ),
          ),
          accountRepositoryProvider.overrideWithValue(
            MockAccountRepository(profile: profile),
          ),
          exerciseWeekProvider.overrideWith((ref) async => week),
          memberCoachRepositoryProvider.overrideWithValue(
            coachRepository ?? MockMemberCoachRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExercisePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('운동 탭 요약은 일수 카드를 제외한 운동 목표를 표시한다', (
    WidgetTester tester,
  ) async {
    await pumpExercise(
      tester,
      profile: const UserProfile(
        id: 'member',
        name: '테스트',
        email: 'member@example.com',
        weeklyWorkoutGoal: 5,
        weeklyExerciseMinutesGoal: 240,
        weeklyBurnGoal: 900,
      ),
    );

    expect(find.text('일수'), findsNothing);
    expect(find.text('2 /5일'), findsNothing);
    expect(find.text('100 /240분'), findsOneWidget);
    expect(find.text('300 /900kcal'), findsOneWidget);
    expect(find.text('연속'), findsOneWidget);
  });

  testWidgets('운동 목표가 없으면 필드별 기본값을 표시한다', (WidgetTester tester) async {
    await pumpExercise(
      tester,
      profile: const UserProfile(
        id: 'member',
        name: '테스트',
        email: 'member@example.com',
        weeklyWorkoutGoal: 4,
        weeklyBurnGoal: 800,
      ),
    );

    expect(find.text('2 /4일'), findsNothing);
    expect(find.text('100 /150분'), findsOneWidget);
    expect(find.text('300 /800kcal'), findsOneWidget);
  });

  testWidgets('트레이너가 완료한 PT 프로그램과 피드백을 표시한다', (WidgetTester tester) async {
    await pumpExercise(
      tester,
      profile: const UserProfile(
        id: 'member',
        name: '테스트',
        email: 'member@example.com',
      ),
      coachRepository: _SessionMemberCoachRepository(
        <CoachSession>[
          CoachSession(
            id: 'completed-pt',
            date: nowKst(),
            time: '18:00',
            type: '1:1 PT',
            durationMinutes: 50,
            status: '완료',
            note: '오른쪽 어깨 가동 범위를 확인해 주세요.',
            program: const <CoachProgramItem>[
              CoachProgramItem(
                name: '숄더 프레스',
                sets: 4,
                reps: '12회',
                weight: '10kg',
              ),
            ],
          ),
        ],
        coach: const MemberCoach(
          trainerId: 'trainer-1',
          name: '김트레이너',
          specialty: '근력 운동',
          career: '5년',
          intro: '',
          gymName: '온케어짐',
          goal: '근력 향상',
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('completedPtSessionCard')),
      400,
    );

    expect(find.text('18:00 수업 완료'), findsOneWidget);
    expect(find.text('숄더 프레스 · 10kg · 4세트 · 12회'), findsOneWidget);
    expect(find.text('김트레이너 · 오늘의 피드백'), findsOneWidget);
    expect(find.text('오른쪽 어깨 가동 범위를 확인해 주세요.'), findsOneWidget);
  });

  testWidgets('MY에서 저장한 운동 목표가 열려 있던 홈·운동 탭에 반영된다', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: Environment.dev,
              apiBaseUrl: 'https://example.test',
              useMockApi: true,
            ),
          ),
          appLoggerProvider.overrideWithValue(Logger(level: Level.off)),
          appDatabaseProvider.overrideWithValue(database),
          dashboardSummaryProvider.overrideWith(
            (ref) async => dashboardSummary,
          ),
          exerciseWeekProvider.overrideWith((ref) async => week),
          memberCoachRepositoryProvider.overrideWithValue(
            MockMemberCoachRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _GoalSyncHost(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(' /3일'), findsOneWidget);
    expect(find.text(' /150분'), findsOneWidget);
    expect(find.text(' /500kcal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('openGoals')));
    await tester.pumpAndSettle();
    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(6), '5');
    await tester.enterText(fields.at(7), '240');
    await tester.enterText(fields.at(8), '900');
    final Finder save = find.text('저장');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.byType(HealthGoalsPage), findsNothing);
    expect(find.text(' /5일'), findsOneWidget);
    expect(find.text(' /240분'), findsOneWidget);
    expect(find.text(' /900kcal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('showExercise')));
    await tester.pumpAndSettle();
    expect(find.text('2 /5일'), findsNothing);
    expect(find.text('100 /240분'), findsOneWidget);
    expect(find.text('300 /900kcal'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
