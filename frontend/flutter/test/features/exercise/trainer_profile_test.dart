import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

const Gym _withProfile = Gym(
  id: 'gym-profile',
  name: '프로필 헬스장',
  address: '서울 서대문구 테스트로 1',
  distanceKm: 0.4,
  rating: 4.6,
  tags: <String>['PT'],
  trainerName: '김테스트',
  trainerRole: '퍼스널 트레이너',
  trainerCareer: '7년',
  trainerIntro: '혈압 관리와 체중 감량을 주로 담당합니다.',
  trainerCertifications: <String>['생활스포츠지도사 2급', '스포츠 영양사'],
);

/// 이름·직함만 있고 소개/경력/자격증이 없는 트레이너.
const Gym _withoutProfile = Gym(
  id: 'gym-bare',
  name: '기본 헬스장',
  address: '서울 서대문구 테스트로 2',
  distanceKm: 0.9,
  rating: 4.1,
  tags: <String>[],
  trainerName: '박테스트',
  trainerRole: '퍼스널 트레이너',
);

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

void main() {
  Future<void> pumpTrainerDetail(WidgetTester tester, Gym gym) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = buildAppRouter(config: _config);
    addTearDown(router.dispose);
    router.go(AppRoutes.trainerDetailPath(gym.id));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          nearbyGymsProvider.overrideWith((ref) async => <Gym>[gym]),
          myGymProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('트레이너 상세가 소개·경력·자격증을 보여준다', (WidgetTester tester) async {
    await pumpTrainerDetail(tester, _withProfile);

    expect(find.text('트레이너 소개'), findsOneWidget);
    expect(find.text(_withProfile.trainerIntro!), findsOneWidget);
    expect(find.text('경력 7년'), findsOneWidget);
    expect(find.text('자격증 · 인증'), findsOneWidget);
    for (final String cert in _withProfile.trainerCertifications) {
      expect(find.text(cert), findsOneWidget);
    }
  });

  testWidgets('프로필 정보가 없으면 소개 섹션을 그리지 않는다', (WidgetTester tester) async {
    await pumpTrainerDetail(tester, _withoutProfile);

    // 트레이너 자체는 존재하므로 이름은 보이되, 소개 섹션만 빠진다.
    expect(find.text(_withoutProfile.trainerName!), findsOneWidget);
    expect(find.text('트레이너 소개'), findsNothing);
    expect(find.text('자격증 · 인증'), findsNothing);
  });

  // 트레이너 앱은 별도 패키지라 seedTrainerProfile 을 import 할 수 없다.
  // 기대값을 여기 고정해 두어, 사용자 앱 목 데이터가 바뀌면 실패하도록 한다.
  // 값을 고칠 때는 frontend/flutter_trainer/lib/shared/models/trainer_profile.dart
  // 의 seedTrainerProfile 과 함께 맞춰야 한다.
  test('연결된 트레이너가 트레이너 앱 seedTrainerProfile 과 같은 값을 쓴다', () async {
    final Gym? gym = await MockGymRepository().fetchMyGym();

    expect(gym, isNotNull);
    expect(gym!.name, '온케어짐 신촌점');
    expect(gym.address, '서울 서대문구 신촌로 120');
    expect(gym.phone, '02-1234-5678');
    expect(gym.weekdayHours, '06:00 - 23:00');
    expect(gym.trainerName, '김트레이너');
    expect(gym.trainerRole, '퍼스널 트레이너');
    expect(gym.trainerCareer, '7년');
    expect(
      gym.trainerIntro,
      '혈압 관리와 체중 감량 전문 트레이너입니다. 고객 맞춤형 AI 루틴으로 안전하고 효과적인 운동을 도와드려요.',
    );
    expect(gym.trainerCertifications, <String>[
      '생활스포츠지도사 2급',
      '퍼스널트레이닝 CPT',
      '스포츠 영양사',
    ]);
  });
}
