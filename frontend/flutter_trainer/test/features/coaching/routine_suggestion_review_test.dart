import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_suggestion_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_suggestion.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_editor_workspace.dart';

import '../../helpers/pump_app.dart';

/// 검토 호출을 기록하는 가짜 저장소. 지연을 둘 수 있어 '처리 중 두 번 클릭'을
/// 재현한다.
class _FakeSuggestionRepository implements TrainerRoutineSuggestionRepository {
  _FakeSuggestionRepository({
    required this.byMember,
    this.delay = Duration.zero,
    this.alreadyReviewed = false,
  });

  /// 회원별 검토 대기 목록. 검토한 것은 여기서 지운다.
  final Map<String, List<RoutineSuggestion>> byMember;

  /// 검토 호출을 붙잡아 두는 시간. 0 이면 곧바로 끝난다.
  final Duration delay;

  /// true 면 모든 검토가 409(이미 검토됨)로 끝난다.
  final bool alreadyReviewed;

  final List<String> approvals = <String>[];
  final List<Map<String, Object?>> approvalEdits = <Map<String, Object?>>[];
  final List<String> dismissals = <String>[];
  final List<String> reads = <String>[];

  @override
  Future<List<RoutineSuggestion>> pending(String memberId) async {
    reads.add(memberId);
    return byMember[memberId] ?? const <RoutineSuggestion>[];
  }

  @override
  Future<void> approve(
    String suggestionId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  }) async {
    approvals.add(suggestionId);
    approvalEdits.add(<String, Object?>{
      'name': name,
      'minutes': minutes,
      'type': type,
      'reason': reason,
    });
    await Future<void>.delayed(delay);
    if (alreadyReviewed) throw RoutineSuggestionAlreadyReviewed(suggestionId);
    _remove(suggestionId);
  }

  @override
  Future<void> dismiss(String suggestionId) async {
    dismissals.add(suggestionId);
    await Future<void>.delayed(delay);
    if (alreadyReviewed) throw RoutineSuggestionAlreadyReviewed(suggestionId);
    _remove(suggestionId);
  }

  void _remove(String suggestionId) {
    for (final list in byMember.values) {
      list.removeWhere((s) => s.id == suggestionId);
    }
  }
}

const RoutineSuggestion _shoulder = RoutineSuggestion(
  id: 's-shoulder',
  name: '어깨 관절 보호 스트레칭',
  minutes: 8,
  type: '스트레칭',
  reason: '회전근개와 어깨 안정화를 돕는 스트레칭이에요',
  evidence: <String>['최근 PT 피드백 반영'],
);

const RoutineSuggestion _walking = RoutineSuggestion(
  id: 's-walking',
  name: '회복 목적 걷기',
  minutes: 20,
  type: '유산소',
  reason: '대화할 수 있는 속도로 걸어 보세요',
  evidence: <String>['혈압 관리 목표'],
);

void main() {
  /// 첫 시드 고객과 그 다음 고객 — 회원 전환 테스트가 두 명을 쓴다.
  const String firstClient = 'seed-client-1';
  const String secondClient = 'seed-client-2';

  Future<_FakeSuggestionRepository> openProgramTab(
    WidgetTester tester, {
    Map<String, List<RoutineSuggestion>>? byMember,
    Duration delay = Duration.zero,
    bool alreadyReviewed = false,
  }) async {
    final repo = _FakeSuggestionRepository(
      byMember:
          byMember ??
          <String, List<RoutineSuggestion>>{
            firstClient: <RoutineSuggestion>[_shoulder, _walking],
          },
      delay: delay,
      alreadyReviewed: alreadyReviewed,
    );
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.coaching,
      extraOverrides: <Override>[
        trainerRoutineSuggestionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Finder approveButton(RoutineSuggestion s) =>
      find.byKey(ValueKey<String>('routine-suggestion-approve-${s.id}'));
  Finder dismissButton(RoutineSuggestion s) =>
      find.byKey(ValueKey<String>('routine-suggestion-dismiss-${s.id}'));
  Finder editButton(RoutineSuggestion s) =>
      find.byKey(ValueKey<String>('routine-suggestion-edit-${s.id}'));

  group('동작 버튼의 생김새와 자리 (#939)', () {
    testWidgets('수정은 이름 줄 오른쪽 끝의 연필 아이콘 버튼이다', (tester) async {
      await openProgramTab(tester);

      // 판단이 아니라 보조 동작이다. 아래 줄에 같은 크기로 세워 두면
      // `추천 안 함`·`추천` 과 함께 셋 중 하나를 고르는 것처럼 읽힌다.
      final IconButton edit = tester.widget<IconButton>(editButton(_shoulder));
      expect((edit.icon as Icon).icon, Icons.edit_outlined);
      expect(edit.color, AppColors.primary);

      // 손볼 대상(운동 이름·시간) 옆에 있다 — 아래 판단 줄이 아니다.
      final Rect editRect = tester.getRect(editButton(_shoulder));
      final Rect nameRect = tester.getRect(find.text(_shoulder.name));
      final Rect approveRect = tester.getRect(approveButton(_shoulder));
      expect(editRect.left, greaterThan(nameRect.right));
      expect(editRect.center.dy, lessThan(approveRect.top));
    });

    testWidgets('추천 안 함도 테두리를 가진 버튼이다', (tester) async {
      await openProgramTab(tester);

      // 예전에는 흐린 글자만 있는 TextButton 이라 카드 안의 설명 문구와
      // 구별되지 않아, 누를 수 있는 것인지 알 수 없었다.
      expect(
        tester.widget(dismissButton(_shoulder)),
        isA<OutlinedButton>(),
        reason: '테두리가 없으면 누를 수 있는 것으로 읽히지 않는다',
      );
      // 카드 안만 본다. 프로그램 탭 전체를 뒤지면 다른 영역에 `TextButton`
      // 하나만 생겨도, 이 카드의 거절 버튼이 멀쩡한데 테스트가 깨진다.
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('routine-suggestion-review-card'),
          ),
          matching: find.byType(TextButton),
        ),
        findsNothing,
      );
    });

    testWidgets('버튼 어디에도 검은 윤곽선이 없다', (tester) async {
      await openProgramTab(tester);

      // 테마에 버튼 스타일이 없어 기본값(colorScheme.outline)을 쓰면 이 버튼만
      // 검은 윤곽선으로 나온다.
      final OutlinedButton dismiss = tester.widget<OutlinedButton>(
        dismissButton(_shoulder),
      );
      final BorderSide? side = dismiss.style!.side!.resolve(<WidgetState>{});
      expect(side, isNotNull);
      expect(side!.color, AppColors.primary.withValues(alpha: 0.45));
      expect(
        dismiss.style!.foregroundColor!.resolve(<WidgetState>{}),
        AppColors.primary,
      );
    });

    testWidgets('아래 줄에는 판단 둘만 남는다', (tester) async {
      await openProgramTab(tester);

      // 카드 하나에 결정 둘 — 추천 안 함 · 고객에게 추천.
      expect(find.text('추천 안 함'), findsNWidgets(2));
      expect(find.text('고객에게 추천'), findsNWidgets(2));
      // `회원` 은 이 화면의 다른 문구(`고객 관리` 등)와 어긋난다.
      expect(find.text('회원에게 추천'), findsNothing);
    });

    testWidgets('검토 중에는 세 동작이 모두 잠긴다', (tester) async {
      await openProgramTab(tester, delay: const Duration(milliseconds: 300));

      await tester.tap(approveButton(_shoulder));
      await tester.pump();

      expect(
        tester.widget<IconButton>(editButton(_shoulder)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(dismissButton(_shoulder)).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(approveButton(_shoulder)).onPressed,
        isNull,
      );
      await tester.pumpAndSettle();
    });
  });

  testWidgets('pending suggestions show what they are and why', (tester) async {
    await openProgramTab(tester);

    expect(find.text('AI 개인운동 제안'), findsOneWidget);
    expect(find.text(_shoulder.name), findsOneWidget);
    expect(find.text('8분'), findsWidgets);
    expect(find.text(_shoulder.reason), findsOneWidget);
    // 근거가 함께 있어야 트레이너가 승인 여부를 판단할 수 있다.
    expect(find.text('최근 PT 피드백 반영'), findsOneWidget);
    // 검토 필요 건수.
    expect(find.text('검토 필요 2'), findsOneWidget);
  });

  testWidgets('the review area sits above the program editor', (tester) async {
    await openProgramTab(tester);

    final review = tester.getTopLeft(
      find.byKey(const ValueKey<String>('routine-suggestion-review-card')),
    );
    final editor = tester.getTopLeft(find.byType(ProgramEditorWorkspace));

    // 정규 프로그램과 개인운동은 목적이 다르다 — 편집기 위에서 판단만 한다.
    expect(review.dy, lessThan(editor.dy));
  });

  testWidgets('approving sends it to the member and clears the card', (
    tester,
  ) async {
    final repo = await openProgramTab(tester);

    await tester.tap(approveButton(_shoulder));
    await tester.pumpAndSettle();

    expect(repo.approvals, <String>[_shoulder.id]);
    // 그대로 승인이므로 고친 값은 없다.
    expect(repo.approvalEdits.single.values.every((v) => v == null), isTrue);
    expect(find.text(_shoulder.name), findsNothing);
    expect(find.textContaining('추천했어요'), findsOneWidget);
    expect(find.text('검토 필요 1'), findsOneWidget);
  });

  testWidgets('dismissing keeps it away from the member', (tester) async {
    final repo = await openProgramTab(tester);

    await tester.tap(dismissButton(_walking));
    await tester.pumpAndSettle();

    expect(repo.dismissals, <String>[_walking.id]);
    expect(repo.approvals, isEmpty);
    expect(find.text(_walking.name), findsNothing);
    expect(find.textContaining('추천하지 않아요'), findsOneWidget);
  });

  testWidgets('editing then recommending sends the edited values', (
    tester,
  ) async {
    final repo = await openProgramTab(tester);

    await tester.tap(editButton(_shoulder));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('suggestion-edit-name')),
      '어깨 회복 스트레칭',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('suggestion-edit-memo')),
      '오른쪽 어깨에 통증이 생기면 중단하세요',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('suggestion-edit-type-요가')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('suggestion-edit-submit')),
    );
    await tester.pumpAndSettle();

    expect(repo.approvals, <String>[_shoulder.id]);
    final edit = repo.approvalEdits.single;
    expect(edit['name'], '어깨 회복 스트레칭');
    expect(edit['reason'], '오른쪽 어깨에 통증이 생기면 중단하세요');
    expect(edit['type'], '요가');
    expect(edit['minutes'], _shoulder.minutes);
  });

  testWidgets('cancelling the edit does not recommend anything', (
    tester,
  ) async {
    final repo = await openProgramTab(tester);

    await tester.tap(editButton(_shoulder));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('suggestion-edit-cancel')),
    );
    await tester.pumpAndSettle();

    expect(repo.approvals, isEmpty);
    expect(find.text(_shoulder.name), findsOneWidget);
  });

  testWidgets('a double tap approves once', (tester) async {
    final repo = await openProgramTab(
      tester,
      delay: const Duration(milliseconds: 300),
    );

    await tester.tap(approveButton(_shoulder));
    await tester.pump();
    // 첫 호출이 아직 진행 중이다 — 두 번째 탭이 같은 제안을 또 보내면 안 된다.
    await tester.tap(approveButton(_shoulder), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(repo.approvals, <String>[_shoulder.id]);
  });

  testWidgets('an already-reviewed suggestion says so instead of failing', (
    tester,
  ) async {
    await openProgramTab(tester, alreadyReviewed: true);

    await tester.tap(approveButton(_shoulder));
    await tester.pumpAndSettle();

    expect(find.textContaining('이미 검토한 제안'), findsOneWidget);
  });

  testWidgets('switching clients loads that client\'s suggestions', (
    tester,
  ) async {
    final repo = await openProgramTab(
      tester,
      byMember: <String, List<RoutineSuggestion>>{
        firstClient: <RoutineSuggestion>[_shoulder],
        secondClient: <RoutineSuggestion>[_walking],
      },
    );

    expect(find.text(_shoulder.name), findsOneWidget);
    expect(find.text(_walking.name), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('program-client-$secondClient')),
    );
    await tester.pumpAndSettle();

    expect(repo.reads, contains(secondClient));
    expect(find.text(_walking.name), findsOneWidget);
    expect(find.text(_shoulder.name), findsNothing);
  });

  testWidgets('no suggestions leaves a quiet one-line empty state', (
    tester,
  ) async {
    await openProgramTab(
      tester,
      byMember: <String, List<RoutineSuggestion>>{
        firstClient: <RoutineSuggestion>[],
      },
    );

    expect(
      find.byKey(const ValueKey<String>('routine-suggestion-empty')),
      findsOneWidget,
    );
    // 검토할 것이 없는 날에는 건수 배지도 없다.
    expect(
      find.byKey(const ValueKey<String>('routine-suggestion-badge')),
      findsNothing,
    );
  });
}
