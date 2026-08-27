/// 리포트 등록 안내와 그 미리보기 문서 (#1600).
///
/// 트레이너 앱의 짝은
/// `frontend/flutter_trainer/test/features/clients/client_detail_chat_test.dart`
/// 의 `리포트 전송 메시지는 …` 테스트다 — 같은 사건을 두 앱이 같은 정보 구조로
/// 그린다. 한쪽 문구만 고치면 여기서 깨진다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/diet/domain/entities/diet_period.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/entities/member_weekly_report.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_report_card.dart';
import 'package:oncare/features/member_coach/services/member_report_pdf_generator.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

final DateTime _weekStart = DateTime(2026, 8, 17);

/// 리포트 안내 한 줄만 들어 있는 스레드.
class _ReportThreadRepository extends MockMemberCoachRepository {
  _ReportThreadRepository();

  static final List<CoachMessage> messages = <CoachMessage>[
    CoachMessage(
      id: 'report-1',
      sender: CoachSender.trainer,
      body: '이번 주 리포트입니다.',
      timeLabel: '18:10',
      createdAt: DateTime(2026, 8, 24, 18, 10),
      reportWeekStart: _weekStart,
    ),
  ];

  @override
  Future<List<CoachMessage>> fetchChat() async => messages;

  @override
  Stream<List<CoachMessage>> watchChat() =>
      Stream<List<CoachMessage>>.value(messages);
}

/// 리포트 안내가 온 **뒤에도** 대화가 이어진 스레드.
class _ReportThenChatRepository extends MockMemberCoachRepository {
  _ReportThenChatRepository();

  static final List<CoachMessage> messages = <CoachMessage>[
    CoachMessage(
      id: 'report-1',
      sender: CoachSender.trainer,
      body: '이번 주 리포트입니다.',
      timeLabel: '18:10',
      createdAt: DateTime(2026, 8, 24, 18, 10),
      reportWeekStart: _weekStart,
    ),
    CoachMessage(
      id: 'after-1',
      sender: CoachSender.me,
      body: '확인했습니다',
      timeLabel: '18:20',
      createdAt: DateTime(2026, 8, 24, 18, 20),
    ),
  ];

  @override
  Future<List<CoachMessage>> fetchChat() async => messages;

  @override
  Stream<List<CoachMessage>> watchChat() =>
      Stream<List<CoachMessage>>.value(messages);
}

MemberWeeklyReport _report({
  List<ExerciseSession> sessions = const <ExerciseSession>[],
  List<double> minutes = const <double>[30, 0, 45, 0, 20, 0, 0],
  List<DietPeriodDay> days = const <DietPeriodDay>[],
  int booked = 2,
  int done = 1,
}) => MemberWeeklyReport(
  weekStart: _weekStart,
  exercise: ExerciseWeek(
    sessions: sessions,
    dailyMinutes: minutes,
    dayLabels: const <String>['월', '화', '수', '목', '금', '토', '일'],
    totalMinutes: 95,
    totalCalories: 620,
    streakDays: 1,
    aiCoachMessage: '',
  ),
  diet: DietPeriod(days: days),
  sessionsBooked: booked,
  sessionsDone: done,
);

List<DietPeriodDay> _week() => <DietPeriodDay>[
  for (int i = 0; i < 7; i++)
    DietPeriodDay(
      date: DateTime(2026, 8, 17 + i),
      calories: i == 6 ? 0 : 1800 + (i * 50),
      sodiumMg: i == 6 ? 0 : 2100,
      sugarG: i == 6 ? 0 : 24.5,
    ),
];

void main() {
  Future<AppLocalizations> localizations(
    WidgetTester tester, {
    String lang = 'ko',
  }) async {
    late AppLocalizations l;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(lang),
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
    return l;
  }

  Future<void> pumpChat(
    WidgetTester tester, {
    MockMemberCoachRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_config),
          memberCoachRepositoryProvider.overrideWithValue(
            repository ?? _ReportThreadRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrainerChatPage(trainerName: '김트레이너'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('리포트 등록 안내 (#1600)', () {
    testWidgets('말풍선이 아니라 대화 가운데 상자로 뜬다', (WidgetTester tester) async {
      await pumpChat(tester);

      expect(find.byType(CoachReportCard), findsOneWidget);
      expect(find.text('리포트가 등록되었어요'), findsOneWidget);
      expect(find.text('8월 17일 – 8월 23일'), findsOneWidget);
      expect(find.text('PDF 미리보기'), findsOneWidget);
      // 본문 그대로의 말풍선은 그리지 않는다 — 같은 사건이 두 번 보인다.
      expect(find.text('이번 주 리포트입니다.'), findsNothing);

      final Rect box = tester.getRect(find.byType(CoachReportCard));
      final Rect screen = tester.getRect(find.byType(MaterialApp));
      expect(
        (box.center.dx - screen.center.dx).abs(),
        lessThan(1.0),
        reason: '안내는 트레이너 말풍선처럼 한쪽에 붙지 않는다',
      );
    });

    testWidgets('뒤에 대화가 이어져도 안내는 맨 아래에 남는다', (WidgetTester tester) async {
      await pumpChat(tester, repository: _ReportThenChatRepository());

      final Rect card = tester.getRect(find.byType(CoachReportCard));
      final Rect lastBubble = tester.getRect(find.text('확인했습니다'));
      expect(
        card.top,
        greaterThan(lastBubble.bottom),
        reason: '리포트를 여는 자리는 대화가 늘어도 같은 곳이어야 한다',
      );
    });
  });

  group('리포트 미리보기 문서 (#1600)', () {
    testWidgets('트레이너 리포트와 같은 지표를 회원 기록으로 적는다', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l = await localizations(tester);
      final List<String> lines = const MemberReportPdfGenerator().textContent(
        l: l,
        report: _report(
          days: _week(),
          sessions: <ExerciseSession>[
            ExerciseSession(
              dayLabel: '월',
              type: ExerciseType.cardio,
              minutes: 30,
              calories: 210,
              name: '걷기',
              date: DateTime(2026, 8, 17),
            ),
          ],
        ),
      );

      expect(lines.first, '기간 2026-08-17 ~ 2026-08-23');
      expect(lines, contains('주요 지표'));
      expect(lines, contains('· 운동한 날: 3일'));
      expect(lines, contains('· 총 운동 시간: 95분'));
      expect(lines, contains('· 소모 칼로리: 620kcal'));
      expect(lines, contains('· PT 세션: 2회 중 1회'));
      // 평균은 **기록이 있는 날만으로** 나눈다 — 안 먹은 날의 0 이 평균을
      // 끌어내리면 실제로 먹은 양과 다른 숫자가 된다.
      expect(lines, contains('· 평균 섭취 칼로리: 1925kcal'));
      expect(lines, contains('· 평균 나트륨: 2100mg'));
      expect(lines, contains('· 평균 당류: 24.5g'));
      expect(lines, contains('요일별 추이'));
      expect(lines, contains('· 운동 시간: 30분 / - / 45분 / - / 20분 / - / -'));
      expect(lines, contains('요일별 상세'));
      expect(lines, contains('월요일 — 운동 걷기, 섭취 1800kcal'));
      // 기록이 없는 날은 0 을 적지 않는다.
      expect(lines, contains('일요일 — 운동 기록 없음, 섭취 기록 없음'));
      expect(lines.last, contains('회원님 기록으로 정리한 미리보기'));
    });

  });
}
