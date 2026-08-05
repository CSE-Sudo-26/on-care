import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

import '../../helpers/client_factory.dart';

ScheduleSession session({
  required String date,
  String status = '예정',
  String clientName = '테스트고객',
  List<ProgramItem> program = const <ProgramItem>[],
}) {
  return ScheduleSession(
    id: 'sess-$date-$status',
    date: date,
    time: '10:00',
    clientName: clientName,
    type: '1:1 PT',
    durationMinutes: 60,
    status: status,
    note: '',
    program: program,
  );
}

void main() {
  // A fixed Wednesday so the week boundaries are unambiguous.
  final wednesday = DateTime(2026, 8, 5);
  final monday = DateTime(2026, 8, 3);
  final sunday = DateTime(2026, 8, 9);

  group('weekStartOf', () {
    test('resolves any day to its Monday', () {
      expect(weekStartOf(wednesday), monday);
      expect(weekStartOf(monday), monday);
      expect(weekStartOf(sunday), monday);
    });

    test('strips the time so two moments on one day agree', () {
      expect(
        weekStartOf(DateTime(2026, 8, 5, 23, 59)),
        weekStartOf(DateTime(2026, 8, 5, 0, 1)),
      );
    });
  });

  group('buildWeeklyReport', () {
    test('counts only the sessions inside the reported week', () {
      final report = buildWeeklyReport(
        client: makeClient(),
        sessions: <ScheduleSession>[
          session(date: ymd(monday), status: '완료'),
          session(date: ymd(sunday)),
          // Last Sunday and next Monday are outside the window.
          session(date: ymd(monday.subtract(const Duration(days: 1)))),
          session(date: ymd(sunday.add(const Duration(days: 1)))),
        ],
        weekStart: wednesday,
      );

      expect(report.sessionsBooked, 2);
      expect(report.sessionsDone, 1);
      expect(report.attendanceRate, 50);
    });

    test('gap slots are not sessions', () {
      final report = buildWeeklyReport(
        client: makeClient(),
        sessions: <ScheduleSession>[session(date: ymd(monday), status: '공백')],
        weekStart: wednesday,
      );

      expect(report.sessionsBooked, 0);
      // Nothing booked — a rate would be a divide-by-zero fiction.
      expect(report.attendanceRate, isNull);
    });

    test('completion averages only the recorded days', () {
      final report = buildWeeklyReport(
        client: makeClient(weekCompletion: const <int>[80, 60, 0, 0, 0, 0, 0]),
        sessions: const <ScheduleSession>[],
        weekStart: wednesday,
        today: wednesday,
      );

      expect(report.completionAvg, 70);
    });

    test('a client with no logged days reports null, not 0%', () {
      final report = buildWeeklyReport(
        client: makeClient(weekCompletion: const <int>[0, 0, 0, 0, 0, 0, 0]),
        sessions: const <ScheduleSession>[],
        weekStart: wednesday,
        today: wednesday,
      );

      expect(report.completionAvg, isNull);
    });

    test('a PAST week does not borrow this week\'s roster aggregates', () {
      // weekCompletion/sodiumWeek carry no week of their own — they are
      // whatever the roster last computed. Attaching them to an earlier
      // week would report this week's numbers under last week's dates,
      // and the trainer can SEND that to the member.
      final lastWeek = monday.subtract(const Duration(days: 7));
      final report = buildWeeklyReport(
        client: makeClient(
          weekCompletion: const <int>[80, 80, 80, 80, 80, 80, 80],
          sodiumWeek: const <int>[2500, 2500, 1000, 1000, 1000, 1000, 1000],
        ),
        sessions: const <ScheduleSession>[],
        weekStart: lastWeek,
        today: wednesday,
      );

      expect(report.completionAvg, isNull);
      expect(report.sodiumOverDays, isNull);
      expect(report.sodiumAvg, isNull);
      // Unknown is not good — praise has to be earned by data we have.
      expect(report.isGoodWeek, isFalse);
    });

    test('the CURRENT week still uses them', () {
      final report = buildWeeklyReport(
        client: makeClient(
          weekCompletion: const <int>[80, 80, 80, 80, 80, 80, 80],
        ),
        sessions: const <ScheduleSession>[],
        weekStart: wednesday,
        today: wednesday,
      );

      expect(report.completionAvg, 80);
      expect(report.sodiumOverDays, isNotNull);
    });

    test('a past week\'s message omits the figures it cannot know', () {
      final report = buildWeeklyReport(
        client: makeClient(),
        sessions: const <ScheduleSession>[],
        weekStart: monday.subtract(const Duration(days: 7)),
        today: wednesday,
      );

      final message = reportMessage(report);
      expect(message, isNot(contains('이행률')));
      expect(message, isNot(contains('나트륨')));
    });

    test('carries the sodium figures from the client', () {
      final report = buildWeeklyReport(
        client: makeClient(
          sodiumWeek: const <int>[2500, 2400, 1000, 1000, 1000, 1000, 1000],
        ),
        sessions: const <ScheduleSession>[],
        weekStart: wednesday,
        today: wednesday,
      );

      expect(report.sodiumOverDays, 2);
      expect(report.sodiumAvg, 1414);
    });

    test('isGoodWeek needs both adherence and diet to hold up', () {
      WeeklyReport reportFor({required int completion, required int overDays}) {
        return buildWeeklyReport(
          client: makeClient(
            weekCompletion: List<int>.filled(7, completion),
            sodiumWeek: <int>[
              for (var i = 0; i < 7; i++) i < overDays ? 2500 : 1000,
            ],
          ),
          sessions: const <ScheduleSession>[],
          weekStart: wednesday,
          today: wednesday,
        );
      }

      expect(reportFor(completion: 80, overDays: 1).isGoodWeek, isTrue);
      expect(reportFor(completion: 50, overDays: 1).isGoodWeek, isFalse);
      expect(reportFor(completion: 80, overDays: 4).isGoodWeek, isFalse);
    });
  });

  group('reportMessage', () {
    test('reads as a trainer message, ending with encouragement', () {
      final report = buildWeeklyReport(
        client: makeClient(name: '김민수'),
        sessions: <ScheduleSession>[session(date: ymd(monday), status: '완료')],
        weekStart: wednesday,
      );

      final message = reportMessage(report);
      expect(message, contains('주간 리포트'));
      expect(message, contains('PT 세션 1/1회 완료'));
      expect(message, contains('이번 주 정말 잘하셨어요'));
    });

    test('omits figures the client has no data for', () {
      final report = buildWeeklyReport(
        client: makeClient(
          weekCompletion: const <int>[],
          sodiumWeek: const <int>[],
        ),
        sessions: const <ScheduleSession>[],
        weekStart: wednesday,
        today: wednesday,
      );

      final message = reportMessage(report);
      expect(message, isNot(contains('이행률')));
      expect(message, isNot(contains('나트륨')));
    });
  });

  group('buildTrainerWeekStats', () {
    test('summarises the trainer’s own week across all clients', () {
      final stats = buildTrainerWeekStats(
        sessions: <ScheduleSession>[
          session(date: ymd(monday), status: '완료'),
          session(
            date: ymd(wednesday),
            program: const <ProgramItem>[
              ProgramItem(name: '스쿼트', sets: 3, reps: '12회', weight: '60kg'),
            ],
          ),
          session(date: ymd(sunday), status: '공백'),
        ],
        clients: const <TrainerClient>[],
      );

      expect(stats.sessionsBooked, 2);
      expect(stats.sessionsDone, 1);
      expect(stats.programsSent, 1);
      expect(stats.completionRate, 50);
    });

    test('an empty week has no completion rate rather than 0%', () {
      final stats = buildTrainerWeekStats(
        sessions: const <ScheduleSession>[],
        clients: const <TrainerClient>[],
      );

      expect(stats.completionRate, isNull);
    });
  });
}
