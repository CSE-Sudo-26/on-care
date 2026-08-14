import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/dashboard/data/ai_coaching_summary_repository.dart';
import 'package:oncare_trainer/features/dashboard/domain/ai_coaching_summary.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
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

  group('DemoAiCoachingSummaryRepository', () {
    test(
      'turns a named client signal into a specific exercise focus',
      () async {
        final summary = buildDashboardSummary(
          clients: <TrainerClient>[
            makeClient(
              id: 'a',
              name: '김민수',
              sodiumMg: 2500,
              lastMessage: '무릎이 가볍게 당겨요',
            ),
          ],
          unread: const <String, int>{'a': 1},
        );
        final result = await const DemoAiCoachingSummaryRepository().fetch(
          summary,
        );

        expect(result.kind, CoachingSummaryKind.attention);
        expect(result.clients.single.ruleData?.signal, RuleCoachingSignal.knee);
      },
    );

    test('includes the sodium value as evidence', () async {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[makeClient(id: 'a', sodiumMg: 2500)],
        unread: const <String, int>{},
      );
      final result = await const DemoAiCoachingSummaryRepository().fetch(
        summary,
      );

      expect(result.clients.single.ruleData?.sodiumMg, 2500);
      expect(result.clients.single.ruleData?.sodiumTargetMg, 2000);
    });

    test('an empty roster gets an onboarding line, not a stat', () async {
      final result = await const DemoAiCoachingSummaryRepository().fetch(
        DashboardSummary.empty,
      );

      expect(result.headline, isEmpty);
      expect(result.clients, isEmpty);
      expect(result.kind, CoachingSummaryKind.noClients);
    });

    test('a clean roster is told so rather than left blank', () async {
      final summary = buildDashboardSummary(
        clients: <TrainerClient>[makeClient(id: 'a')],
        unread: const <String, int>{},
      );
      final result = await const DemoAiCoachingSummaryRepository().fetch(
        summary,
      );

      expect(result.kind, CoachingSummaryKind.allOnTrack);
      expect(result.totalClients, 1);
    });

    test('ordinary body-part words are not treated as pain signals', () async {
      for (final message in <String>['오늘 하체 운동 완료', '목표를 달성했어요']) {
        final summary = buildDashboardSummary(
          clients: <TrainerClient>[makeClient(id: 'a', lastMessage: message)],
          unread: const <String, int>{'a': 1},
        );
        final result = await const DemoAiCoachingSummaryRepository().fetch(
          summary,
        );
        expect(
          result.clients.single.ruleData?.signal,
          RuleCoachingSignal.unanswered,
          reason: message,
        );
      }
    });

    test(
      'unanswered and low completion keep different coaching signals',
      () async {
        final unanswered = buildDashboardSummary(
          clients: <TrainerClient>[makeClient(id: 'reply')],
          unread: const <String, int>{'reply': 1},
        );
        final lowCompletion = buildDashboardSummary(
          clients: <TrainerClient>[
            makeClient(
              id: 'low',
              weekCompletion: const <int>[40, 40, 0, 0, 0, 0, 0],
            ),
          ],
          unread: const <String, int>{'low': 1},
        );
        final unansweredResult = await const DemoAiCoachingSummaryRepository()
            .fetch(unanswered);
        final lowResult = await const DemoAiCoachingSummaryRepository().fetch(
          lowCompletion,
        );
        expect(
          unansweredResult.clients.single.ruleData?.signal,
          RuleCoachingSignal.unanswered,
        );
        expect(
          lowResult.clients.single.ruleData?.signal,
          RuleCoachingSignal.lowCompletion,
        );
      },
    );
  });
}
