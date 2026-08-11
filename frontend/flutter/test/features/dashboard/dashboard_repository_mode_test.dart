import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/core/storage/app_database.dart';
import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/dashboard/data/repositories/dio_dashboard_repository.dart';
import 'package:oncare/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// 이 분기가 두 번 유실되어 데모 홈이 "대시보드 정보를 불러오지 못했어요" 만
/// 띄운 적이 있다. my_health 의 같은 이름 테스트와 짝을 이루는 회귀 방지용.
void main() {
  // 목업 대시보드가 식단 저장소를 통해 drift 를 타므로(#616) 바인딩과 인메모리
  // DB 가 필요하다. 파일 DB 를 열면 테스트가 기기 저장소에 의존하게 된다.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dashboardRepositoryProvider 모드 분기', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    ProviderContainer makeContainer({required bool useMockApi}) {
      final container = ProviderContainer(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: Environment.dev,
              apiBaseUrl: 'https://dev.api.test/v1',
              useMockApi: useMockApi,
            ),
          ),
          // Dio 저장소 경로는 dioProvider → appLogger 를 타므로 조용한 로거로 오버라이드.
          appLoggerProvider.overrideWithValue(Logger(level: Level.off)),
          appDatabaseProvider.overrideWithValue(db),
          accountRepositoryProvider.overrideWithValue(MockAccountRepository()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('USE_MOCK_API=false 면 Dio 저장소를 쓴다', () {
      final container = makeContainer(useMockApi: false);
      expect(
        container.read(dashboardRepositoryProvider),
        isA<DioDashboardRepository>(),
      );
    });

    test('USE_MOCK_API=true 면 Mock 저장소를 쓴다', () {
      final container = makeContainer(useMockApi: true);
      expect(
        container.read(dashboardRepositoryProvider),
        isA<MockDashboardRepository>(),
      );
    });

    test('데모 기본값(USE_MOCK_API 미지정)은 Mock 저장소다', () {
      final container = ProviderContainer(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
          appLoggerProvider.overrideWithValue(Logger(level: Level.off)),
          appDatabaseProvider.overrideWithValue(db),
          accountRepositoryProvider.overrideWithValue(MockAccountRepository()),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(dashboardRepositoryProvider),
        isA<MockDashboardRepository>(),
      );
    });
  });
}
