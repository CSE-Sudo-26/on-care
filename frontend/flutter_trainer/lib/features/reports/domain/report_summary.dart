import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
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

/// 근거 문장 수. 셋을 넘으면 카드가 리포트 본문만큼 길어져 요약이 아니게 된다.
const int summaryMaxPoints = 3;

/// 화면의 수치를 요약이 인용할 수 있는 문장으로 굳힌다.
///
/// **여기 없는 말은 근거가 될 수 없다.** 백엔드가 모델에 주는 목록과 같은
/// 규칙이라, 데모에서 본 문장과 실서버에서 본 문장이 같은 자리에서 나온다.
List<String> summaryEvidence(WeeklyReport report) {
  final lines = <String>[];
  final completion = report.completionAvg;
  if (completion != null) lines.add('운동 이행률 평균 $completion%');
  if (report.sessionsBooked > 0) {
    lines.add('PT 세션 ${report.sessionsDone}/${report.sessionsBooked}회 완료');
  }
  final sodium = report.sodiumAvg;
  if (sodium != null) {
    lines.add(
      '나트륨 평균 ${sodium}mg · 목표 ${summarySodiumTargetMg}mg '
      '초과 ${report.sodiumOverDays ?? 0}일',
    );
  }
  final recorded = report.caloriesWeek.where((v) => v > 0).toList();
  if (recorded.isNotEmpty) {
    final mean = recorded.fold<double>(0, (a, b) => a + b) / recorded.length;
    lines.add('칼로리 평균 ${mean.round()}kcal');
  }
  final skipped = <String>[];
  for (final day in report.days) {
    for (final line in day.exercises) {
      if (!line.contains('✗')) continue;
      final name = line.replaceAll('✗', '').trim();
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
      headline: '$name 고객은 이번 주 기록이 없어 다음 주 시작을 함께 잡아 주세요.',
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
    (sodium > summarySodiumTargetMg ? watch : good).add('나트륨 평균 ${sodium}mg');
  }

  final String headline;
  if (watch.isNotEmpty && good.isNotEmpty) {
    headline =
        '$name 고객은 ${good.first} 로 잘 지켰고, 다음 주는 ${watch.first} 을 함께 챙기면 좋겠습니다.';
  } else if (watch.isNotEmpty) {
    headline = '$name 고객은 ${watch.first} 이 목표를 벗어나 다음 주 조정이 필요합니다.';
  } else {
    headline = '$name 고객은 이번 주 기록이 목표 범위 안에 있어 지금 강도를 유지해도 좋습니다.';
  }
  return ReportSummary(
    headline: headline,
    points: evidence.take(summaryMaxPoints).toList(growable: false),
    generatedBy: 'rule',
  );
}
