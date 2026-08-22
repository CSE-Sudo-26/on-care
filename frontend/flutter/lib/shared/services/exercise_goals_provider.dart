import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_load.dart';

/// MY 건강 목표에서 저장한 **운동 탭 기준** 목표 (#1139).
///
/// 운동 탭·홈 운동 카드가 견주는 축은 하루 소모 칼로리와 유형별 주간 목표다.
/// 예전에는 이 값이 코드 상수([kDefaultExerciseLoadGoals])라 MY 에서 아무리
/// 목표를 고쳐도 그래프의 기준선은 꿈쩍하지 않았다 — 같은 회원의 목표를 두
/// 화면이 서로 다른 축으로 말하고 있었다.
///
/// 저장된 값이 없으면 권장값(= 상수)이 그대로 기준이 된다. 하루 몫은 유형별
/// 주간 목표를 그 유형의 주당 횟수로 나눈 값이라 상수와 같은 규칙을 쓴다.
final exerciseLoadGoalsProvider = Provider.autoDispose<ExerciseLoadGoals>((
  ref,
) {
  final UserProfile? p = ref.watch(profileProvider).valueOrNull;
  if (p == null) return kDefaultExerciseLoadGoals;
  return ExerciseLoadGoals(
    dailyBurnKcal:
        (p.dailyBurnKcal ?? kDefaultExerciseLoadGoals.dailyBurnKcal.round())
            .toDouble(),
    weeklyCardioMinutes:
        (p.weeklyCardioMinutes ??
                kDefaultExerciseLoadGoals.weeklyCardioMinutes.round())
            .toDouble(),
    weeklyStrengthSets:
        (p.weeklyStrengthSets ??
                kDefaultExerciseLoadGoals.weeklyStrengthSets.round())
            .toDouble(),
    weeklyFlexibilityMinutes:
        (p.weeklyFlexibilityMinutes ??
                kDefaultExerciseLoadGoals.weeklyFlexibilityMinutes.round())
            .toDouble(),
  );
}, name: 'exerciseLoadGoals');
