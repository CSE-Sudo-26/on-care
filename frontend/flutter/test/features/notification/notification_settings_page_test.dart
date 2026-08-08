import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/storage/prefs_store.dart';
import 'package:oncare/features/my_health/presentation/widgets/my_flows.dart';
import 'package:oncare/features/notification/data/repositories/notification_settings_repository.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 데모/목 설정 — 화면이 기기 저장을 쓰는 쪽.
const AppConfig _demo = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

/// 저장 요청을 기록하고, 실패시킬 수도 있는 페이크.
class _FakeRepository implements NotificationSettingsRepository {
  _FakeRepository({Map<String, bool>? initial, this.failOnWrite = false})
    : _values =
          initial ??
          <String, bool>{
            for (final NotificationSettingItem item
                in kNotificationSettingItems)
              item.key: item.fallback,
          };

  final Map<String, bool> _values;
  final bool failOnWrite;
  final List<(String, bool)> writes = <(String, bool)>[];

  @override
  Future<Map<String, bool>> fetch() async => Map<String, bool>.from(_values);

  @override
  Future<void> setValue(String key, bool value) async {
    if (failOnWrite) throw StateError('write failed');
    writes.add((key, value));
    _values[key] = value;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  NotificationSettingsRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(_demo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (repository != null)
          notificationSettingsRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotificationSettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('토글 5개가 그대로 그려진다', (WidgetTester tester) async {
    // 데모 화면은 지금과 같아야 한다 — 항목 수와 기본 상태가 바뀌면 안 된다.
    await _pump(tester);

    expect(find.byType(Switch), findsNWidgets(kNotificationSettingItems.length));
  });

  testWidgets('저장된 값이 화면에 반영된다', (WidgetTester tester) async {
    final repo = _FakeRepository(
      initial: <String, bool>{
        for (final NotificationSettingItem item in kNotificationSettingItems)
          item.key: item.key == 'notif_trainer_message'
              ? false
              : item.fallback,
      },
    );

    await _pump(tester, repository: repo);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    final index = kNotificationSettingItems.indexWhere(
      (NotificationSettingItem item) => item.key == 'notif_trainer_message',
    );
    expect(switches[index].value, isFalse);
  });

  testWidgets('토글하면 저장소에 값을 넘긴다', (WidgetTester tester) async {
    final repo = _FakeRepository();
    await _pump(tester, repository: repo);

    // 주간 리포트는 기본 꺼짐이라 켜는 방향으로 눌린다.
    final index = kNotificationSettingItems.indexWhere(
      (NotificationSettingItem item) => item.key == 'notif_weekly_report',
    );
    await tester.tap(find.byType(Switch).at(index));
    await tester.pumpAndSettle();

    expect(repo.writes, <(String, bool)>[('notif_weekly_report', true)]);
  });

  testWidgets('저장에 실패하면 원래 값으로 되돌리고 알린다', (
    WidgetTester tester,
  ) async {
    // 켜진 줄 알았는데 알림이 안 오는 상태가 가장 나쁘다.
    final repo = _FakeRepository(failOnWrite: true);
    await _pump(tester, repository: repo);
    final index = kNotificationSettingItems.indexWhere(
      (NotificationSettingItem item) => item.key == 'notif_weekly_report',
    );

    await tester.tap(find.byType(Switch).at(index));
    await tester.pumpAndSettle();

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[index].value, isFalse);
    expect(find.text('알림 설정을 저장하지 못했어요'), findsOneWidget);
  });

  testWidgets('데모는 기기 저장을 그대로 쓴다', (WidgetTester tester) async {
    // repository override 없이 — 데모 설정이 로컬 저장소를 고르는지 확인한다.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'notif_diet_log': false,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_demo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final index = kNotificationSettingItems.indexWhere(
      (NotificationSettingItem item) => item.key == 'notif_diet_log',
    );
    expect(
      tester.widgetList<Switch>(find.byType(Switch)).toList()[index].value,
      isFalse,
    );
  });
}
