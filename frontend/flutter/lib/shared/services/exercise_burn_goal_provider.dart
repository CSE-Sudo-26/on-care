import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';

typedef ExerciseGoals = ({int workouts, int minutes, int burnCalories});

/// MY에서 저장한 주간 운동 목표. 홈과 운동 탭은 이 값을 함께 읽는다.
/// 프로필이 로딩 중이거나 조회에 실패하면 필드별 기본값을 사용한다.
final exerciseGoalsProvider = Provider.autoDispose<ExerciseGoals>((ref) {
  final UserProfile? profile = ref.watch(profileProvider).valueOrNull;
  return (
    workouts:
        profile?.effectiveWeeklyWorkoutGoal ??
        UserProfile.defaultWeeklyWorkoutGoal,
    minutes:
        profile?.effectiveWeeklyExerciseMinutesGoal ??
        UserProfile.defaultWeeklyExerciseMinutesGoal,
    burnCalories:
        profile?.effectiveWeeklyBurnGoal ?? UserProfile.defaultWeeklyBurnGoal,
  );
}, name: 'exerciseGoals');

/// 기존 소모 칼로리 목표 소비자를 위한 단일 값 provider.
final exerciseBurnGoalProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(exerciseGoalsProvider).burnCalories,
  name: 'exerciseBurnGoal',
);
