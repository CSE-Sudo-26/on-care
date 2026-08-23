import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/app/shell/nav_destinations.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations_ko.dart';

import '../../helpers/pump_app.dart';

/// 라벨 기대값은 로케일을 명시해 읽는다 — 기본 로케일이 바뀌어도 의도가 남는다.
final AppLocalizationsKo _ko = AppLocalizationsKo();

ConsultationRequest _request({
  String id = 'consult-1',
  String name = '김민수',
  String status = 'pending',
  String? message = '상담 부탁드립니다.',
  DateTime? createdAt,
}) => ConsultationRequest(
  id: id,
  memberId: 'user-$id',
  memberName: name,
  goalCode: 'weight_loss',
  purposeCode: 'chronic',
  preferredDate: DateTime(2026, 8, 12),
  preferredTimeCode: 'evening',
  message: message,
  status: status,
  createdAt: createdAt,
);

/// A stand-in inbox that reports itself enabled (so the nav row renders)
/// and records the decisions made against it.
class _FakeConsultationRepository implements ConsultationRepository {
  _FakeConsultationRepository({
    List<ConsultationRequest>? requests,
    this.failure,
  }) : requests = requests ?? <ConsultationRequest>[];

  List<ConsultationRequest> requests;
  final AppError? failure;

  final List<String> accepted = <String>[];
  final List<(String, String?)> rejected = <(String, String?)>[];

  @override
  bool get supportsInbox => true;

  /// 이어 받기 요청으로 들어온 커서 — 인박스가 무엇을 넘겼는지 확인한다(#980).
  final List<(DateTime?, String?)> cursors = <(DateTime?, String?)>[];

  @override
  Future<List<ConsultationRequest>> fetch({
    String status = 'pending',
    int limit = consultationPageSize,
    DateTime? before,
    String? beforeId,
  }) async {
    if (failure != null) throw failure!;
    // 서버와 같은 순서로 준다 — 최신 요청이 먼저다. 이 순서가 아니면 커서가 가리키는
    // '받은 마지막 요청'이 가장 오래된 것이 아니게 되어 이어 받기가 성립하지 않는다.
    final List<ConsultationRequest> rows =
        (status == 'pending' ? requests.where((r) => r.isPending) : requests)
            .toList()
          ..sort((ConsultationRequest a, ConsultationRequest b) {
            final DateTime? x = a.createdAt;
            final DateTime? y = b.createdAt;
            if (x == null || y == null) return 0;
            return y.compareTo(x);
          });
    if (before == null) return rows.take(limit).toList();
    cursors.add((before, beforeId));
    // 커서보다 오래된 것만 — 서버와 같은 규칙이다.
    return rows
        .where(
          (ConsultationRequest r) =>
              r.createdAt != null && r.createdAt!.isBefore(before),
        )
        .take(limit)
        .toList();
  }

  @override
  Stream<List<ConsultationRequest>> watch({
    String status = 'pending',
    int limit = consultationPageSize,
  }) => Stream<List<ConsultationRequest>>.fromFuture(
    fetch(status: status, limit: limit),
  );

  @override
  Future<int> pendingCount() async => requests.where((r) => r.isPending).length;

  @override
  Stream<int> watchPendingCount() => Stream<int>.fromFuture(pendingCount());

  @override
  Future<void> accept(String id, {ConsultationSchedule? schedule}) async {
    accepted.add(id);
    requests = requests
        .map((r) => r.id == id ? _request(id: id, status: 'accepted') : r)
        .toList();
  }

  @override
  Future<void> reject(String id, {String? note}) async {
    rejected.add((id, note));
    requests = requests
        .map((r) => r.id == id ? _request(id: id, status: 'rejected') : r)
        .toList();
  }
}

Future<ProviderContainer> _pumpInbox(
  WidgetTester tester,
  _FakeConsultationRepository repo,
) => pumpTrainerApp(
  tester,
  token: 'demo-token',
  at: AppRoutes.consultations,
  extraOverrides: <Override>[
    consultationRepositoryProvider.overrideWithValue(repo),
  ],
);

void main() {
  testWidgets('renders a pending request with its decision actions', (
    tester,
  ) async {
    await _pumpInbox(
      tester,
      _FakeConsultationRepository(requests: <ConsultationRequest>[_request()]),
    );

    expect(find.text('상담 요청'), findsWidgets);
    expect(find.text('김민수'), findsOneWidget);
    expect(find.text('체중 감량'), findsOneWidget);
    // 관리 목적은 회원이 고른 운동 목표에서 자동으로 채워지는 값이라
    // 더는 따로 보이지 않는다(#1112).
    expect(find.text('관리 목적'), findsNothing);
    expect(find.text('건강관리 목적'), findsNothing);
    // 문의 내용도 다른 항목처럼 라벨을 달아 무엇을 보여주는 값인지 밝힌다.
    expect(find.text(_ko.consultMessage), findsOneWidget);
    expect(find.text('상담 부탁드립니다.'), findsOneWidget);
    expect(find.text('승인'), findsOneWidget);
    expect(find.text('거절'), findsOneWidget);
  });

  testWidgets('does not repeat that every request targets a trainer', (
    tester,
  ) async {
    await _pumpInbox(
      tester,
      _FakeConsultationRepository(requests: <ConsultationRequest>[_request()]),
    );

    // 요청은 항상 트레이너 앞으로 오므로 카드마다 같은 배지를 반복하지 않는다.
    expect(find.text('트레이너 지정'), findsNothing);
    expect(find.text('헬스장 문의'), findsNothing);
  });

  testWidgets('offers a route back to the schedule', (tester) async {
    await _pumpInbox(tester, _FakeConsultationRepository());

    await tester.tap(
      find.byKey(const ValueKey<String>('consultations-back-to-schedule')),
    );
    await settle(tester);

    expect(currentLocation(tester), AppRoutes.schedule);
  });

  testWidgets('accepting sends the decision to the repository', (tester) async {
    final repo = _FakeConsultationRepository(
      requests: <ConsultationRequest>[_request()],
    );
    await _pumpInbox(tester, repo);

    await tester.tap(find.text('승인'));
    await settle(tester);

    expect(repo.accepted, <String>['consult-1']);
  });

  testWidgets('a decided request shows its outcome, not the actions', (
    tester,
  ) async {
    final repo = _FakeConsultationRepository(
      requests: <ConsultationRequest>[_request(status: 'accepted')],
    );
    await _pumpInbox(tester, repo);
    // 처리된 건은 '전체' 필터에서만 보인다.
    await tester.tap(find.text('전체 보기'));
    await settle(tester);

    expect(find.text('담당 고객으로 등록됨'), findsOneWidget);
    expect(find.text('승인'), findsNothing);
  });

  testWidgets('an empty inbox explains itself instead of showing nothing', (
    tester,
  ) async {
    await _pumpInbox(tester, _FakeConsultationRepository());

    expect(find.text('대기 중인 상담 요청이 없어요'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    await _pumpInbox(
      tester,
      _FakeConsultationRepository(
        failure: const NetworkError(message: '연결이 불안정해요'),
      ),
    );

    expect(find.text('상담 요청을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('the demo console never shows the 상담 요청 row', (tester) async {
    // 데모는 지금 그대로여야 한다 — 목 모드에서는 인박스 진입점이 아예 없다.
    await withWideSurface(tester, () async {
      await pumpTrainerApp(tester, token: 'demo-token');

      expect(
        find.text(navLabel(_ko, consultationsDestination.label)),
        findsNothing,
      );
      for (final destination in navDestinations) {
        expect(find.text(navLabel(_ko, destination.label)), findsWidgets);
      }
    });
  });

  testWidgets('상한에 닿은 인박스는 지난 요청을 이어 받는다 (#980)', (tester) async {
    // 서버는 한 쪽만 준다. 버튼이 없으면 트레이너는 첫 쪽 너머의 요청을 볼 길이 없고,
    // 목록이 잘렸다는 사실조차 화면에 남지 않는다.
    final repo = _FakeConsultationRepository(
      requests: <ConsultationRequest>[
        for (int i = 0; i < consultationPageSize; i++)
          _request(
            id: 'consult-new-$i',
            name: '최근 $i',
            createdAt: DateTime.utc(2026, 8, 19, 9).add(Duration(minutes: i)),
          ),
        _request(
          id: 'consult-old',
          name: '지난 요청',
          createdAt: DateTime.utc(2026, 8, 1, 9),
        ),
      ],
    );

    await _pumpInbox(tester, repo);

    // 첫 쪽에는 오래된 요청이 없다.
    expect(find.text('지난 요청'), findsNothing);

    final Finder more = find.byKey(
      const ValueKey<String>('consultation-load-more'),
    );
    await tester.scrollUntilVisible(more, 400);
    await tester.tap(more);
    await tester.pumpAndSettle();

    // 커서는 받은 쪽의 **가장 오래된** 요청이다 — 최신순 목록의 마지막 줄.
    expect(repo.cursors.single.$2, 'consult-new-0');
    await tester.scrollUntilVisible(find.text('지난 요청'), 400);
    expect(find.text('지난 요청'), findsOneWidget);
    // 다 받았으면 버튼은 사라진다 — 남아 있으면 눌러도 아무 일이 없다.
    expect(more, findsNothing);
  });

  testWidgets('the real-API console also keeps the separate row hidden', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      await pumpTrainerApp(
        tester,
        token: 'demo-token',
        extraOverrides: <Override>[
          consultationRepositoryProvider.overrideWithValue(
            _FakeConsultationRepository(),
          ),
        ],
      );

      expect(
        find.text(navLabel(_ko, consultationsDestination.label)),
        findsNothing,
      );
    });
  });
}
