import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';

class MockDashboardRepository implements DashboardRepository {
  const MockDashboardRepository();

  @override
  Future<DashboardSummary> fetchSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const DashboardSummary(
      indicators: <HealthIndicator>[
        HealthIndicator(label: '칼로리', current: 1860, max: 2000, unit: 'kcal'),
        HealthIndicator(
          label: '나트륨',
          current: 2329,
          max: 2000,
          unit: 'mg',
          overBudget: true,
        ),
        HealthIndicator(label: '당류', current: 43, max: 50, unit: 'g'),
      ],
      macros: DietMacros(
        carbsG: 203.6,
        proteinG: 109.3,
        fatG: 66.5,
        carbsPct: 44,
        proteinPct: 24,
        fatPct: 32,
      ),
      dietEntries: 4,
      exerciseMinutes: 45,
      exerciseCalories: 520,
      exerciseCount: 4,
      // 데모 주간 소모 목표. 화면이 하드코딩하던 값을 목 데이터로 옮겨,
      // 홈·운동 탭이 같은 소스(exerciseBurnGoal)를 읽어도 데모 수치는 그대로.
      exerciseBurnGoal: 1500,
      todaySchedule: <ScheduleItem>[
        ScheduleItem(time: '10:00', title: '병원 정기검진', emoji: '🏥'),
        ScheduleItem(time: '18:00', title: '헬스장 운동', emoji: '💪'),
      ],
      weekScore: 85,
      weekScoreDelta: 12,
      // 데모의 통합 조언은 화면의 다국어 리소스(homeAiAdviceBody)를 사용한다.
      sodiumWarning: null,
    );
  }
}
