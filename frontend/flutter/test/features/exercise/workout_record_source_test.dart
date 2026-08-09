/// 트레이너가 완료 처리한 PT 기록의 화면 규칙. (#499)
///
/// 서버가 파생시킨 기록은 회원이 고칠 수 없고(PUT/DELETE 409), 화면은 그 규칙을
/// 앞당겨 보여준다 — 배지를 붙이고 편집·스와이프 삭제를 감춘다. 눌러도 실패로
/// 끝나는 동작을 열어 두면 회원은 자기 앱이 고장 난 것으로 읽는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/workout_record_tab.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/swipe_to_delete.dart';

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

ExerciseWeek _weekWith(List<ExerciseSession> sessions) => ExerciseWeek(
  sessions: sessions,
  dailyMinutes: const <double>[60, 0, 0, 0, 0, 0, 0],
  dayLabels: const <String>['월', '화', '수', '목', '금', '토', '일'],
  totalMinutes: 60,
  totalCalories: 360,
  streakDays: 1,
  aiCoachMessage: '이번 주도 좋아요',
);

const ExerciseSession _memberLog = ExerciseSession(
  id: 'ex-own',
  dayLabel: '월',
  type: ExerciseType.cardio,
  minutes: 30,
  calories: 270,
);

const ExerciseSession _trainerLog = ExerciseSession(
  id: 'sched-ex-1',
  dayLabel: '월',
  type: ExerciseType.strength,
  minutes: 60,
  calories: 360,
  source: ExerciseSource.trainerPt,
);

Future<void> _pump(WidgetTester tester, List<ExerciseSession> sessions) async {
  // 세션 카드는 차트·통계 아래에 쌓인다. 기본 테스트 창(600dp)에서는 두 번째
  // 카드가 뷰포트 밖이라 아예 빌드되지 않아, "없다" 와 "안 보인다" 가 구분되지
  // 않는다. 목록 전체가 한 화면에 들어오도록 창을 키운다.
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(_config),
        exerciseWeekProvider.overrideWith((ref) async => _weekWith(sessions)),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: WorkoutRecordTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('PT 파생 기록은 배지를 달고 스와이프 삭제를 열지 않는다', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const <ExerciseSession>[_trainerLog]);

    expect(find.text('트레이너 PT'), findsOneWidget);
    expect(find.byType(SwipeToDelete), findsNothing);
  });

  testWidgets('회원이 남긴 기록은 배지 없이 삭제·편집이 열린다', (WidgetTester tester) async {
    await _pump(tester, const <ExerciseSession>[_memberLog]);

    expect(find.text('트레이너 PT'), findsNothing);
    expect(find.byType(SwipeToDelete), findsOneWidget);
  });

  testWidgets('둘이 섞여 있어도 회원 기록만 편집 가능하다', (WidgetTester tester) async {
    await _pump(tester, const <ExerciseSession>[_trainerLog, _memberLog]);

    // 배지는 파생 기록 하나에만, 스와이프 삭제는 회원 기록 하나에만 붙는다.
    expect(find.text('트레이너 PT'), findsOneWidget);
    expect(find.byType(SwipeToDelete), findsOneWidget);
  });
}
