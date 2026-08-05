import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/ai_summary_card.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

import '../../helpers/client_factory.dart';

/// The dashboard's aggregation rules. These decide what the trainer is
/// told to do first, so they're worth pinning down without a widget.
void main() {
  group('buildDashboardSummary', () {
    test('counts active clients separately from the roster size', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[
          makeClient(id: 'a'),
          makeClient(id: 'b'),
          makeClient(id: 'c', active: false),
        ],
        unread: const <String, int>{},
      );

      expect(summary.totalClients, 3);
      expect(summary.activeClients, 2);
    });

    test('sums unread messages and the clients waiting on them', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[
          makeClient(id: 'a'),
          makeClient(id: 'b'),
          makeClient(id: 'c'),
        ],
        unread: const <String, int>{'a': 2, 'b': 3},
      );

      // 5 messages, but only 2 people are waiting — the KPI says
      // "3건" while the hint says "고객 2명".
      expect(summary.unreadTotal, 5);
      expect(summary.unreadClients, 2);
    });

    test('an unanswered client stays in the list but is not counted 주의', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[
          makeClient(id: 'sodium', sodiumMg: 2500),
          makeClient(id: 'waiting'),
        ],
        unread: const <String, int>{'waiting': 1},
      );

      // The trainer still owes 'waiting' a reply, so the row stays.
      expect(summary.attention.map((a) => a.client.id), <String>[
        'sodium',
        'waiting',
      ]);
      // …but 주의 means the member's own numbers, and 'waiting' has none.
      expect(summary.healthAttentionCount, 1);
      expect(summary.unreadClients, 1);
    });

    test('a health alert outranks an unanswered one on the same client', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[makeClient(id: 'both', sodiumMg: 2500)],
        unread: const <String, int>{'both': 3},
      );

      // The badge is the client's first alert. With 답장 대기 first, every
      // sodium overshoot hid behind a message the 답장 필요 card already
      // reported.
      expect(summary.attention.single.primary, ClientAlert.sodiumOver);
      expect(summary.attention.single.alerts, <ClientAlert>[
        ClientAlert.sodiumOver,
        ClientAlert.unanswered,
      ]);
      expect(summary.healthAttentionCount, 1);
    });

    test('within one alert type the incoming (priority) order is kept', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[
          makeClient(id: 'first', sodiumMg: 2100),
          makeClient(id: 'second', sodiumMg: 2400),
        ],
        unread: const <String, int>{},
      );

      expect(summary.attention.map((a) => a.client.id), <String>[
        'first',
        'second',
      ]);
    });

    test('a healthy roster raises nothing', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[makeClient(id: 'a')],
        unread: const <String, int>{},
      );

      expect(summary.attention, isEmpty);
    });

    test('weekly completion is the mean across clients, per weekday', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[
          makeClient(
            id: 'a',
            weekCompletion: const <int>[100, 0, 50, 0, 0, 0, 0],
          ),
          makeClient(
            id: 'b',
            weekCompletion: const <int>[0, 100, 50, 0, 0, 0, 0],
          ),
        ],
        unread: const <String, int>{},
      );

      expect(summary.weeklyCompletion, <int>[50, 50, 50, 0, 0, 0, 0]);
    });

    test('a client with no week data is skipped, not averaged as zero', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[
          makeClient(
            id: 'a',
            weekCompletion: const <int>[60, 60, 60, 60, 60, 60, 60],
          ),
          // Newly registered: no week array at all.
          makeClient(id: 'b', weekCompletion: const <int>[]),
        ],
        unread: const <String, int>{},
      );

      expect(summary.weeklyCompletion.first, 60);
    });
  });

  group('isLowCompletion', () {
    test('flags a recorded week averaging under the threshold', () {
      expect(
        isLowCompletion(
          makeClient(weekCompletion: const <int>[40, 30, 50, 0, 0, 0, 0]),
        ),
        isTrue,
      );
    });

    test('does NOT flag a client who has logged nothing yet', () {
      // A client registered this morning must not read as failing —
      // that trains the trainer to ignore the badge.
      expect(
        isLowCompletion(
          makeClient(weekCompletion: const <int>[0, 0, 0, 0, 0, 0, 0]),
        ),
        isFalse,
      );
      expect(
        isLowCompletion(makeClient(weekCompletion: const <int>[])),
        isFalse,
      );
    });

    test('averages only the days that were recorded', () {
      // 90% on the one day they trained is not a 13% week.
      expect(
        isLowCompletion(
          makeClient(weekCompletion: const <int>[90, 0, 0, 0, 0, 0, 0]),
        ),
        isFalse,
      );
    });
  });

  group('AiSummaryCard.messageFor', () {
    test('leads with unanswered messages over every other signal', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[makeClient(id: 'a', sodiumMg: 2500)],
        unread: const <String, int>{'a': 1},
      );
      expect(AiSummaryCard.messageFor(summary), contains('답장'));
    });

    test('mentions the sodium count when nobody is waiting', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[makeClient(id: 'a', sodiumMg: 2500)],
        unread: const <String, int>{},
      );
      expect(AiSummaryCard.messageFor(summary), contains('나트륨'));
    });

    test('an empty roster gets an onboarding line, not a stat', () {
      expect(
        AiSummaryCard.messageFor(DashboardSummary.empty),
        contains('담당 고객이 없어요'),
      );
    });

    test('a clean roster is told so rather than left blank', () {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[makeClient(id: 'a')],
        unread: const <String, int>{},
      );
      expect(AiSummaryCard.messageFor(summary), contains('목표 범위 안'));
    });
  });
}
