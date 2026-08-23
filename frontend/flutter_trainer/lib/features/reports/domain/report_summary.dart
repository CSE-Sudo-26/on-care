import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/number_format.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays;
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart' as targets;
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// 한 주를 트레이너가 손볼 수 있는 문장으로 압축한 것.
///
/// 그대로 읽는 글이 아니라 **피드백 초안으로 가져다 고칠 재료**다(#755).
class ReportSummary {
  /// Creates a summary.
  const ReportSummary({
    required this.headline,
    required this.points,
    required this.generatedBy,
  });

  /// 이번 주를 한 문장으로. 잘한 점과 챙길 점이 함께 들어간다.
  final String headline;

  /// 근거가 된 수치 문장. 리포트 화면이 이미 보여 주는 값만 담는다 — 요약과
  /// 그래프가 다른 값을 말하면 트레이너가 어느 쪽을 믿어야 할지 모른다.
  final List<String> points;

  /// `llm` 이면 생성된 것, `rule` 이면 수치에서 조립한 것. 화면이 이 둘을
  /// 구분해 말해야 트레이너가 문장을 어디까지 믿을지 안다.
  final String generatedBy;

  /// 모델이 만든 문장인가.
  bool get isGenerated => generatedBy == 'llm';

  /// 피드백 입력창에 넣을 본문. 제목 줄과 근거를 그대로 잇는다.
  String get asDraft =>
      <String>[headline, ...points.map((p) => '· $p')].join('\n');
}

/// 하루 목표 — 백엔드 `trainer_report_summary_service` 와 같은 값이다.
const int summarySodiumTargetMg = 2000;

/// 이행률이 이 아래면 주의로 본다 — 주의 배지·리포트 막대와 같은 기준.
const int summaryLowCompletion = 70;

/// 목표를 이 날 수보다 많이 넘겼으면 주의로 본다 — [WeeklyReport.isGoodWeek]
/// 와 같은 기준이다.
const int summarySodiumOverDays = 2;

/// 근거 문장 수. 셋을 넘으면 카드가 리포트 본문만큼 길어져 요약이 아니게 된다.
const int summaryMaxPoints = 3;

/// 다음 주 제안 수. 근거 세 줄과 함께 놓이므로 둘이 상한이다.
const int summaryMaxActions = 2;

/// 화면의 수치를 요약이 인용할 수 있는 문장으로 굳힌다.
///
/// **여기 없는 말은 근거가 될 수 없다.** 백엔드가 모델에 주는 목록과 같은
/// 규칙이라, 데모에서 본 문장과 실서버에서 본 문장이 같은 자리에서 나온다.
List<String> summaryEvidence(WeeklyReport report) {
  final lines = <String>[];
  final completion = report.completionAvg;
  if (completion != null) lines.add('운동 이행률 평균 $completion%');
  final sodium = report.sodiumAvg;
  if (sodium != null) {
    lines.add(
      '나트륨 평균 ${formatNumber(sodium)}mg · '
      '목표 ${formatNumber(summarySodiumTargetMg)}mg '
      '초과 ${report.sodiumOverDays ?? 0}일',
    );
  }
  final recorded = report.caloriesWeek.where((v) => v > 0).toList();
  if (recorded.isNotEmpty) {
    final mean = recorded.fold<double>(0, (a, b) => a + b) / recorded.length;
    lines.add('칼로리 평균 ${formatNumber(mean.round())}kcal');
  }
  final skipped = <String>[];
  for (final day in report.days) {
    for (final line in day.exercises) {
      if (!line.contains('✗')) continue;
      // 분량을 뗀 이름으로 묶는다 — 같은 운동을 요일마다 건너뛴 것이 서로 다른
      // 운동 셋으로 읽히면 안 된다(#1177).
      final name = exerciseBaseName(line);
      if (name.isNotEmpty && !skipped.contains(name)) skipped.add(name);
    }
  }
  if (skipped.isNotEmpty) {
    lines.add('건너뛴 운동: ${skipped.take(summaryMaxPoints).join(', ')}');
  }
  return lines;
}

/// 모델 없이 수치에서 조립하는 요약.
///
/// 데모의 기본값이자 실서버의 실패 경로다 — 공급자가 죽어도 카드가 비지
/// 않는다. 백엔드의 `_rule_summary` 와 같은 문장을 만든다.
ReportSummary ruleReportSummary(WeeklyReport report, TrainerClient client) {
  final evidence = summaryEvidence(report);
  final name = client.name;
  if (evidence.isEmpty) {
    return ReportSummary(
      headline: '$name 고객은 그 주 기록이 없어 다음 주 시작을 함께 잡아 주세요.',
      points: const <String>[],
      generatedBy: 'rule',
    );
  }

  final good = <String>[];
  final watch = <String>[];
  final completion = report.completionAvg;
  if (completion != null) {
    (completion >= summaryLowCompletion ? good : watch).add(
      '운동 이행률 $completion%',
    );
  }
  final sodium = report.sodiumAvg;
  if (sodium != null) {
    // 평균만 보면 목표 안이어도 사흘을 넘긴 주가 '목표 범위 안' 으로 넘어갔다.
    // 바로 아래 근거 줄이 `초과 3일` 을 적고 있어 한 카드가 서로 다른 말을
    // 했다 — [WeeklyReport.isGoodWeek] 와 같은 기준으로 가른다(#1177).
    final over = report.sodiumOverDays ?? 0;
    final bool watched =
        sodium > summarySodiumTargetMg || over > summarySodiumOverDays;
    (watched ? watch : good).add(
      over > 0
          ? '나트륨 목표 초과 $over일'
          : '나트륨 평균 ${formatNumber(sodium)}mg',
    );
  }

  final String headline;
  if (watch.isNotEmpty && good.isNotEmpty) {
    final String kept = hasFinalConsonant(good.first) ? '으로' : '로';
    final String care = hasFinalConsonant(watch.first) ? '을' : '를';
    headline =
        '$name 고객은 ${good.first}$kept 잘 지켰고, '
        '다음 주는 ${watch.first}$care 함께 챙기면 좋겠습니다.';
  } else if (watch.isNotEmpty) {
    final String subject = hasFinalConsonant(watch.first) ? '이' : '가';
    headline = '$name 고객은 ${watch.first}$subject 목표를 벗어나 다음 주 조정이 필요합니다.';
  } else {
    headline = '$name 고객은 기록이 목표 범위 안에 있어 지금 강도를 유지해도 좋습니다.';
  }
  return ReportSummary(
    headline: headline,
    points: evidence.take(summaryMaxPoints).toList(growable: false),
    generatedBy: 'rule',
  );
}


/// 그 주 수치에서 곧바로 나오는 **다음 주 할 일**.
///
/// 요약은 지난 한 주를 말하고, 이 목록은 그래서 무엇을 하면 되는지를 말한다.
/// 트레이너에게 하는 말이라 회원에게 보낼 초안([ReportSummary.asDraft])에는
/// 넣지 않는다 — 문장의 상대가 다르다(#1177).
///
/// 모델을 부르지 않는다. 화면이 이미 보여 주는 수치에서만 나오므로 실서버든
/// 데모든 같은 제안이 뜨고, 요약 생성이 실패한 주에도 카드가 비지 않는다.
List<String> summaryCoachingActions(AppLocalizations l, WeeklyReport report) {
  final actions = <String>[];
  final over = report.sodiumOverDays ?? 0;
  if (over > 0 || (report.sodiumAvg ?? 0) > summarySodiumTargetMg) {
    actions.add(l.reportsActionSodium);
  }
  final sugarOver = report.sugarWeek
      .where((g) => g > targets.sugarTargetG)
      .length;
  if (sugarOver > 0) {
    actions.add(l.reportsActionSugar(formatNumber(targets.sugarTargetG)));
  }
  final completion = report.completionAvg;
  if (completion != null && completion < summaryLowCompletion) {
    actions.add(l.reportsActionLowCompletion);
  }
  final skipped = <String>[];
  for (final day in report.days) {
    for (final line in day.exercises) {
      if (!line.contains('✗')) continue;
      final name = exerciseBaseName(line);
      if (name.isNotEmpty && !skipped.contains(name)) skipped.add(name);
    }
  }
  if (skipped.isNotEmpty) {
    final names = skipped.take(2).join(', ');
    actions.add(
      l.reportsActionSkipped(
        '$names${hasFinalConsonant(names) ? '은' : '는'}',
      ),
    );
  }
  final unlogged = report.weekCompletion.where((v) => v == 0).length;
  // 아직 오지 않은 날은 세지 않는다 — 이번 주 목요일에 "사흘 비었다" 고 하면
  // 오지도 않은 날을 나무라는 말이 된다.
  final pending = report.isCurrentWeek
      ? report.weekCompletion.length - elapsedWeekdays(nowKst())
      : 0;
  if (unlogged - pending > 0) {
    actions.add(l.reportsActionUnlogged(unlogged - pending));
  }
  final calories = recordedMean(report.caloriesWeek);
  if (calories != null && calories < targets.calorieTargetKcal * 0.8) {
    actions.add(l.reportsActionCalories(formatNumber(targets.calorieTargetKcal)));
  }
  if (completion != null && completion >= 90 && actions.isEmpty) {
    actions.add(l.reportsActionHighCompletion);
  }
  // 둘까지만. 근거 세 줄 아래에 제안이 셋까지 붙으면 왼쪽 열에서 카드가
  // 스스로 스크롤하기 시작해, 채우려던 자리가 오히려 잘려 보인다.
  return actions.take(summaryMaxActions).toList(growable: false);
}
