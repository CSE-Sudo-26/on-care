import 'package:oncare/features/diet/domain/entities/diet_day.dart';

/// 기간 뷰의 하루. 하루 상세( [DietDay] )에서 화면이 그리는 세 수치만 남긴다.
class DietPeriodDay {
  const DietPeriodDay({
    required this.date,
    required this.calories,
    required this.sodiumMg,
    required this.sugarG,
  });

  /// 그날의 [DietDay] 를 접어 만든다. 합산 규칙은 하루 요약과 공유한다
  /// ([DietDayTotals]) — 따로 계산하면 두 화면의 숫자가 조용히 어긋난다.
  factory DietPeriodDay.from(DateTime date, DietDay day) => DietPeriodDay(
    date: date,
    calories: day.effectiveCalories,
    sodiumMg: day.effectiveSodiumMg,
    sugarG: day.effectiveSugarG,
  );

  final DateTime date;
  final int calories;
  final int sodiumMg;
  final double sugarG;

  /// 기록이 있었던 날인가. 칼로리를 기준으로 본다 — 물만 마신 날은 없다고
  /// 보는 편이 평균을 사실에 가깝게 만든다.
  bool get hasRecord => calories > 0;
}

/// 한 기간(이번 주·이번 달)의 식단 집계.
///
/// 합계가 아니라 **하루 평균**이 이 값의 머리 숫자다. 주(7일)와 달(28~31일)은
/// 길이가 다르므로 합계끼리 견주면 언제나 달이 크게 나온다. 평균은 **기록이
/// 있는 날만으로** 나눈다 — 기록하지 않은 날의 0 이 평균을 끌어내리면 실제로
/// 먹은 양과 다른 숫자가 된다.
class DietPeriod {
  const DietPeriod({required this.days});

  final List<DietPeriodDay> days;

  List<DietPeriodDay> get logged =>
      days.where((DietPeriodDay d) => d.hasRecord).toList();

  int get loggedDays => logged.length;

  bool get isEmpty => loggedDays == 0;

  int get totalCalories =>
      days.fold<int>(0, (int a, DietPeriodDay d) => a + d.calories);
  int get totalSodiumMg =>
      days.fold<int>(0, (int a, DietPeriodDay d) => a + d.sodiumMg);
  double get totalSugarG =>
      days.fold<double>(0, (double a, DietPeriodDay d) => a + d.sugarG);

  double get avgCalories => loggedDays == 0 ? 0 : totalCalories / loggedDays;
  double get avgSodiumMg => loggedDays == 0 ? 0 : totalSodiumMg / loggedDays;
  double get avgSugarG => loggedDays == 0 ? 0 : totalSugarG / loggedDays;
}
