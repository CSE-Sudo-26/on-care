import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/dio_trainer_routine_options_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_options.dart';

/// Generates A/B routine options for a member (the AI generation step). The
/// result is *generated*, not assigned — the trainer picks/edits one and
/// sends it via the routine assign repository.
///
/// Two implementations, selected by [trainerRoutineOptionsRepositoryProvider]
/// via [AppConfig.useMockApi]:
///  * [MockTrainerRoutineOptionsRepository] — demo (deterministic A/B);
///  * [DioTrainerRoutineOptionsRepository] — the real FastAPI backend.
abstract interface class TrainerRoutineOptionsRepository {
  Future<RoutineOptions> generate(
    String memberId, {
    required int availableMinutes,
    required String intensityPreference,
    required String trainerNote,
  });
}

/// Deterministic demo generator mirroring the backend rule-based output, so
/// the 3-step flow works with no backend. Uses a fixed member snapshot
/// (over-target sodium, mid adherence) that tells the demo story.
class MockTrainerRoutineOptionsRepository
    implements TrainerRoutineOptionsRepository {
  const MockTrainerRoutineOptionsRepository();

  @override
  Future<RoutineOptions> generate(
    String memberId, {
    required int availableMinutes,
    required String intensityPreference,
    required String trainerNote,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    const sodium = 2100;
    const completion = 55;
    const goal = '혈압 관리 · 체중 감량';
    final note = trainerNote.trim();
    final noteSuffix = note.isEmpty ? '' : ' 트레이너 메모 반영: $note.';

    final totalA = (availableMinutes * 0.7).round().clamp(10, availableMinutes);
    // Keep the demo contract aligned with the backend: neither option may
    // exceed the time the trainer entered. The old lower bound
    // (`totalA + 5`) produced a 15-minute plan for a 10-minute request and
    // even threw when availableMinutes was 180 (lower clamp bound > 180).
    final totalB = availableMinutes;

    return RoutineOptions(
      analysis: MemberAnalysis(
        goal: goal,
        sodiumTodayMg: sodium,
        sodiumOverTarget: true,
        avgCompletionRate: completion,
        latestRoutine: '저강도 유산소 (걷기)',
        note: note,
      ),
      planA: RoutinePlan(
        key: 'A',
        label: '회복·지속 중심',
        totalMinutes: totalA,
        intensity: '낮음',
        exercises: <RoutineExercise>[
          RoutineExercise(
            name: '저강도 걷기',
            minutes: (totalA * 0.6).round().clamp(1, totalA),
            type: '유산소',
          ),
          RoutineExercise(
            name: '코어 스트레칭',
            minutes: (totalA - (totalA * 0.6).round()).clamp(1, totalA),
            type: '스트레칭',
          ),
        ],
        reason: '짧고 지속하기 쉬운 회복 중심 루틴',
        rationale:
            '오늘 나트륨 ${sodium}mg (목표 초과), 최근 운동 완료율 $completion% → '
            '부담이 적은 유산소·스트레칭으로 지속 가능성에 집중.$noteSuffix',
      ),
      planB: RoutinePlan(
        key: 'B',
        label: '강도·운동량 중심',
        totalMinutes: totalB,
        intensity: intensityPreference == 'low' ? '보통' : '높음',
        exercises: <RoutineExercise>[
          RoutineExercise(
            name: '인터벌 러닝',
            minutes: (totalB * 0.5).round().clamp(1, totalB),
            type: '유산소',
          ),
          RoutineExercise(
            name: '스쿼트',
            minutes: (totalB * 0.3).round().clamp(1, totalB),
            type: '근력',
          ),
          RoutineExercise(
            name: '플랭크',
            minutes: (totalB - (totalB * 0.5).round() - (totalB * 0.3).round())
                .clamp(1, totalB),
            type: '근력',
          ),
        ],
        reason: '운동량과 강도를 높인 루틴',
        rationale:
            "목표 '$goal' 기준, 완료율 $completion%로 점진적으로 근력·유산소를 더해 "
            '운동량을 높임.$noteSuffix',
      ),
      generatedBy: 'rule',
    );
  }
}

/// Selects the real Dio-backed generator, or the demo generator for
/// `USE_MOCK_API=true`.
final trainerRoutineOptionsRepositoryProvider =
    Provider<TrainerRoutineOptionsRepository>((ref) {
      if (ref.watch(appConfigProvider).useMockApi) {
        return const MockTrainerRoutineOptionsRepository();
      }
      return DioTrainerRoutineOptionsRepository(ref.watch(dioProvider));
    }, name: 'trainerRoutineOptionsRepository');
