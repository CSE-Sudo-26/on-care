import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_invite.dart';

/// 트레이너가 회원에게 보내는 담당 요청. (#919)
///
/// 지금까지 고객이 생기는 경로는 회원이 보낸 상담 요청을 트레이너가 수락하는
/// 하나뿐이라, 센터에서 먼저 등록·결제를 마친 회원을 콘솔에서 잡을 수 없었다.
///
/// **여기서 보내는 것은 요청이지 등록이 아니다.** 담당 관계는 상대의 식단·건강
/// 기록을 여는 권한이라, 회원이 회원 앱에서 수락해야 명단에 나타난다. 화면도
/// 그렇게 말해야 한다 — 요청을 보낸 트레이너가 고객이 생겼다고 읽으면, 오지
/// 않는 회원을 기다리게 된다.
///
/// 두 구현이 [clientInviteRepositoryProvider] 뒤에 있고 [AppConfig.useMockApi]
/// 로 갈린다.
abstract interface class ClientInviteRepository {
  /// 이 빌드에서 담당 요청을 보낼 수 있는가. 데모에서는 진입점을 감춘다 —
  /// 요청을 받을 회원 백엔드가 없어, 보내도 아무 데도 닿지 않는다.
  bool get supportsInvites;

  /// 이메일 **완전 일치**로 회원을 찾는다. 없으면 [NotFoundError].
  Future<MemberLookup> lookup(String email);

  /// 담당 요청을 보낸다. 이미 담당이 있거나 이미 보냈으면 [ValidationError]
  /// (서버 문구를 그대로 싣는다 — 어느 쪽인지는 서버만 안다).
  Future<ClientInvite> invite(String memberId, {String? message});

  /// 내가 보낸 요청. `status` 는 `pending` 또는 `all`.
  Future<List<ClientInvite>> listSent({String status = 'pending'});

  /// 보낸 요청을 거둬들인다.
  Future<void> cancel(String inviteId);
}

/// 데모: 요청을 받을 회원 백엔드가 없다.
///
/// 읽기는 빈 결과로 성공시켜 딥링크나 테스트가 오류가 아닌 빈 화면을 보게 하고,
/// 쓰기는 조용히 성공시키지 않는다 — 데모에서 눌러 성공한 것처럼 보이면 실제로
/// 회원에게 닿았다고 읽힌다.
class DemoClientInviteRepository implements ClientInviteRepository {
  const DemoClientInviteRepository();

  @override
  bool get supportsInvites => false;

  @override
  Future<MemberLookup> lookup(String email) async =>
      throw const NotFoundError();

  @override
  Future<ClientInvite> invite(String memberId, {String? message}) async =>
      throw const ValidationError();

  @override
  Future<List<ClientInvite>> listSent({String status = 'pending'}) async =>
      const <ClientInvite>[];

  @override
  Future<void> cancel(String inviteId) async => throw const ValidationError();
}

/// 실 백엔드 구현.
class DioClientInviteRepository implements ClientInviteRepository {
  const DioClientInviteRepository(this._dio);

  final Dio _dio;

  @override
  bool get supportsInvites => true;

  @override
  Future<MemberLookup> lookup(String email) async {
    try {
      final res = await _dio.get<Map<String, Object?>>(
        '/trainer/member-lookup',
        queryParameters: <String, Object?>{'email': email.trim()},
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
    return const DemoClientInviteRepository();
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
