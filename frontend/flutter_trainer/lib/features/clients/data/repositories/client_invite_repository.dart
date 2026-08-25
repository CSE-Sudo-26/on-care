import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/demo_member_directory.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_invite.dart';

/// 트레이너가 회원 ID로 회원을 찾아 담당으로 연결하는 흐름. (#919)
///
/// 지금까지 고객이 생기는 경로는 회원이 보낸 상담 요청을 트레이너가 수락하는
/// 하나뿐이라, 센터에서 먼저 등록·결제를 마친 회원을 콘솔에서 잡을 수 없었다.
/// 트레이너가 성별·나이 같은 인적 사항을 직접 입력해 새 고객을 만드는 대신,
/// 회원이 이미 자기 앱에 등록해 둔 프로필을 회원 ID로 찾아 연결한다 — 신체
/// 정보의 source of truth는 언제나 회원 본인이다.
///
/// **실 API 에서 [invite] 가 만드는 것은 요청이지 등록이 아니다.** 담당 관계는
/// 상대의 식단·건강 기록을 여는 권한이라, 회원이 회원 앱에서 수락해야 명단에
/// 나타난다 — [connectsImmediately] 가 `false`. 데모는 답할 회원 백엔드가
/// 없으므로 회원 ID가 확인되면 그 자리에서 연결한다 — [connectsImmediately]
/// 가 `true`.
///
/// 두 구현이 [clientInviteRepositoryProvider] 뒤에 있고 [AppConfig.useMockApi]
/// 로 갈린다.
abstract interface class ClientInviteRepository {
  /// 이 빌드에서 회원 ID로 회원을 찾아 연결할 수 있는가.
  bool get supportsInvites;

  /// [invite] 가 호출 즉시 담당 링크를 만드는가(데모), 아니면 회원의 수락을
  /// 기다리는 요청만 보내는가(실 API). 화면 문구·성공 처리가 이 값으로
  /// 갈린다.
  bool get connectsImmediately;

  /// 회원 ID(`User.id`) **완전 일치**로 회원을 찾는다. 없으면 [NotFoundError].
  ///
  /// 이메일도 성별·나이도 아니다 — 회원이 자기 앱 MY 탭에서 확인할 수 있는
  /// 그 계정의 고유 식별자다.
  Future<MemberLookup> lookup(String memberId);

  /// 회원을 담당으로 연결한다. 이미 담당이 있거나 이미 보냈으면
  /// [ValidationError](서버 문구를 그대로 싣는다 — 어느 쪽인지는 서버만 안다).
  Future<ClientInvite> invite(String memberId, {String? message});

  /// 내가 보낸 요청. `status` 는 `pending` 또는 `all`. [connectsImmediately] 가
  /// `true` 인 소스는 대기할 요청이 없으므로 항상 빈 목록이다.
  Future<List<ClientInvite>> listSent({String status = 'pending'});

  /// 보낸 요청을 거둬들인다. [connectsImmediately] 가 `true` 인 소스에는
  /// 거둘 대기 요청이 없다.
  Future<void> cancel(String inviteId);
}

/// 데모: 답할 회원 백엔드가 없는 대신, 회원 ID가 확인되면 그 자리에서
/// 로컬 로스터에 연결한다 — [demoProspectiveMembers] 가 "아직 연결되지 않은
/// 회원", [demoAlreadyLinkedMemberId] 가 "이미 연결된 회원" 시나리오다.
class DemoClientInviteRepository implements ClientInviteRepository {
  DemoClientInviteRepository(this._db);

  final AppDatabase _db;

  @override
  bool get supportsInvites => true;

  @override
  bool get connectsImmediately => true;

  @override
  Future<MemberLookup> lookup(String memberId) async {
    final String normalized = memberId.trim().toLowerCase();
    if (normalized.isEmpty) throw const NotFoundError();
    final DateTime now = nowKst();

    if (normalized == demoAlreadyLinkedMemberId) {
      final row =
          await (_db.select(_db.trainerClients)
                ..where((t) => t.id.equals(demoAlreadyLinkedClientId)))
              .getSingleOrNull();
      if (row != null) return _linkedLookup(normalized, row.name);
    }

    final prospect = findDemoProspectiveMemberById(normalized);
    if (prospect == null) throw const NotFoundError();

    // 이번 데모 세션에서 이미 연결한 적이 있으면(같은 회원 ID를 다시 찾는
    // 경우) "이미 연결됨" 으로 답한다 — 중복 연결을 여기서부터 막는다.
    final existing = await (_db.select(
      _db.trainerClients,
    )..where((t) => t.id.equals(prospect.id))).getSingleOrNull();
    if (existing != null) return _linkedLookup(existing.id, existing.name);

    return MemberLookup(
      memberId: prospect.id,
      name: prospect.name,
      hasTrainer: false,
      coachedByMe: false,
      invitePending: false,
      // 회원이 이미 자기 앱에 등록해 둔 값 — 트레이너가 등록 전에 "이 사람이
      // 맞는지" 확인할 수 있게 데모에서만 함께 실어 준다.
      gender: prospect.gender,
      age: prospect.ageOn(now),
      goal: prospect.goal,
    );
  }

  MemberLookup _linkedLookup(String memberId, String name) => MemberLookup(
    memberId: memberId,
    name: name,
    hasTrainer: true,
    coachedByMe: true,
    invitePending: false,
  );

  @override
  Future<ClientInvite> invite(String memberId, {String? message}) async {
    final prospect = findDemoProspectiveMemberById(memberId);
    if (prospect == null) throw const NotFoundError();

    final DateTime now = nowKst();
    try {
      await _db
          .into(_db.trainerClients)
          .insert(
            TrainerClientsCompanion.insert(
              id: prospect.id,
              name: prospect.name,
              avatar: String.fromCharCode(prospect.name.runes.first),
              goal: prospect.goal,
              lastMessage: '아직 대화가 없어요',
              lastTime: '-',
              active: const Value(true),
              caloriesToday: 0,
              sodiumMg: 0,
              sugarG: 0,
              lastRoutine: '-',
              weekCompletionJson: '[0,0,0,0,0,0,0]',
              // 회원이 이미 등록해 둔 실제 값 — 트레이너가 지금 입력하는
              // 값이 아니다.
              gender: Value(prospect.gender),
              age: Value(prospect.ageOn(now)),
              sortOrder: Value(now.millisecondsSinceEpoch),
            ),
          );
    } catch (_) {
      // 같은 id 로 이미 연결된 행이 있는 경우 — 두 번 연결이 아니라 "이미
      // 연결됨" 으로 읽혀야 한다. lookup 이 먼저 걸러내므로 정상 경로에서는
      // 일어나지 않고, 방어적으로만 남긴다.
      throw const ValidationError();
    }

    return ClientInvite(
      id: 'demo-link-${prospect.id}',
      memberId: prospect.id,
      memberName: prospect.name,
      memberEmail: '',
      status: ClientInviteStatus.accepted,
      createdAt: now,
    );
  }

  @override
  Future<List<ClientInvite>> listSent({String status = 'pending'}) async =>
      const <ClientInvite>[];

  @override
  Future<void> cancel(String inviteId) async {}
}

/// 실 백엔드 구현.
class DioClientInviteRepository implements ClientInviteRepository {
  const DioClientInviteRepository(this._dio);

  final Dio _dio;

  @override
  // Production request/accept/reject remains a follow-up. For now the
  // client-registration entry point is exposed only by the demo source.
  bool get supportsInvites => false;

  @override
  bool get connectsImmediately => false;

  @override
  Future<MemberLookup> lookup(String memberId) async {
    try {
      final res = await _dio.get<Map<String, Object?>>(
        '/trainer/member-lookup',
        queryParameters: <String, Object?>{'member_id': memberId.trim()},
      );
      final data = res.data;
      if (data == null) throw const ServerError();
      return MemberLookup.fromJson(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) throw const NotFoundError();
      if (status == 422 || status == 400) {
        throw ValidationError(message: _detail(e));
      }
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<ClientInvite> invite(String memberId, {String? message}) async {
    try {
      final res = await _dio.post<Map<String, Object?>>(
        '/trainer/client-invites',
        data: <String, Object?>{
          'member_id': memberId,
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
        },
      );
      final data = res.data;
      if (data == null) throw const ServerError();
      return ClientInvite.fromJson(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) throw const NotFoundError();
      // 409(이미 담당 중·이미 보냄)와 422(트레이너 계정)는 서버가 이유를 문장으로
      // 돌려준다. 그 문장이 트레이너가 다음에 할 일을 정하는 근거라 그대로 싣는다.
      if (status == 409 || status == 422 || status == 400) {
        throw ValidationError(message: _detail(e));
      }
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<List<ClientInvite>> listSent({String status = 'pending'}) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/trainer/client-invites',
        queryParameters: <String, Object?>{'status': status},
      );
      return (res.data ?? const <dynamic>[])
          .whereType<Map<String, Object?>>()
          .map(ClientInvite.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<void> cancel(String inviteId) async {
    try {
      await _dio.delete<Map<String, Object?>>(
        '/trainer/client-invites/${Uri.encodeComponent(inviteId)}',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) throw const NotFoundError();
      if (status == 409) throw ValidationError(message: _detail(e));
      throw AppError.fromDio(e);
    }
  }

  String? _detail(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return null;
    final detail = data['detail'];
    return detail is String ? detail : null;
  }
}

/// 현재 모드에 맞는 저장소.
final clientInviteRepositoryProvider = Provider<ClientInviteRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return DemoClientInviteRepository(ref.watch(appDatabaseProvider));
  }
  return DioClientInviteRepository(ref.watch(dioProvider));
}, name: 'clientInviteRepository');

/// 고객 탭에 '회원 추가' 진입점을 노출할지.
final clientInvitesEnabledProvider = Provider<bool>(
  (ref) => ref.watch(clientInviteRepositoryProvider).supportsInvites,
  name: 'clientInvitesEnabled',
);

/// 내가 보낸 대기 중인 요청. 보내기·취소 뒤에는 invalidate 한다.
final pendingClientInvitesProvider =
    FutureProvider.autoDispose<List<ClientInvite>>(
      (ref) => ref.watch(clientInviteRepositoryProvider).listSent(),
      name: 'pendingClientInvites',
    );
