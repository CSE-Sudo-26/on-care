import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_card.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

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

class _ReadFailingMemberCoachRepository extends MockMemberCoachRepository {
  @override
  Future<void> markRead() async {
    throw StateError('읽음 처리 실패');
  }
}

class _SendFailingMemberCoachRepository extends MockMemberCoachRepository {
  @override
  Future<void> sendMessage(String text) async {
    throw StateError('메시지 전송 실패');
  }
}

class _ReadTrackingMemberCoachRepository extends MockMemberCoachRepository {
  int unreadCalls = 0;
  int markReadCalls = 0;
  bool _read = false;

  @override
  Future<int> unreadCount() async {
    unreadCalls += 1;
    return _read ? 0 : 1;
  }

  @override
  Future<void> markRead() async {
    markReadCalls += 1;
    _read = true;
  }
}

class _PdfMemberCoachRepository extends MockMemberCoachRepository {
  static final List<CoachMessage> _messages = <CoachMessage>[
    CoachMessage(
      id: 'pdf-message',
      sender: CoachSender.trainer,
      body: '이번 주 리포트입니다.',
      timeLabel: '18:20',
      createdAt: DateTime(2026, 8, 16, 18, 20),
      attachment: const CoachPdfAttachment(
        fileName: '김고객_2026-08-10_주간리포트.pdf',
        fileId: 'pdf-file',
        fileSize: 2048,
        downloadPath: '/chat/attachments/pdf-file',
      ),
    ),
  ];

  @override
  Future<List<CoachMessage>> fetchChat() async => _messages;

  @override
  Stream<List<CoachMessage>> watchChat() => Stream.value(_messages);
}

/// 데모(목업) 설정 — 채팅 화면이 `appConfigProvider` 를 읽어 안내 배너 노출을
/// 가른다. 이 provider 는 기본값 없이 던지므로 테스트마다 넣어 줘야 한다.
const AppConfig _demoConfig = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'http://localhost',
  useMockApi: true,
);

/// 채팅 화면 문구는 l10n 에서 온다 — 델리게이트 없이 띄우면 빌드가 실패한다.
Widget _chatApp(Widget home) => MaterialApp(
  locale: const Locale('ko'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
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

  testWidgets('여러 세션짜리 프로그램은 프로그램 이름과 세션 구분을 함께 보여 준다 (#709)', (
    WidgetTester tester,
  ) async {
    await pumpRecommendationCards(tester, const <CoachRoutine>[
      CoachRoutine(
        id: 'session-a',
        name: '세션 A · 하체',
        minutes: 30,
        type: '근력',
        reason: '레그프레스, 스쿼트',
        source: 'trainer',
        programName: '주 2회 분할',
        sessionName: '세션 A · 하체',
        exercises: <CoachRoutineExercise>[
          CoachRoutineExercise(
            name: '레그프레스',
            sets: '4',
            reps: '12회',
            weight: '60kg',
          ),
        ],
      ),
      CoachRoutine(
        id: 'session-b',
        name: '세션 B · 유산소',
        minutes: 20,
        type: '유산소',
        reason: '인터벌 러닝',
        source: 'trainer',
        programName: '주 2회 분할',
        sessionName: '세션 B · 유산소',
        sessionOrder: 1,
        exercises: <CoachRoutineExercise>[
          CoachRoutineExercise(name: '인터벌 러닝', duration: '20'),
        ],
      ),
    ]);

    final Finder trainerCard = find.byType(CoachCard);
    // 프로그램 이름은 묶음마다 한 번만 — 세션마다 반복하면 목록이 이름으로 찬다.
    expect(
      find.descendant(of: trainerCard, matching: find.text('주 2회 분할')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: trainerCard, matching: find.text('세션 A · 하체')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: trainerCard, matching: find.text('세션 B · 유산소')),
      findsOneWidget,
    );
    // 운동 구성이 세트·횟수·중량까지 그대로 보인다.
    expect(
      find.descendant(
        of: trainerCard,
        matching: find.text('레그프레스 · 4세트 × 12회 · 60kg'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: trainerCard,
        matching: find.text('인터벌 러닝 · 20분'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('단일 배정은 프로그램 이름표 없이 예전과 같이 보인다 (#709)', (
    WidgetTester tester,
  ) async {
    await pumpRecommendationCards(tester, const <CoachRoutine>[
      _trainerRoutine,
    ]);

    final Finder trainerCard = find.byType(CoachCard);
    expect(
      find.descendant(of: trainerCard, matching: find.byIcon(Icons.list_alt_outlined)),
      findsNothing,
    );
    expect(
      find.descendant(of: trainerCard, matching: find.text('허리 부담 완화')),
      findsOneWidget,
    );
  });

  testWidgets('배정 루틴 완료를 기록하고 완료 상태를 갱신한다', (WidgetTester tester) async {
    final MockMemberCoachRepository repository = MockMemberCoachRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          memberCoachRepositoryProvider.overrideWithValue(repository),
          myTrainerProvider.overrideWith((ref) async => _assignedTrainer),
        ],
        child: const MaterialApp(home: Scaffold(body: CoachCard())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('completeRoutine-seed-r2')));
    await tester.pumpAndSettle();
    expect(find.text('루틴 수행 완료'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('routineCompletionNote')),
      '허리는 편안했어요',
    );
    await tester.tap(find.text('높음'));
    await tester.tap(find.byKey(const Key('confirmRoutineCompletion')));
    await tester.pumpAndSettle();

    final CoachRoutine completed = (await repository.fetchRoutines())
        .firstWhere((CoachRoutine routine) => routine.id == 'seed-r2');
    expect(find.text('운동 기록에 반영했어요'), findsOneWidget);
    expect(find.text('내 메모: 허리는 편안했어요'), findsOneWidget);
    expect(find.byKey(const Key('completeRoutine-seed-r2')), findsNothing);
    expect(completed.completedIntensity, 'high');
  });

  testWidgets('완료한 루틴에 트레이너 피드백을 표시한다', (WidgetTester tester) async {
    await pumpRecommendationCards(tester, const <CoachRoutine>[
      CoachRoutine(
        id: 'done',
        name: '완료 루틴',
        minutes: 20,
        type: '근력',
        reason: '',
        source: 'trainer',
        completed: true,
        trainerFeedback: '자세가 좋았어요',
      ),
    ]);

    expect(find.text('트레이너 피드백: 자세가 좋았어요'), findsOneWidget);
    expect(find.byKey(const Key('routineFeedback-done')), findsOneWidget);
  });

  testWidgets('각 출처의 추천 운동이 없으면 안내 문구를 표시한다', (WidgetTester tester) async {
    await pumpRecommendationCards(tester, const <CoachRoutine>[]);

    expect(find.text('아직 트레이너가 추천한 개인운동이 없어요'), findsOneWidget);
    expect(find.text('현재 추천할 수 있는 AI 맞춤 운동이 없어요'), findsOneWidget);
  });

  testWidgets('담당 트레이너 프로필은 트레이너 상세 경로로 이동한다', (WidgetTester tester) async {
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
          appConfigProvider.overrideWithValue(_demoConfig),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
    // 말풍선 검사는 **마지막** 트레이너 메시지로 한다. 대화가 3일치로 늘면서
    // 화면은 맨 아래에서 열리므로, 첫 메시지는 뷰포트 밖이라 좌표를 잴 수 없다.
    expect(find.text('김트레이너 · 18:18'), findsNothing);
    expect(find.text('18:18'), findsOneWidget);
    final Finder trainerBubble = find.byKey(
      const Key('coach-message-bubble-seed-m18'),
    );
    final Finder trainerAvatar = find.byKey(
      const Key('coach-message-avatar-seed-m18'),
    );
    final Finder trainerTime = find.byKey(
      const Key('coach-message-time-seed-m18'),
    );
    // 본문은 그 말풍선 **안에서** 찾는다. '확인했어요' 로 화면 전체를 뒤지면
    // 첫날 메시지까지 걸려, 그 메시지가 뷰포트에 들어오는 순간 다중 일치로
    // 깨진다 (리뷰 지적).
    final Finder trainerBody = find.descendant(
      of: trainerBubble,
      matching: find.byType(Text),
    );
    expect(
      tester.getTopLeft(trainerTime).dy,
      greaterThan(tester.getBottomLeft(trainerBody).dy),
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
    final Finder sentBubble = find
        .ancestor(of: find.text('운동 후 확인할게요'), matching: find.byType(Container))
        .first;
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

  testWidgets('읽음 처리가 실패해도 대화 목록을 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          memberCoachRepositoryProvider.overrideWithValue(
            _ReadFailingMemberCoachRepository(),
          ),
          appConfigProvider.overrideWithValue(_demoConfig),
        ],
        child: _chatApp(const TrainerChatPage(trainerName: '김트레이너')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('확인했어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('읽음 처리 후 unread count를 갱신한다', (WidgetTester tester) async {
    final repository = _ReadTrackingMemberCoachRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          memberCoachRepositoryProvider.overrideWithValue(repository),
          appConfigProvider.overrideWithValue(_demoConfig),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              ref.watch(coachUnreadProvider);
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () =>
                      openTrainerChatPage(context, trainerName: '김트레이너'),
                  child: const Text('채팅 열기'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.unreadCalls, 1);

    await tester.tap(find.text('채팅 열기'));
    await tester.pumpAndSettle();

    expect(repository.markReadCalls, 1);
    expect(repository.unreadCalls, 2);
  });

  testWidgets('메시지 전송이 실패하면 입력 내용을 유지한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          memberCoachRepositoryProvider.overrideWithValue(
            _SendFailingMemberCoachRepository(),
          ),
          appConfigProvider.overrideWithValue(_demoConfig),
        ],
        child: _chatApp(const TrainerChatPage(trainerName: '김트레이너')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '다시 보낼 메시지');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    final TextField input = tester.widget<TextField>(find.byType(TextField));
    expect(input.controller?.text, '다시 보낼 메시지');
    expect(find.text('메시지 전송에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
  });

  testWidgets('PDF attachment를 파일명과 크기가 있는 카드로 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          memberCoachRepositoryProvider.overrideWithValue(
            _PdfMemberCoachRepository(),
          ),
          appConfigProvider.overrideWithValue(_demoConfig),
        ],
        child: _chatApp(const TrainerChatPage(trainerName: '김트레이너')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coach-pdf-pdf-file')), findsOneWidget);
    expect(find.text('김고객_2026-08-10_주간리포트.pdf'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });
}
