/// 실 API E2E 공통 하네스 (회원 앱) — #637.
///
/// 트레이너 웹 쪽 `frontend/flutter_trainer/test_e2e/support/e2e_harness.dart` 와
/// 짝이다. 두 앱은 서로 다른 Dart 패키지라 한 프로세스에 함께 띄울 수 없어, 한
/// 시나리오를 단계로 쪼개 번갈아 실행한다.
///
/// ## 왜 `test_e2e/` 이고 `integration_test/` 가 아닌가
///
/// `flutter test integration_test/...` 는 실기기·브라우저 러너를 요구한다. 이 스위트는
/// 브라우저 없이 실 백엔드를 검증하므로 그 러너가 필요 없다. 대신
/// `IntegrationTestWidgetsFlutterBinding`(LiveBinding)을 써서 실제 위젯 트리와 실제
/// HTTP 를 얻는다 — `flutter test` 기본 바인딩은 FakeAsync 라 실 네트워크 응답이
/// 영원히 오지 않는다.
///
/// `test/` 밖에 둔 이유는 CI 다. `user-app-ci.yml` 의 `flutter test` 는 인자 없이 돌아
/// `test/` 만 훑는다. 백엔드가 없는 CI 에서 이 스위트가 딸려 돌면 무조건 깨진다.
library;

// `test_e2e/` 는 분석기가 테스트 디렉터리로 인정하는 경로(`test/`)가 아니다. 그래서
// 테스트에서만 쓰라고 표시된 플러그인 페이크 진입점이 경고로 잡힌다 — 이 파일은
// 테스트 전용이고 앱 코드에서 import 되지 않으므로 그 경고만 끈다.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/app/bootstrap.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/auth/presentation/pages/sign_in_page.dart';
import 'package:oncare/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:oncare/features/exercise/presentation/pages/exercise_page.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String memberEmail = 'minsu@oncare.com';
const String otherMemberEmail = 'jisu@oncare.com';
/// 픽스처 전용. 정원 1 짜리 경쟁용 슬롯을 여는 데만 쓴다.
const String trainerEmail = 'trainer@oncare.com';
const String trainerId = 'trainer-demo';
const String memberId = 'user-demo';
const String otherMemberId = 'user-jisu';
const String demoPassword = 'oncare123';

const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const String e2ePhase = String.fromEnvironment('E2E_PHASE');
const String e2eStateFile = String.fromEnvironment('E2E_STATE_FILE');

/// 단계 사이로 넘기는 값. **화면에서 읽을 수 없는 id 만** 여기 담는다.
///
/// 잔여 좌석처럼 검증 대상인 것은 담지 않는다 — 파일로 넘기면 서버가 아니라 앞
/// 단계의 기억을 검증하게 된다.
class E2eState {
  const E2eState(this.values);

  final Map<String, Object?> values;

  static File get _file {
    expect(e2eStateFile, isNotEmpty, reason: 'E2E_STATE_FILE 이 필요합니다.');
    return File(e2eStateFile);
  }

  static E2eState read() {
    final File file = _file;
    if (!file.existsSync()) return const E2eState(<String, Object?>{});
    // 러너가 실행 시작에 파일을 비운다 — 빈 파일은 "아직 아무 단계도 안 지났다" 다.
    final String raw = file.readAsStringSync().trim();
    if (raw.isEmpty) return const E2eState(<String, Object?>{});
    return E2eState(jsonDecode(raw) as Map<String, Object?>);
  }

  static void merge(Map<String, Object?> patch) {
    final Map<String, Object?> next = <String, Object?>{
      ...read().values,
      ...patch,
    };
    _file.writeAsStringSync(jsonEncode(next));
  }

  String require(String key) {
    final Object? value = values[key];
    expect(value, isA<String>(), reason: '앞 단계가 남긴 $key 가 없습니다.');
    return value! as String;
  }

  int requireInt(String key) {
    final Object? value = values[key];
    expect(value, isA<int>(), reason: '앞 단계가 남긴 $key 가 없습니다.');
    return value! as int;
  }
}

/// 화면을 거치지 않고 서버 상태를 직접 확인할 때 쓰는 클라이언트.
///
/// UI 검증을 대신하라고 있는 것이 아니다 — "화면에 보였다" 와 "서버에 저장됐다" 는
/// 다른 주장이고, 이슈의 완료 조건은 둘 다 요구한다.
class E2eApi {
  E2eApi._(this._dio, this._auth);

  final Dio _dio;
  final Options _auth;

  static Future<E2eApi> login(String email) async {
    final Dio dio = Dio(
      BaseOptions(
        // 분석 시점에는 dart-define 이 없어 이 상수가 '' 로 보인다. 기본값과 같다고
        // 잡히지만, 실행 시에는 러너가 넘긴 주소가 들어온다.
        // ignore: avoid_redundant_argument_values
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        // 4xx 를 예외가 아니라 응답으로 받는다 — 예외 케이스 검증이 상태 코드를
        // 직접 비교하기 때문이다.
        validateStatus: (int? status) => status != null && status < 500,
      ),
    );
    final Response<Map<String, dynamic>> res = await dio
        .post<Map<String, dynamic>>(
          '/auth/login',
          data: <String, String>{'username': email, 'password': demoPassword},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
    expect(res.statusCode, 200, reason: '$email 로그인 실패');
    return E2eApi._(
      dio,
      Options(
        headers: <String, String>{
          'Authorization': 'Bearer ${res.data!['access_token']}',
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      path,
      options: _auth,
    );
    return <Map<String, dynamic>>[
      for (final Object? row in res.data ?? const <Object?>[])
        row! as Map<String, dynamic>,
    ];
  }

  Future<List<Map<String, dynamic>>> myReservations() =>
      _list('/reservations/me');

  Future<List<Map<String, dynamic>>> trainerSlots() =>
      _list('/trainers/$trainerId/slots');

  /// 회원에게 보이는 슬롯 하나. 마감·과거 슬롯은 목록에서 빠질 수 있어 null 을 준다.
  Future<Map<String, dynamic>?> slotById(String id) async {
    for (final Map<String, dynamic> slot in await trainerSlots()) {
      if (slot['id'] == id) return slot;
    }
    return null;
  }

  Future<Map<String, dynamic>?> reservationForSlot(String slotId) async {
    for (final Map<String, dynamic> row in await myReservations()) {
      if (row['slot_id'] == slotId) return row;
    }
    return null;
  }

  /// 상태 코드까지 보고 싶을 때 쓰는 원시 예약 호출(예외 케이스 검증용).
  Future<Response<Object?>> reserveRaw(String slotId) => _dio.post<Object?>(
    '/reservations',
    data: <String, String>{'slot_id': slotId},
    options: _auth,
  );

  Future<Response<Object?>> cancelRaw(String reservationId) =>
      _dio.delete<Object?>('/reservations/$reservationId', options: _auth);

  // ── 채팅 (#639) ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> coachChat() => _list('/me/coach/chat');

  /// 본문이 [body] 인 메시지들. 재시도가 한 건으로 접히는지 셀 때 쓴다.
  Future<List<Map<String, dynamic>>> coachChatWithBody(String body) async =>
      <Map<String, dynamic>>[
        for (final Map<String, dynamic> row in await coachChat())
          if (row['body'] == body) row,
      ];

  /// 회원 발신. [clientRequestId] 를 같은 값으로 두 번 보내면 서버가 한 건으로
  /// 접어야 한다 — 앱의 재시도가 정확히 이 모양이다(#605).
  Future<Response<Object?>> sendAsMember(
    String text, {
    String? clientRequestId,
  }) => _dio.post<Object?>(
    '/me/coach/chat',
    data: <String, Object?>{
      'text': text,
      'client_request_id': ?clientRequestId,
    },
    options: _auth,
  );

  Future<int> memberUnread() async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/me/coach/chat/unread', options: _auth);
    return (res.data!['unread'] as num).toInt();
  }

  Future<void> markMemberRead() async {
    await _dio.post<Object?>('/me/coach/chat/read', options: _auth);
  }

  /// 픽스처용 — 트레이너 계정으로 회원 [memberId] 스레드에 답장한다.
  Future<Response<Object?>> sendAsTrainer(
    String memberId,
    String text, {
    String? clientRequestId,
  }) => _dio.post<Object?>(
    '/trainer/clients/$memberId/chat',
    data: <String, Object?>{
      'text': text,
      'client_request_id': ?clientRequestId,
    },
    options: _auth,
  );

  Future<List<Map<String, dynamic>>> trainerThread(String memberId) =>
      _list('/trainer/clients/$memberId/chat');

  /// 픽스처용 — 트레이너 계정으로 정원 [capacity] 짜리 슬롯을 연다.
  ///
  /// 마지막 좌석 경쟁은 **정원이 1 인 자리**에서만 정직하게 재현된다. 담당 회원 계정이
  /// 둘뿐이라, 정원 2 짜리 자리에서는 한쪽이 먼저 자리를 채우는 순간 다른 쪽의 두 번째
  /// 요청이 '중복' 으로 걸려 경쟁이 아니게 된다.
  Future<Map<String, dynamic>> createSlotAsTrainer({
    required DateTime startsAt,
    required int capacity,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/trainer/reservation-slots',
          data: <String, Object?>{
            'starts_at': startsAt.toUtc().toIso8601String(),
            'capacity': capacity,
          },
          options: _auth,
        );
    expect(res.statusCode, 201, reason: '경쟁 검증용 슬롯 생성 실패');
    return res.data!;
  }

  Future<void> closeSlotAsTrainer(String slotId) async {
    await _dio.delete<Object?>(
      '/trainer/reservation-slots/$slotId',
      options: _auth,
    );
  }
}

/// VM 에는 구현이 없는 플러그인을 채운다.
///
/// 이 셋이 없으면 앱은 부팅 도중 `MissingPluginException` 으로 멈춘다. 실제 기기에서는
/// 플랫폼이 제공하는 것들이라, 여기서만 대신 준다.
void installPluginFakes() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  FlutterSecureStorage.setMockInitialValues(<String, String>{});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async =>
            Directory.systemTemp.createTempSync('oncare_e2e').path,
      );
}

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  required String step,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    finder,
    findsWidgets,
    reason: '[$e2ePhase] $step 이(가) $timeout 안에 나타나지 않았습니다.',
  );
}

Future<void> pumpUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  required String step,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    finder,
    findsNothing,
    reason: '[$e2ePhase] $step 이(가) $timeout 안에 사라지지 않았습니다.',
  );
}

/// 목업으로 통과하는 것을 막는 관문.
///
/// 이슈의 완료 조건이 "mock repository 만으로 테스트가 통과하지 않는다" 라, 설정이
/// 목업으로 새면 조용히 초록불이 뜨는 대신 여기서 멈춘다.
void assertRealApiConfig() {
  final AppConfig config = AppConfig.fromEnvironment();
  expect(
    config.useMockApi,
    isFalse,
    reason: '--dart-define=USE_MOCK_API=false 로 실행해야 합니다.',
  );
  expect(apiBaseUrl, isNotEmpty, reason: 'API_BASE_URL 이 필요합니다.');
  expect(
    config.apiBaseUrl,
    apiBaseUrl,
    reason: '앱과 검증용 API 클라이언트가 같은 백엔드를 봐야 합니다.',
  );
}

/// 회원 앱의 기준 뷰포트. 기본 800×600 은 이 앱의 레이아웃과 어긋난다.
void useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 로그아웃 상태에서 앱을 새로 띄운다. 재시작·재로그인 검증도 이것을 다시 부른다.
Future<void> bootSignedOut(WidgetTester tester) async {
  useMobileViewport(tester);
  assertRealApiConfig();
  // 앞선 부팅이 남아 있으면 그 ProviderScope 의 세션이 그대로 살아 있어, 토큰을
  // 지워도 새 트리가 로그인 화면 대신 대시보드로 간다. 재시작 검증이 조용히
  // "로그인된 채로 계속" 을 통과시키지 않도록 먼저 트리를 비운다.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await const FlutterSecureStorage().deleteAll();
  await bootstrap();
  await pumpUntil(tester, find.byType(SignInPage), step: '로그인 화면');
}

Future<void> loginAsMember(WidgetTester tester, {String? email}) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey<String>('member-login-email')),
      matching: find.byType(TextField),
    ),
    email ?? memberEmail,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey<String>('member-login-password')),
      matching: find.byType(TextField),
    ),
    demoPassword,
  );
  await tester.tap(find.byKey(const ValueKey<String>('member-login-submit')));
  await pumpUntil(tester, find.byType(DashboardPage), step: '회원 로그인');
}

/// 슬롯 하나를 골라 예약 확정 버튼이 뜬 상태로 만든다.
///
/// 칩은 **토글**이라(같은 칩을 다시 누르면 선택이 풀린다) 한 번 누르는 것으로는
/// "선택됨" 을 보장할 수 없다. 앞선 조작이 이미 이 칩을 골라 둔 상태였다면 그 한 번이
/// 선택을 푸는 쪽으로 작동한다. 그래서 결과(확정 버튼)를 보고 필요하면 한 번 더 누른다.
Future<Finder> selectSlotForReserve(WidgetTester tester, String slotId) async {
  final Finder chip = find.byKey(ValueKey<String>('slot-chip-$slotId'));
  final Finder confirm = find.byKey(const ValueKey<String>('reserve-confirm'));
  await pumpUntil(tester, chip, step: '슬롯 칩');

  for (int attempt = 0; attempt < 3; attempt++) {
    // 목록이 길면(내 예약이 쌓였거나 자리가 많으면) 칩이 화면 밖으로 밀린다. 그 상태의
    // `tap` 은 예외 없이 **엉뚱한 곳을 누르고** 조용히 지나간다.
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pump();
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
    while (confirm.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (confirm.evaluate().isNotEmpty) return confirm;
  }
  fail('[$e2ePhase] 슬롯 $slotId 를 골랐는데 예약 확정 버튼이 뜨지 않았습니다.');
}

/// 운동 탭 헤더 → 담당 트레이너 채팅 화면.
///
/// 헤더 버튼은 모든 메인 탭에 같은 모양으로 있고 담당 트레이너가 있어야 눌린다.
Future<void> openTrainerChat(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('nav-exercise')));
  await pumpUntil(tester, find.byType(ExercisePage), step: '운동 화면');
  final Finder button = find.byKey(const Key('trainerChatHeaderButton'));
  await pumpUntil(tester, button, step: '트레이너 채팅 버튼');

  // 버튼은 담당 트레이너가 **로드되기 전까지** onTap 이 null 이다. 그 사이의 탭은
  // 예외 없이 아무 일도 일으키지 않으므로, 화면이 열릴 때까지 다시 누른다.
  final Finder page = find.byType(TrainerChatPage);
  for (int attempt = 0; attempt < 10 && page.evaluate().isEmpty; attempt++) {
    await tester.tap(button);
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 3));
    while (page.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  expect(page, findsWidgets, reason: '[$e2ePhase] 트레이너 채팅 화면이 열리지 않았습니다.');
}

/// 운동 탭 → 헬스장 서브탭. 담당 트레이너의 예약 패널이 있는 자리다.
Future<void> openGymTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('nav-exercise')));
  await pumpUntil(tester, find.byType(ExercisePage), step: '운동 화면');
  await tester.tap(find.byKey(const ValueKey<String>('exercise-subtab-1')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
