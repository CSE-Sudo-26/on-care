import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/domain/entities/goal_update.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/shared/services/exercise_burn_goal_provider.dart';

class _TestProfileController extends ProfileController {
  _TestProfileController(this._load);

  final Future<UserProfile> Function() _load;

  @override
  Future<UserProfile> build() => _load();
}

void main() {
  UserProfile profile({int? workouts, int? minutes, int? burnCalories}) =>
      UserProfile(
        id: 'member',
        name: '테스트',
        email: 'member@example.com',
        weeklyWorkoutGoal: workouts,
        weeklyExerciseMinutesGoal: minutes,
        weeklyBurnGoal: burnCalories,
      );

  ProviderContainer containerWith(Future<UserProfile> Function() load) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        profileProvider.overrideWith(() => _TestProfileController(load)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('프로필의 운동 목표 3종을 함께 노출한다', () async {
    final ProviderContainer container = containerWith(
      () async => profile(workouts: 5, minutes: 240, burnCalories: 900),
    );
    await container.read(profileProvider.future);

    expect(container.read(exerciseGoalsProvider), (
      workouts: 5,
      minutes: 240,
      burnCalories: 900,
    ));
    expect(container.read(exerciseBurnGoalProvider), 900);
  });

  test('null 필드는 각각 기본값으로 폴백한다', () async {
    final ProviderContainer container = containerWith(
      () async => profile(workouts: 4, burnCalories: 800),
    );
    await container.read(profileProvider.future);

    expect(container.read(exerciseGoalsProvider), (
      workouts: 4,
      minutes: UserProfile.defaultWeeklyExerciseMinutesGoal,
      burnCalories: 800,
    ));
  });

  test('프로필 로딩 중에는 세 기본값으로 버틴다', () {
    final ProviderContainer container = containerWith(
      () => Completer<UserProfile>().future,
    );

    expect(container.read(exerciseGoalsProvider), (
      workouts: UserProfile.defaultWeeklyWorkoutGoal,
      minutes: UserProfile.defaultWeeklyExerciseMinutesGoal,
      burnCalories: UserProfile.defaultWeeklyBurnGoal,
    ));
  });

  test('프로필 조회가 실패해도 세 기본값으로 버틴다', () async {
    final ProviderContainer container = containerWith(
      () => Future<UserProfile>.error(StateError('boom')),
    );
    await expectLater(container.read(profileProvider.future), throwsStateError);

    expect(container.read(exerciseGoalsProvider), (
      workouts: UserProfile.defaultWeeklyWorkoutGoal,
      minutes: UserProfile.defaultWeeklyExerciseMinutesGoal,
      burnCalories: UserProfile.defaultWeeklyBurnGoal,
    ));
  });

  test('mock 저장 응답을 반영하면 운동 목표도 즉시 바뀐다', () async {
    final MockAccountRepository repository = MockAccountRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        accountRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileProvider.future);
    expect(container.read(exerciseGoalsProvider), (
      workouts: 3,
      minutes: 150,
      burnCalories: 500,
    ));

    final UserProfile updatedProfile = await repository.updateHealthGoals(
      weeklyWorkoutGoal: const GoalUpdate(5),
      weeklyExerciseMinutesGoal: const GoalUpdate(240),
      weeklyBurnGoal: const GoalUpdate(900),
    );
    container
        .read(profileProvider.notifier)
        .applyUpdatedProfile(updatedProfile);

    expect(container.read(exerciseGoalsProvider), (
      workouts: 5,
      minutes: 240,
      burnCalories: 900,
    ));
  });
}
