// Boot smoke test — the trainer app now starts on the login screen.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/app.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/storage/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('boots to the trainer login screen', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: Environment.dev,
              apiBaseUrl: 'http://localhost/v1',
              useMockApi: true,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const OncareTrainerApp(locale: Locale('ko')),
      ),
    );
    await tester.pumpAndSettle();

    // The login screen shows the On-Care logo (image, not a title) plus
    // the login / sign-up / demo entry points.
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('계정 만들기'), findsOneWidget);
    expect(find.text('로그인 없이 데모 둘러보기'), findsOneWidget);
  });
}
