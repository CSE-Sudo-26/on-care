import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_invite_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_invite.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_connect_dialog.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 회원 ID로 찾고, 확인하고, 연결한다. 한 번에 연결하지 않는 것이 이 창의
/// 요지라(오타 한 글자가 다른 사람에게 가는 요청이 된다) 그 순서를 검증한다.
/// (#919)
class _FakeInviteRepository implements ClientInviteRepository {
  _FakeInviteRepository({
    this.found,
    this.pending = const <ClientInvite>[],
    this.connectsImmediately = false,
  });

  MemberLookup? found;
  List<ClientInvite> pending;

  @override
  final bool connectsImmediately;
  final List<({String memberId, String? message})> sent =
      <({String memberId, String? message})>[];
  final List<String> cancelled = <String>[];
  AppError? inviteFailure;

  @override
  bool get supportsInvites => true;

  @override
  Future<MemberLookup> lookup(String memberId) async {
    final result = found;
    if (result == null) throw const NotFoundError();
    return result;
  }

  @override
  Future<ClientInvite> invite(String memberId, {String? message}) async {
    if (inviteFailure case final AppError failure) throw failure;
    sent.add((memberId: memberId, message: message));
    return ClientInvite(
      id: 'tci-new',
      memberId: memberId,
      memberName: found?.name ?? '',
      memberEmail: '',
      status: connectsImmediately
          ? ClientInviteStatus.accepted
          : ClientInviteStatus.pending,
      createdAt: DateTime(2026, 8, 19),
    );
  }

  @override
  Future<List<ClientInvite>> listSent({String status = 'pending'}) async =>
      pending;

  @override
  Future<void> cancel(String inviteId) async => cancelled.add(inviteId);
}

MemberLookup _lookup({
  bool hasTrainer = false,
  bool coachedByMe = false,
  bool invitePending = false,
  String? gender,
  int? age,
  String? goal,
}) => MemberLookup(
  memberId: 'user-a3f9c81e4b2d',
  name: '김민수',
  hasTrainer: hasTrainer,
  coachedByMe: coachedByMe,
  invitePending: invitePending,
  gender: gender,
  age: age,
  goal: goal,
);

Future<void> _pumpDialog(
  WidgetTester tester,
  _FakeInviteRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        clientInviteRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ClientConnectDialog()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('보내기 버튼은 회원을 찾기 전에는 없다', (tester) async {
    await _pumpDialog(tester, _FakeInviteRepository(found: _lookup()));

    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('회원 ID 입력은 고객 탭의 compact 타이포그래피를 사용한다', (tester) async {
    await _pumpDialog(tester, _FakeInviteRepository(found: _lookup()));

    final fieldFinder = find.byKey(
      const ValueKey<String>('client-connect-member-id'),
    );
    final field = tester.widget<TextField>(fieldFinder);
    expect(field.style?.fontSize, 12.5);
    expect(field.style?.fontWeight, FontWeight.w500);
    expect(field.style?.color, AppColors.mutedForeground);
    expect(field.decoration?.isDense, isTrue);
    expect(
      field.decoration?.contentPadding,
      const EdgeInsets.only(left: 12, top: 10, bottom: 10),
    );
    final lookupFinder = find.byKey(
      const ValueKey<String>('client-connect-lookup'),
    );
    expect(tester.widget<IconButton>(lookupFinder).tooltip, '찾기');
    expect(
      tester.getRect(fieldFinder).contains(tester.getRect(lookupFinder).center),
      isTrue,
    );
  });

  testWidgets('찾은 회원을 확인한 뒤에야 요청을 보낸다', (tester) async {
    final repository = _FakeInviteRepository(found: _lookup());
    await _pumpDialog(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-a3f9c81e4b2d',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('client-connect-lookup')),
    );
    await tester.pumpAndSettle();

    // 이름이 먼저 보인다 — 눈으로 확인하고 누르라는 뜻이다. 이메일 등 다른
    // 인적 사항은 보여주지 않는다.
    expect(find.text('김민수'), findsOneWidget);
    expect(find.text('minsu@oncare.com'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-invite-message')),
      '센터에서 뵀어요',
    );
    await tester.tap(find.text('담당 요청 보내기'));
    await tester.pumpAndSettle();

    expect(repository.sent, hasLength(1));
    expect(repository.sent.single.memberId, 'user-a3f9c81e4b2d');
    expect(repository.sent.single.message, '센터에서 뵀어요');
  });

  testWidgets('없는 회원 ID에는 사유가 입력창에 붙는다', (tester) async {
    await _pumpDialog(tester, _FakeInviteRepository());

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-no-such-member',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('client-connect-lookup')),
    );
    await tester.pumpAndSettle();

    expect(find.text('그 회원 ID를 쓰는 회원을 찾지 못했어요'), findsOneWidget);
    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('이미 다른 트레이너가 담당 중이면 보낼 수 없다고 말한다', (tester) async {
    await _pumpDialog(
      tester,
      _FakeInviteRepository(found: _lookup(hasTrainer: true)),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-a3f9c81e4b2d',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('client-connect-lookup')),
    );
    await tester.pumpAndSettle();

    expect(find.text('이미 다른 트레이너가 담당 중인 회원이에요'), findsOneWidget);
    // 이유만 보여 주고 끝내지 않는다 — 누를 수 없어야 이유가 이유가 된다.
    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('서버가 거절하면 그 사유가 화면에 남고 창은 닫히지 않는다', (tester) async {
    final repository = _FakeInviteRepository(found: _lookup())
      ..inviteFailure = const ValidationError(message: '이미 보낸 요청이 기다리고 있어요.');
    await _pumpDialog(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-a3f9c81e4b2d',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('client-connect-lookup')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('담당 요청 보내기'));
    await tester.pumpAndSettle();

    expect(find.text('이미 보낸 요청이 기다리고 있어요.'), findsOneWidget);
    expect(find.byType(ClientConnectDialog), findsOneWidget);
  });

  testWidgets('답을 기다리는 요청은 여기서만 볼 수 있고 거둘 수 있다', (tester) async {
    final repository = _FakeInviteRepository(
      found: _lookup(),
      pending: <ClientInvite>[
        ClientInvite(
          id: 'tci-1',
          memberId: 'user-b7c2f0913da5',
          memberName: '이지수',
          memberEmail: 'jisu@oncare.com',
          status: ClientInviteStatus.pending,
          createdAt: DateTime(2026, 8, 18),
        ),
      ],
    );
    await _pumpDialog(tester, repository);

    expect(find.text('이지수'), findsOneWidget);
    // 회원 ID만 아는 트레이너에게 이메일까지 보여줄 이유가 없다.
    expect(find.text('jisu@oncare.com'), findsNothing);

    await tester.tap(find.text('요청 거두기'));
    await tester.pumpAndSettle();

    expect(repository.cancelled, <String>['tci-1']);
  });

  testWidgets('찾은 뒤 입력값을 바꾸면 확인 카드가 사라진다', (tester) async {
    // 회원 A를 찾고 나서 입력값만 B로 바꾸면, 다시 찾기 전까지는 화면에 A가
    // 남아 있으면 안 된다 — 그대로 두면 트레이너가 B를 연결한다고 착각한 채
    // A에게 요청을 보내게 된다.
    await _pumpDialog(tester, _FakeInviteRepository(found: _lookup()));

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-a3f9c81e4b2d',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('client-connect-lookup')),
    );
    await tester.pumpAndSettle();

    expect(find.text('김민수'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('client-connect-member-id')),
      'user-different-member',
    );
    await tester.pump();

    expect(find.text('김민수'), findsNothing);
    expect(find.text('담당 요청 보내기'), findsNothing);
  });

  testWidgets('가운데 뜨는 작은 창으로 열린다', (tester) async {
    // 상담 요청 인박스(showConsultationsDialog)와 같은 형식 — 바닥에서
    // 올라오는 시트가 아니라 Dialog 다. BottomSheet 위젯이 트리에 없어야
    // 한다.
    await _pumpDialog(tester, _FakeInviteRepository(found: _lookup()));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  group('connectsImmediately (데모)', () {
    testWidgets('메시지 칸·대기 목록 없이 바로 등록하고 성공을 안내한다', (tester) async {
      final repository = _FakeInviteRepository(
        found: _lookup(),
        connectsImmediately: true,
      );
      await _pumpDialog(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey<String>('client-connect-member-id')),
        'user-a3f9c81e4b2d',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('client-connect-lookup')),
      );
      await tester.pumpAndSettle();

      expect(find.text('김민수'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('client-invite-message')),
        findsNothing,
      );
      expect(find.text('답을 기다리는 요청'), findsNothing);

      final registerButton = find.byKey(
        const ValueKey<String>('client-connect-register'),
      );
      expect(
        find.descendant(of: registerButton, matching: find.text('고객 등록')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: registerButton,
          matching: find.byIcon(Icons.person_add_alt_1_rounded),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pump();

      expect(repository.sent, hasLength(1));
      expect(find.text('김민수님을 고객으로 등록했어요'), findsOneWidget);
    });

    testWidgets('조회된 회원의 성별·나이·운동 목표가 확인 화면에 함께 뜬다', (tester) async {
      final repository = _FakeInviteRepository(
        found: _lookup(gender: 'female', age: 29, goal: '체지방 감량'),
        connectsImmediately: true,
      );
      await _pumpDialog(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey<String>('client-connect-member-id')),
        'user-a3f9c81e4b2d',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('client-connect-lookup')),
      );
      await tester.pumpAndSettle();

      expect(find.text('이 고객이 맞나요?'), findsOneWidget);
      expect(find.textContaining('여성'), findsOneWidget);
      expect(find.textContaining('29세'), findsOneWidget);
      expect(find.textContaining('체지방 감량'), findsOneWidget);
    });

    testWidgets('데모용 회원 ID를 다이얼로그에 노출하지 않는다', (tester) async {
      final repository = _FakeInviteRepository(connectsImmediately: true);
      await _pumpDialog(tester, repository);

      expect(find.text('데모용 회원 ID'), findsNothing);
      expect(find.text('user-8f2a41c9d6e3'), findsNothing);
      expect(find.text('user-1c7b93f04a58'), findsNothing);
    });

    testWidgets('닫았다 다시 열면 입력값·조회 결과가 남지 않는다', (tester) async {
      final repository = _FakeInviteRepository(
        found: _lookup(),
        connectsImmediately: true,
      );
      await _pumpDialog(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey<String>('client-connect-member-id')),
        'user-a3f9c81e4b2d',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('client-connect-lookup')),
      );
      await tester.pumpAndSettle();
      expect(find.text('김민수'), findsOneWidget);

      // 닫는다 — 실제 화면은 여기서 다이얼로그 라우트가 pop 되며 State 가
      // 사라진다. 트리 모양이 달라지는 위젯을 한 번 끼워 넣어 같은 자리를
      // 재사용하지 못하게 한다.
      await tester.pumpWidget(const SizedBox.shrink());

      // 다시 연다 — showDialog 가 매번 그렇듯 완전히 새 인스턴스다.
      await _pumpDialog(tester, repository);

      expect(
        find
            .byKey(const ValueKey<String>('client-connect-member-id'))
            .evaluate()
            .map((e) => (e.widget as TextField).controller!.text),
        <String>[''],
      );
      expect(find.text('김민수'), findsNothing);
    });
  });
}
