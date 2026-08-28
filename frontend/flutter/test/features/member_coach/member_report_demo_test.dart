/// 데모 데이터로 세운 리포트 문서 (#1617).
///
/// 다른 리포트 테스트들은 손으로 만든 [MemberWeeklyReport] 를 문서로 옮기는
/// 부분만 본다. 여기서는 **데모가 실제로 지나는 길**을 통째로 지난다 — drift 시드
/// → 저장소 → provider → 문서. 문서를 만드는 규칙이 아니라, 그 규칙에 들어오는
/// 값이 비어 있어서 났던 회귀를 잡는 자리다.
///
/// 실제로 두 가지가 그랬다. 요일별 상세의 운동 이름이 데모 경로에서 전부 걸러져
/// 이레 내내 `기록 없음` 이었고, 아직 오지 않은 요일을 가리는 기준 날짜가
/// provider 에서 넘어가지 않아 같은 자리에 다시 `기록 없음` 이 적혔다. 둘 다 문서를
/// 만드는 규칙은 맞았고 들어오는 값만 비어 있었다.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/core/storage/app_database.dart';
import 'package:oncare/core/storage/prefs_store.dart';
import 'package:oncare/core/storage/seed_data.dart';
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/entities/member_weekly_report.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_report_providers.dart';
import 'package:oncare/features/member_coach/services/member_report_pdf_generator.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

const List<String> _weekdays = <String>['월', '화', '수', '목', '금', '토', '일'];

/// 문서가 실제로 쓰는 서체를 테스트에도 올린다. (#1621)
///
/// 올리지 않으면 대체 서체로 재게 되는데, 그 글자 높이가 실기기와 달라 한 장에
/// 들어가는지를 여기서 잘못 판정한다 — 실제로 테스트는 한 장, 기기는 두 장이었다.
Future<void> _loadReportFont() async {
  for (final String weight in <String>[
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
  ]) {
    final File file = File('assets/fonts/Pretendard-$weight.otf');
    if (!file.existsSync()) continue;
    await (FontLoader('Pretendard')..addFont(
          Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
        ))
        .load();
  }
}

void main() {
  testWidgets('데모 리포트는 운동한 날마다 그날 한 운동을 적는다', (WidgetTester tester) async {
    await _loadReportFont();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfEmpty(db);

    late AppLocalizations l;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            l = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(_config),
        appLoggerProvider.overrideWithValue(Logger(level: Level.off)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    final List<CoachMessage> chat = await container
        .read(memberCoachRepositoryProvider)
        .fetchChat();
    final CoachMessage notice = chat.firstWhere(
      (CoachMessage m) => m.reportWeekStart != null,
      orElse: () => throw StateError('데모 대화에 리포트 안내가 없다'),
    );

    late MemberWeeklyReport report;
    await tester.runAsync(() async {
      report = await container.read(
        memberWeeklyReportProvider(notice.reportWeekStart!).future,
      );
    });

    final List<String> lines = const MemberReportPdfGenerator().textContent(
      l: l,
      report: report,
      trainerNote: notice.body,
    );

    // 시드는 오늘에 맞춰 미끄러지므로 요일을 고정하지 않는다 — 문서가 스스로
    // 말하는 값(운동한 분)과 요일별 상세가 어긋나지 않는지만 본다.
    expect(report.exercise.totalMinutes, greaterThan(0));
    final DateTime now = nowKst();
    final DateTime today = DateTime(now.year, now.month, now.day);
    bool checkedAny = false;
    for (int i = 0; i < _weekdays.length; i++) {
      final String prefix = '${_weekdays[i]}요일 — ';
      final String line = lines.firstWhere(
        (String s) => s.startsWith(prefix),
        orElse: () => throw StateError('$prefix 줄이 없다'),
      );
      final DateTime day = DateTime(
        report.weekStart.year,
        report.weekStart.month,
        report.weekStart.day + i,
      );
      if (day.isAfter(today)) {
        expect(
          line,
          l.coachReportPdfDayUpcoming(_weekdays[i]),
          reason: '오지 않은 날을 기록이 없는 날로 적으면 안 된다',
        );
        continue;
      }
      if (report.minutesByDay[i] > 0) {
        checkedAny = true;
        expect(
          line,
          isNot(contains(l.coachReportPdfNoData)),
          reason: '$prefix 그날 운동한 시간이 있는데 내역이 비어 있다',
        );
      }
    }
    expect(checkedAny, isTrue, reason: '운동한 날이 하나도 없으면 이 테스트가 아무것도 못 지킨다');

    // 한 장에 담기로 한 문서다(#1619). 넘치면 마지막 한 줄만 든 빈 종이가 한 장
    // 더 생긴다 — 실기기에서 실제로 그랬다(#1621).
    expect(
      const MemberReportPdfGenerator().pageCount(
        l: l,
        report: report,
        trainerNote: notice.body,
      ),
      1,
      reason: '리포트 문서는 한 장이어야 한다',
    );
  });
}
