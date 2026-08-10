import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/app/session_feature_reset.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/session/session_feature_reset.dart';
import 'package:oncare/features/ai_coach/domain/entities/ai_coach_state.dart';
import 'package:oncare/features/ai_coach/domain/entities/chat_message.dart';
import 'package:oncare/features/ai_coach/domain/repositories/ai_coach_repository.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/ai_coach_controller.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/chat_controller.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/repositories/member_coach_repository.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/notification/presentation/controllers/notification_controller.dart';

const AppConfig _mockConfig = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

class _FakeAiCoachRepository implements AiCoachRepository {
  @override
  Future<AiCoachState> fetchState() async {
    return const AiCoachState(greeting: '', suggestions: <AiSuggestion>[]);
  }

  @override
  Future<List<ChatMessage>> fetchHistory() async => const <ChatMessage>[];

  @override
  Future<ChatMessage> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    return const ChatMessage(role: ChatRole.coach, content: '확인했어요');
  }
}

void main() {
  test(
    'session reset clears mutable account state and recreates mock roots',
    () async {
      var accountId = 'account-a';
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_mockConfig),
          aiCoachRepositoryProvider.overrideWith(
            (ref) => _FakeAiCoachRepository(),
          ),
          coachSessionsProvider.overrideWith((ref) async {
            return <CoachSession>[
              CoachSession(
                id: '$accountId-session',
                date: DateTime(2026, 8, 10),
                time: '18:00',
                type: '1:1 PT',
                durationMinutes: 50,
                status: '완료',
              ),
            ];
          }),
          sessionFeatureResetOverride(),
        ],
      );
      addTearDown(container.dispose);

      await container.read(chatControllerProvider.notifier).send('A 사용자 메시지');
      await container
          .read(notificationControllerProvider.notifier)
          .markAllRead();
      container.read(exerciseRoutineDoneProvider.notifier).state = <bool>[
        true,
        false,
      ];

      final MemberCoachRepository memberCoachBefore = container.read(
        memberCoachRepositoryProvider,
      );
      expect(
        (await container.read(coachSessionsProvider.future)).single.id,
        'account-a-session',
      );
      await memberCoachBefore.sendMessage('A 사용자 트레이너 메시지');

      final Object dietRepositoryBefore = container.read(
        dietRepositoryProvider,
      );
      final Object exerciseRepositoryBefore = container.read(
        exerciseRepositoryProvider,
      );
      final Object gymRepositoryBefore = container.read(gymRepositoryProvider);

      expect(
        container
            .read(chatControllerProvider)
            .messages
            .any((ChatMessage message) => message.content == 'A 사용자 메시지'),
        isTrue,
      );
      expect(container.read(notificationControllerProvider).unreadCount, 0);
      // 시드 15개 + 방금 보낸 1개. 개수를 상수로 적으면 시드가 늘 때마다
      // 여기가 깨지므로, 시드 길이는 새 리포지토리에서 읽어 비교한다.
      final int seedLength =
          (await MockMemberCoachRepository().fetchChat()).length;
      expect(await memberCoachBefore.fetchChat(), hasLength(seedLength + 1));

      accountId = 'account-b';
      container.read(sessionFeatureResetProvider)();

      expect(
        container
            .read(chatControllerProvider)
            .messages
            .any((ChatMessage message) => message.content == 'A 사용자 메시지'),
        isFalse,
      );
      expect(
        container.read(notificationControllerProvider).unreadCount,
        greaterThan(0),
      );
      expect(container.read(exerciseRoutineDoneProvider), <bool>[false, false]);
      expect(
        (await container.read(coachSessionsProvider.future)).single.id,
        'account-b-session',
      );

      final MemberCoachRepository memberCoachAfter = container.read(
        memberCoachRepositoryProvider,
      );
      expect(identical(memberCoachAfter, memberCoachBefore), isFalse);
      expect(await memberCoachAfter.fetchChat(), hasLength(seedLength));
      expect(
        identical(container.read(dietRepositoryProvider), dietRepositoryBefore),
        isFalse,
      );
      expect(
        identical(
          container.read(exerciseRepositoryProvider),
          exerciseRepositoryBefore,
        ),
        isFalse,
      );
      expect(
        identical(container.read(gymRepositoryProvider), gymRepositoryBefore),
        isFalse,
      );
    },
  );
}
