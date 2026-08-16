import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/services/report_pdf_generator.dart';

import '../../helpers/client_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('한글 리포트와 긴 피드백을 실제 다중 페이지 PDF로 만든다', (tester) async {
    final report = WeeklyReport(
      client: makeClient(id: 'pdf-client', name: '김고객'),
      weekStart: DateTime(2026, 8, 10),
      sessionsBooked: 2,
      sessionsDone: 1,
      completionAvg: 72,
      sodiumOverDays: 2,
      sodiumAvg: 1890,
      isCurrentWeek: false,
      weekCompletion: const <int>[80, 0, 70, 90, 60, 0, 0],
      sodiumWeek: const <int>[1800, 0, 2100, 1700, 1950, 0, 0],
      caloriesWeek: const <int>[1800, 0, 1900, 1750, 2000, 0, 0],
      sugarWeek: const <double>[20, 0, 24.5, 19, 22, 0, 0],
      days: const <ReportDay>[
        ReportDay(completion: 80, exercises: <String>['스쿼트', '런지']),
      ],
    );
    final previous = WeeklyReport(
      client: report.client,
      weekStart: DateTime(2026, 8, 3),
      sessionsBooked: 2,
      sessionsDone: 2,
      completionAvg: 65,
      sodiumOverDays: 3,
      sodiumAvg: 2050,
      isCurrentWeek: false,
    );
    final content = const ReportPdfGenerator().textContent(
      report: report,
      previousReport: previous,
      feedback: '한글 피드백',
    );
    expect(content, contains('고객  김고객'));
    expect(content, contains('기간  2026-08-10 ~ 2026-08-16'));
    expect(content, contains('• 운동 수행률: 72%'));
    expect(content, contains('• 평균 열량: 1863kcal'));
    expect(content, contains('• 운동 수행률: +7%'));
    expect(content, contains('한글 피드백'));
    final bytes = await tester.runAsync(
      () => const ReportPdfGenerator().generate(
        report: report,
        previousReport: previous,
        feedback: List<String>.filled(80, '한글 피드백을 PDF에 정확히 반영합니다.').join(' '),
      ),
    );

    expect(ascii.decode(bytes!.sublist(0, 5)), '%PDF-');
    final source = latin1.decode(bytes, allowInvalid: true);
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(source).length,
      greaterThan(1),
    );
  });
}
