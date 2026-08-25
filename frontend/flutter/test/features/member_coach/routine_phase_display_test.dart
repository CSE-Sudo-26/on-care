/// 배정 루틴이 단계별로 보인다. (#934)
///
/// 몸을 풀고 → 본 운동 → 정리하는 차례가 데이터에도 화면에도 없었다. 단계가
/// 둘 이상인 루틴만 머리글로 묶는다 — 단계 칸이 없던 옛 루틴은 예전 그대로
/// 읽혀야 한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/member_coach/data/dtos/member_coach_dtos.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/entities/routine_phase.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_card.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

const CoachRoutine _staged = CoachRoutine(
  id: 'staged',
  name: '하체 프로그램',
  minutes: 40,
  type: '근력',
  reason: '하체 강화',
  source: 'trainer',
  exercises: <CoachRoutineExercise>[
    CoachRoutineExercise(
      name: '가벼운 걷기',
      duration: '5',
      phase: kRoutinePhaseWarmup,
    ),
    CoachRoutineExercise(name: '스쿼트', sets: '4', reps: '12'),
    CoachRoutineExercise(
      name: '하체 스트레칭',
      duration: '5',
      phase: kRoutinePhaseCooldown,
    ),
  ],
);

/// 단계 칸이 없던 옛 루틴 — 전부 본운동으로 읽힌다.
const CoachRoutine _legacy = CoachRoutine(
  id: 'legacy',
  name: '코어 루틴',
  minutes: 20,
  type: '근력',
  reason: '코어 강화',
  source: 'trainer',
  exercises: <CoachRoutineExercise>[
    CoachRoutineExercise(name: '플랭크', duration: '10'),
    CoachRoutineExercise(name: '버드독', duration: '10'),
  ],
);

Future<void> _pump(WidgetTester tester, List<CoachRoutine> routines) async {
  await tester.binding.setSurfaceSize(const Size(600, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        memberCoachRepositoryProvider.overrideWithValue(
          MockMemberCoachRepository(),
        ),
        coachRoutinesProvider.overrideWith((ref) async => routines),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AiCoachingCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('단계 칸이 없는 응답은 본운동으로 읽는다', () {
    final CoachRoutine routine = coachRoutineFromJson(<String, Object?>{
      'id': 'r-1',
      'name': '코어',
      'minutes': 20,
      'type': '근력',
      'reason': '',
      'source': 'trainer',
      'exercises': <Object?>[
        <String, Object?>{'name': '플랭크'},
        <String, Object?>{'name': '걷기', 'phase': 'warmup'},
        <String, Object?>{'name': '스트레칭', 'phase': '알 수 없는 값'},
      ],
    });

    expect(routine.exercises[0].phase, kRoutinePhaseMain);
    expect(routine.exercises[1].phase, kRoutinePhaseWarmup);
    // 모르는 값도 본운동이다 — 없는 단계를 지어내지 않는다.
    expect(routine.exercises[2].phase, kRoutinePhaseMain);
  });

  testWidgets('단계가 여럿이면 준비운동 → 본운동 → 마무리 순으로 묶인다', (tester) async {
    await _pump(tester, const <CoachRoutine>[_staged]);

    for (final String phase in kRoutinePhases) {
      expect(
        find.byKey(ValueKey<String>('routine-phase-$phase-staged')),
        findsOneWidget,
        reason: phase,
      );
    }
    // 화면 차례도 몸풀기 → 본 운동 → 정리다.
    final double warmup = tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('routine-phase-warmup-staged')),
        )
        .dy;
    final double main = tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('routine-phase-main-staged')),
        )
        .dy;
    final double cooldown = tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('routine-phase-cooldown-staged')),
        )
        .dy;
    expect(warmup, lessThan(main));
    expect(main, lessThan(cooldown));

    // 운동 줄은 그대로 남는다.
    expect(find.textContaining('스쿼트'), findsWidgets);
  });

  testWidgets('단계가 하나뿐인 옛 루틴은 머리글 없이 예전대로다', (tester) async {
    await _pump(tester, const <CoachRoutine>[_legacy]);

    expect(
      find.byKey(const ValueKey<String>('routine-phase-main-legacy')),
      findsNothing,
    );
    expect(find.textContaining('플랭크'), findsWidgets);
    expect(find.textContaining('버드독'), findsWidgets);
  });
}
