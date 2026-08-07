import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_card.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';

const MemberCoach _trainer = MemberCoach(
  trainerId: 'trainer-1',
  name: '김트레이너',
  specialty: '퍼스널 트레이너',
  career: '7년',
  intro: '건강한 운동을 돕습니다.',
  gymName: '온케어짐',
  goal: '건강 관리',
);

const CoachRoutine _trainerRoutine = CoachRoutine(
  id: 'trainer-routine',
  name: '코어 스트레칭',
  minutes: 10,
  type: '스트레칭',
  reason: '허리 부담 완화',
  source: 'trainer',
);

const CoachRoutine _aiRoutine = CoachRoutine(
  id: 'ai-routine',
  name: '어깨 관절 보호 스트레칭',
  minutes: 8,
  type: '스트레칭',
  reason: 'PT 피드백 반영 · 오른쪽 어깨 보호',
  source: 'ai',
);

const Trainer _assignedTrainer = Trainer(
  id: 'trainer-assigned',
  gymId: 'trainer-gym',
  name: '김트레이너',
  role: '퍼스널 트레이너',
);

void main() {
  Future<void> pumpRecommendationCards(
    WidgetTester tester,
    List<CoachRoutine> routines,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          memberCoachProvider.overrideWith((ref) async => _trainer),
          coachRoutinesProvider.overrideWith((ref) async => routines),
          coachUnreadProvider.overrideWith((ref) async => 0),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  CoachCard(),
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: AiRecommendedExerciseCard(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('source에 따라 트레이너와 AI 추천 운동을 각각 표시한다', (
    WidgetTester tester,
  ) async {
    await pumpRecommendationCards(tester, const <CoachRoutine>[
      _trainerRoutine,
      _aiRoutine,
    ]);

    final Finder trainerCard = find.byType(CoachCard);
    final Finder aiCard = find.byType(AiRecommendedExerciseCard);

    expect(find.text('트레이너 추천 추가 개인운동'), findsOneWidget);
    expect(find.text('트레이너와 채팅'), findsOneWidget);
    expect(
      find.descendant(
        of: trainerCard,
        matching: find.text(_trainerRoutine.name),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: trainerCard, matching: find.text(_aiRoutine.name)),
      findsNothing,
    );
    expect(
      find.descendant(of: aiCard, matching: find.text(_aiRoutine.name)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: aiCard, matching: find.text(_trainerRoutine.name)),
      findsNothing,
    );
    expect(
      find.text('나의 건강 기록과 트레이너 PT 피드백을 바탕으로 AI가 추천한 개인운동이에요'),
      findsOneWidget,
    );
  });

  testWidgets('각 출처의 추천 운동이 없으면 안내 문구를 표시한다', (WidgetTester tester) async {
    await pumpRecommendationCards(tester, const <CoachRoutine>[]);

    expect(find.text('아직 트레이너가 추천한 개인운동이 없어요'), findsOneWidget);
    expect(find.text('현재 추천할 수 있는 AI 맞춤 운동이 없어요'), findsOneWidget);
  });

  testWidgets('담당 트레이너 프로필은 트레이너 상세 경로로 이동한다', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: CoachCard()),
        ),
        GoRoute(
          path: AppRoutes.trainerDetail,
          builder: (_, GoRouterState state) => Scaffold(
            body: Text('trainer:${state.pathParameters['trainerId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          memberCoachProvider.overrideWith((ref) async => _trainer),
          coachRoutinesProvider.overrideWith(
            (ref) async => const <CoachRoutine>[],
          ),
          coachUnreadProvider.overrideWith((ref) async => 0),
          myTrainerProvider.overrideWith((ref) async => _assignedTrainer),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assignedTrainerProfile')));
    await tester.pumpAndSettle();

    expect(find.text('trainer:${_assignedTrainer.id}'), findsOneWidget);
  });

  testWidgets('트레이너 채팅은 말풍선 아래 시간과 입력창을 표시하고 메시지를 전송한다', (
    WidgetTester tester,
  ) async {
    final repository = MockMemberCoachRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          memberCoachRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              floatingActionButton: const FloatingActionButton(
                key: Key('underlyingFloatingButton'),
                onPressed: null,
              ),
              body: Center(
                child: ElevatedButton(
                  key: const Key('openTrainerChat'),
                  onPressed: () =>
                      openTrainerChatPage(context, trainerName: '김트레이너'),
                  child: const Text('채팅 열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('openTrainerChat')));
    await tester.pumpAndSettle();

    expect(find.byType(TrainerChatPage), findsOneWidget);
    expect(find.byKey(const Key('underlyingFloatingButton')), findsNothing);
    expect(find.text('김트레이너'), findsOneWidget);
    expect(find.text('담당 트레이너 · 상담 가능'), findsOneWidget);
    expect(find.text('김트레이너 · 13:20'), findsNothing);
    expect(find.text('13:20'), findsOneWidget);
    final Finder trainerBubble = find.byKey(
      const Key('coach-message-bubble-seed-m1'),
    );
    final Finder trainerAvatar = find.byKey(
      const Key('coach-message-avatar-seed-m1'),
    );
    final Finder trainerTime = find.byKey(
      const Key('coach-message-time-seed-m1'),
    );
    expect(
      tester.getTopLeft(trainerTime).dy,
      greaterThan(tester.getBottomLeft(find.textContaining('오늘 점심')).dy),
    );
    expect(
      tester.getBottomLeft(trainerAvatar).dy,
      closeTo(tester.getBottomLeft(trainerTime).dy, 0.1),
    );
    final BoxDecoration trainerBubbleDecoration =
        tester.widget<Container>(trainerBubble).decoration! as BoxDecoration;
    expect(trainerBubbleDecoration.color, Colors.white);
    expect(
      trainerBubbleDecoration.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(14),
        topRight: Radius.circular(14),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(14),
      ),
    );
    expect(find.text('트레이너에게 메시지 보내기...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '운동 후 확인할게요');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('운동 후 확인할게요'), findsOneWidget);
    expect(find.textContaining('나 ·'), findsNothing);
    final Finder sentBubble = find.ancestor(
      of: find.text('운동 후 확인할게요'),
      matching: find.byType(Container),
    ).first;
    final BoxDecoration sentBubbleDecoration =
        tester.widget<Container>(sentBubble).decoration! as BoxDecoration;
    expect(sentBubbleDecoration.color, FigmaColors.primary);
    expect(
      sentBubbleDecoration.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(14),
        topRight: Radius.circular(14),
        bottomLeft: Radius.circular(14),
        bottomRight: Radius.circular(4),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.byType(TrainerChatPage), findsNothing);
    expect(find.byKey(const Key('underlyingFloatingButton')), findsOneWidget);
  });
}
