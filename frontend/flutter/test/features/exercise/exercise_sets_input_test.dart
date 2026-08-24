/// 근력은 세트로 묻고 세트로 저장한다 (#1262).
///
/// 화면 여러 곳(홈 운동 카드·운동 현황 링·주간 목표)이 근력을 이미 세트로 읽는데
/// `운동 추가` 시트만 분으로 물어, 회원이 적지 않은 수(분 ÷ 3)가 화면에 떴다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/exercise_flows.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 저장 요청을 그대로 받아 두는 대역. 무엇이 실려 갔는지만 본다.
class _CapturingRepository implements ExerciseRepository {
  ExerciseType? type;
  int? minutes;
  int? sets;
  String? updatedId;

  @override
  Future<ExerciseWeek> fetchThisWeek() async => _emptyWeek;

  @override
  Future<ExerciseWeek> fetchWeek(DateTime weekStart) async => _emptyWeek;

  @override
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
    int? sets,
  }) async {
    this.type = type;
    this.minutes = minutes;
    this.sets = sets;
    return ExerciseSession(
      id: 'new',
      dayLabel: dayLabel,
      type: type,
      minutes: minutes,
      calories: calories,
      sets: sets,
    );
  }

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<ExerciseSession> updateSession({
    required String id,
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
    int? sets,
  }) async {
    updatedId = id;
    this.type = type;
    this.minutes = minutes;
    this.sets = sets;
    return ExerciseSession(
      id: id,
      dayLabel: dayLabel,
      type: type,
      minutes: minutes,
      calories: calories,
      sets: sets,
    );
  }
}

const ExerciseWeek _emptyWeek = ExerciseWeek(
  sessions: <ExerciseSession>[],
  dailyMinutes: <double>[0, 0, 0, 0, 0, 0, 0],
  dailyCalories: <double>[0, 0, 0, 0, 0, 0, 0],
  cardioMinutes: <double>[0, 0, 0, 0, 0, 0, 0],
  strengthMinutes: <double>[0, 0, 0, 0, 0, 0, 0],
  stretchingMinutes: <double>[0, 0, 0, 0, 0, 0, 0],
  dayLabels: <String>['월', '화', '수', '목', '금', '토', '일'],
  totalMinutes: 0,
  totalCalories: 0,
  streakDays: 0,
  aiCoachMessage: '',
);

/// 시트를 연 화면. [session] 을 주면 수정 모드로 열린다.
Future<void> _openSheet(
  WidgetTester tester,
  _CapturingRepository repo, {
  ExerciseSession? session,
}) async {
  tester.view.physicalSize = const Size(500, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        exerciseRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () =>
                  showExerciseAddSheet(context, session: session),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('근력을 고르면 시간 대신 세트로 묻는다', (WidgetTester tester) async {
    final _CapturingRepository repo = _CapturingRepository();
    await _openSheet(tester, repo);

    // 기본값은 유산소 — 분으로 묻는다.
    expect(find.text('운동 시간'), findsOneWidget);
    expect(find.text('세트 수'), findsNothing);
    expect(find.byKey(const Key('exerciseMinutesSlider')), findsOneWidget);

    await tester.tap(find.text('근력'));
    await tester.pumpAndSettle();

    expect(find.text('세트 수'), findsOneWidget);
    expect(find.text('운동 시간'), findsNothing);
    expect(find.text('12세트'), findsOneWidget);
    expect(find.byKey(const Key('exerciseSetsSlider')), findsOneWidget);
    expect(find.byKey(const Key('exerciseMinutesSlider')), findsNothing);
  });

  testWidgets('근력 기록은 세트를 실어 저장한다', (WidgetTester tester) async {
    final _CapturingRepository repo = _CapturingRepository();
    await _openSheet(tester, repo);

    await tester.tap(find.text('근력'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.type, ExerciseType.strength);
    expect(repo.sets, 12);
    // 서버는 분(>0)도 받는다 — 세트당 벽시계 3분으로 환산한 값이다.
    expect(repo.minutes, 36);
  });

  testWidgets('근력이 아닌 기록에는 세트가 실리지 않는다', (WidgetTester tester) async {
    final _CapturingRepository repo = _CapturingRepository();
    await _openSheet(tester, repo);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.type, ExerciseType.cardio);
    expect(repo.sets, isNull);
    expect(repo.minutes, 30);
  });

  testWidgets('수정 시트는 저장된 세트로 열린다', (WidgetTester tester) async {
    final _CapturingRepository repo = _CapturingRepository();
    await _openSheet(
      tester,
      repo,
      session: const ExerciseSession(
        id: 'ex-1',
        dayLabel: '월',
        type: ExerciseType.strength,
        minutes: 45,
        calories: 270,
        sets: 15,
      ),
    );

    expect(find.text('세트 수'), findsOneWidget);
    expect(find.text('15세트'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.updatedId, 'ex-1');
    expect(repo.sets, 15);
  });

  testWidgets('세트를 모르는 옛 근력 기록은 분에서 환산해 연다', (WidgetTester tester) async {
    final _CapturingRepository repo = _CapturingRepository();
    await _openSheet(
      tester,
      repo,
      session: const ExerciseSession(
        id: 'ex-old',
        dayLabel: '월',
        type: ExerciseType.strength,
        minutes: 30,
        calories: 180,
      ),
    );

    expect(find.text('10세트'), findsOneWidget); // 30분 ÷ 3분
  });

  testWidgets('근력이던 기록을 유산소로 고치면 세트가 지워진다', (WidgetTester tester) async {
    final _CapturingRepository repo = _CapturingRepository();
    await _openSheet(
      tester,
      repo,
      session: const ExerciseSession(
        id: 'ex-2',
        dayLabel: '월',
        type: ExerciseType.strength,
        minutes: 36,
        calories: 216,
        sets: 12,
      ),
    );

    await tester.tap(find.text('유산소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.type, ExerciseType.cardio);
    expect(repo.sets, isNull);
  });
}
