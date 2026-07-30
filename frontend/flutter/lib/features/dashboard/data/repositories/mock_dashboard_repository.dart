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
      todaySchedule: <ScheduleItem>[
        ScheduleItem(time: '10:00', title: '병원 정기검진', emoji: '🏥'),
        ScheduleItem(time: '18:00', title: '헬스장 운동', emoji: '💪'),
      ],
      weekScore: 85,
      weekScoreDelta: 12,
      sodiumWarning: '김치찌개·배추김치 섭취로 나트륨이 높아요.',
      exerciseFeedback: '주간 운동 목표 80%를 달성했어요! 오늘 가볍게 걷기를 더해 100%를 채워봐요!',
    );
  }
}
