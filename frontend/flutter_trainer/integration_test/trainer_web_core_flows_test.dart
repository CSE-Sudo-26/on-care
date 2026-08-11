import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:oncare_trainer/app/bootstrap.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/app/shell/app_shell.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/auth/presentation/pages/trainer_sign_in_page.dart';
import 'package:oncare_trainer/features/clients/presentation/pages/clients_page.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/chat_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/diet_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/workout_view.dart';
import 'package:oncare_trainer/features/consultations/presentation/pages/consultations_page.dart';
import 'package:oncare_trainer/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:oncare_trainer/features/schedule/presentation/pages/schedule_page.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

const String _trainerEmail = 'trainer@oncare.com';
const String _memberEmail = 'jisu@oncare.com';
const String _password = 'oncare123';
const String _clientId = 'user-demo';
const String _consultationMemberName = '이지수';
const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  required String step,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = tester.binding.clock.now().add(timeout);
  while (finder.evaluate().isEmpty &&
      tester.binding.clock.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets, reason: '$step timed out after $timeout.');
}

String _location(WidgetTester tester) {
  final context = tester.element(find.byType(AppShell));
  return GoRouter.of(context).routeInformationProvider.value.uri.toString();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(AppShell)));

bool _isSelectedSegment(Finder label) => find
    .ancestor(of: label, matching: find.byType(Semantics))
    .evaluate()
    .map((element) => (element.widget as Semantics).properties.selected)
    .contains(true);

Future<void> _bootSignedOut(WidgetTester tester) async {
  final config = AppConfig.fromEnvironment();
  expect(
    config.useMockApi,
    isFalse,
    reason: 'Run with --dart-define=USE_MOCK_API=false.',
  );
  expect(
    config.apiBaseUrl,
    _apiBaseUrl,
    reason: 'The app and E2E fixture API must use the same API_BASE_URL.',
  );
  expect(_apiBaseUrl, isNotEmpty);

  await const FlutterSecureStorage().deleteAll();
  await bootstrap();
  await _pumpUntil(
    tester,
    find.byType(TrainerSignInPage),
    step: 'login screen boot',
  );
}

Future<void> _loginThroughUi(WidgetTester tester) async {
  final email = find.descendant(
    of: find.byKey(const ValueKey<String>('trainer-login-email')),
    matching: find.byType(TextField),
  );
  final password = find.descendant(
    of: find.byKey(const ValueKey<String>('trainer-login-password')),
    matching: find.byType(TextField),
  );
  await tester.enterText(email, _trainerEmail);
  await tester.enterText(password, _password);
  await tester.tap(find.byKey(const ValueKey<String>('trainer-login-submit')));
  await _pumpUntil(tester, find.byType(DashboardPage), step: 'trainer login');
  expect(_location(tester), AppRoutes.dashboard);
}

Future<void> _openSidebar(WidgetTester tester, String route) async {
  await tester.tap(find.byKey(ValueKey<String>('sidebar-$route')));
  await tester.pump();
}

Future<void> _openClient(WidgetTester tester) async {
  await _openSidebar(tester, AppRoutes.clients);
  await _pumpUntil(
    tester,
    find.byType(ClientsPage),
    step: 'clients navigation',
  );
  await _pumpUntil(
    tester,
    find.byKey(const ValueKey<String>('client-$_clientId')),
    step: 'seed client load',
  );
  await tester.tap(find.byKey(const ValueKey<String>('client-$_clientId')));
  await _pumpUntil(tester, find.byType(DietView), step: 'client diet section');
  expect(_location(tester), AppRoutes.clientDetail(_clientId));
}

Future<void> _restartAtCurrentBrowserLocation(WidgetTester tester) async {
  // integration_test exposes no WebDriver refresh command. Disposing and
  // booting the production root at the unchanged browser URL exercises the
  // two app contracts that a refresh relies on: secure-session restoration
  // and GoRouter's platform-location restoration.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await bootstrap();
}

String _ymd(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

Future<String> _ensurePendingConsultation() async {
  final dio = Dio(BaseOptions(baseUrl: _apiBaseUrl));
  final login = await dio.post<Map<String, dynamic>>(
    '/auth/login',
    data: <String, String>{'username': _memberEmail, 'password': _password},
    options: Options(contentType: Headers.formUrlEncodedContentType),
  );
  final token = login.data!['access_token'] as String;
  final auth = Options(
    headers: <String, String>{'Authorization': 'Bearer $token'},
  );
  final mine = await dio.get<List<dynamic>>('/consultations/me', options: auth);
  for (final item in mine.data ?? const <dynamic>[]) {
    final row = item as Map<String, dynamic>;
    if (row['status'] == 'pending' && row['trainer_id'] == 'trainer-demo') {
      return row['id'] as String;
    }
  }

  final preferredDate = DateTime.now().add(const Duration(days: 2));
  final created = await dio.post<Map<String, dynamic>>(
    '/consultations',
    options: auth,
    data: <String, Object?>{
      'target_type': 'trainer',
      'trainer_id': 'trainer-demo',
      'exercise_goal': 'fitness',
      'health_purpose_type': 'general',
      'health_purpose_detail': null,
      'preferred_date': _ymd(preferredDate),
      'preferred_time_slot': 'evening',
      'message': '#624 브라우저 E2E 상담 요청',
    },
  );
  return created.data!['id'] as String;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login, client sections, and refresh-equivalent restore', (
    tester,
  ) async {
    await _bootSignedOut(tester);
    await _loginThroughUi(tester);
    await _openClient(tester);

    final tabs = find.byKey(const ValueKey<String>('client-detail-sub-tabs'));
    final l = _l10n(tester);
    await tester.tap(
      find.descendant(of: tabs, matching: find.text(l.clientTabWorkout)),
    );
    await _pumpUntil(
      tester,
      find.byType(WorkoutView),
      step: 'client workout section',
    );
    expect(
      _location(tester),
      AppRoutes.clientDetail(_clientId, section: 'workout'),
      reason: 'customer context lost in workout section',
    );
    await tester.tap(find.byKey(const ValueKey<String>('client-chat-button')));
    await _pumpUntil(
      tester,
      find.byType(ChatView),
      step: 'client chat section',
    );
    final expectedLocation = AppRoutes.clientDetail(_clientId, section: 'chat');
    expect(_location(tester), expectedLocation);

    await _restartAtCurrentBrowserLocation(tester);
    await _pumpUntil(
      tester,
      find.byType(ChatView),
      step: 'session and client route restore',
    );
    expect(find.byType(TrainerSignInPage), findsNothing);
    expect(_location(tester), expectedLocation);
  });

  testWidgets('chat message is sent once and survives page re-entry', (
    tester,
  ) async {
    await _bootSignedOut(tester);
    await _loginThroughUi(tester);
    await _openClient(tester);
    await tester.tap(find.byKey(const ValueKey<String>('client-chat-button')));
    await _pumpUntil(tester, find.byType(ChatView), step: 'chat navigation');

    final message = '#624 E2E ${DateTime.now().toUtc().toIso8601String()}';
    await tester.enterText(
      find.byKey(const ValueKey<String>('client-chat-input')),
      message,
    );
    await tester.tap(find.byKey(const ValueKey<String>('client-chat-send')));
    await _pumpUntil(tester, find.text(message), step: 'chat send result');
    expect(find.text(message), findsOneWidget);

    await _restartAtCurrentBrowserLocation(tester);
    await _pumpUntil(
      tester,
      find.byType(ChatView),
      step: 'chat server refetch after page re-entry',
    );
    expect(
      _location(tester),
      AppRoutes.clientDetail(_clientId, section: 'chat'),
    );
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('pending consultation is rejected through its dialog', (
    tester,
  ) async {
    final consultationId = await _ensurePendingConsultation();
    await _bootSignedOut(tester);
    await _loginThroughUi(tester);
    await _openSidebar(tester, AppRoutes.consultations);
    await _pumpUntil(
      tester,
      find.byType(ConsultationsPage),
      step: 'consultation inbox navigation',
    );

    final requestKey = ValueKey<String>('consultation-$consultationId');
    await _pumpUntil(
      tester,
      find.byKey(requestKey),
      step: 'prepared pending consultation',
    );
    expect(find.text(_consultationMemberName), findsWidgets);
    await tester.tap(
      find.byKey(ValueKey<String>('consultation-reject-$consultationId')),
    );
    await _pumpUntil(
      tester,
      find.byType(AlertDialog),
      step: 'consultation rejection dialog',
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '#624 E2E 반복 실행 확인',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('consultation-reject-confirm')),
    );
    await _pumpUntil(
      tester,
      find.text(_l10n(tester).consultRejected),
      step: 'consultation rejection result',
    );
    await _pumpUntil(
      tester,
      find.text(_l10n(tester).consultShowAll),
      step: 'pending consultation list refresh',
    );
    expect(find.byKey(requestKey), findsNothing);

    await tester.tap(find.text(_l10n(tester).consultShowAll));
    await _pumpUntil(
      tester,
      find.byKey(requestKey),
      step: 'rejected consultation history',
    );
    expect(
      find.text(
        _l10n(tester).consultStatusRejectedWithNote('#624 E2E 반복 실행 확인'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('schedule view/date selection opens the booked client', (
    tester,
  ) async {
    await _bootSignedOut(tester);
    await _loginThroughUi(tester);
    await _openSidebar(tester, AppRoutes.schedule);
    await _pumpUntil(
      tester,
      find.byType(SchedulePage),
      step: 'schedule navigation',
    );

    final l = _l10n(tester);
    await tester.tap(find.text(l.schedViewWeek));
    await tester.pump();
    expect(_location(tester), contains('v=week'));
    expect(
      _isSelectedSegment(find.text(l.schedViewWeek)),
      isTrue,
      reason: 'weekly schedule display and URL diverged',
    );
    await tester.tap(find.text(l.schedViewDay));
    await tester.pump();
    expect(_location(tester), contains('v=day'));
    expect(
      _isSelectedSegment(find.text(l.schedViewDay)),
      isTrue,
      reason: 'daily schedule display and URL diverged',
    );

    final today = DateTime.now();
    final anotherDay = today.add(const Duration(days: 1));
    await tester.tap(
      find.byKey(ValueKey<String>('schedule-day-${_ymd(anotherDay)}')),
    );
    await tester.pump();
    expect(_location(tester), contains('d=${_ymd(anotherDay)}'));
    final selectedDay = find.descendant(
      of: find.byKey(ValueKey<String>('schedule-day-${_ymd(anotherDay)}')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == AppColors.primary,
      ),
    );
    expect(
      selectedDay,
      findsOneWidget,
      reason: 'selected schedule date and URL diverged',
    );
    await tester.tap(
      find.byKey(ValueKey<String>('schedule-day-${_ymd(today)}')),
    );
    await _pumpUntil(
      tester,
      find.text('김민수'),
      step: 'booked client schedule row',
    );

    await tester.tap(
      find.ancestor(of: find.text('김민수'), matching: find.byType(InkWell)).first,
    );
    await _pumpUntil(
      tester,
      find.byKey(const ValueKey<String>('session-chat-chip')),
      step: 'booked client actions',
    );
    await tester.tap(find.byKey(const ValueKey<String>('session-chat-chip')));
    await _pumpUntil(
      tester,
      find.byType(ChatView),
      step: 'booked client detail navigation',
    );
    expect(
      _location(tester),
      AppRoutes.clientDetail(_clientId, section: 'chat'),
    );
  });
}
