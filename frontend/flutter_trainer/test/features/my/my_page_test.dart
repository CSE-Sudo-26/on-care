import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare_trainer/features/my/data/trainer_profile_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';

import '../../helpers/pump_app.dart';

class _GymFailureRepository implements TrainerProfileRepository {
  final MockTrainerProfileRepository _delegate = MockTrainerProfileRepository();

  @override
  Future<TrainerProfile> fetch() => _delegate.fetch();

  @override
  Future<List<TrainerGymChoice>> listGyms() => _delegate.listGyms();

  @override
  Future<TrainerProfile> update(TrainerProfileUpdate update) =>
      _delegate.update(update);

  @override
  Future<TrainerProfile> setGym(String gymId) {
    throw const ServerError(message: '헬스장 연결 요청이 실패했습니다.');
  }

  @override
  Future<TrainerProfile> clearGym() => _delegate.clearGym();
}

class _UpdateFailureRepository implements TrainerProfileRepository {
  @override
  Future<TrainerProfile> fetch() async => seedTrainerProfile;

  @override
  Future<List<TrainerGymChoice>> listGyms() async => const <TrainerGymChoice>[];

  @override
  Future<TrainerProfile> update(TrainerProfileUpdate update) {
    throw const ValidationError(message: '프로필 입력값을 확인해 주세요.');
  }

  @override
  Future<TrainerProfile> setGym(String gymId) => throw UnimplementedError();

  @override
  Future<TrainerProfile> clearGym() => throw UnimplementedError();
}

void main() {
  group('MyPage', () {
    Future<void> openTab(WidgetTester tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.my,
      );
    }

    /// 로그아웃 moved into the 설정 section (it is an account action, not
    /// part of the profile).
    Future<void> openSettings(WidgetTester tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.mySection('settings'),
      );
    }

    testWidgets('renders profile, certs, stats, gym — and no 역할 전환', (
      tester,
    ) async {
      await openTab(tester);

      expect(find.text('김트레이너'), findsWidgets);
      expect(find.text('trainer@oncare.com'), findsOneWidget);
      expect(find.text('퍼스널 트레이너'), findsOneWidget);
      expect(find.text('경력 7년'), findsOneWidget);
      expect(find.text('생활스포츠지도사 2급'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('담당 고객'), 150);
      expect(find.text('3'), findsOneWidget); // live client count
      expect(find.text('완료 세션'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('온케어짐 신촌점'), 150);
      expect(find.text('영업 중'), findsOneWidget);

      // 역할 전환은 계정 분리 정책상 존재하지 않는다.
      expect(find.textContaining('역할 전환'), findsNothing);
    });

    testWidgets('로그아웃 returns to the login screen', (tester) async {
      await openSettings(tester);

      await tester.scrollUntilVisible(find.text('로그아웃'), 150);
      await tester.ensureVisible(find.text('로그아웃'));
      await tester.pump();
      await tester.tap(find.text('로그아웃'));
      await settle(tester);

      expect(find.text('로그인 없이 데모 둘러보기'), findsOneWidget);
    });

    testWidgets('edit mode saves changes with a confirmation flash', (
      tester,
    ) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.my,
      );

      await tester.tap(find.text('프로필 수정'));
      await tester.pump();
      expect(find.text('저장'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('profile-phone')),
        '010-9999-0000',
      );
      await tester.tap(find.text('저장'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('변경사항이 저장됐어요'), findsOneWidget);
      expect(
        container.read(sessionControllerProvider).profile?.phone,
        '010-9999-0000',
      );

      // Flash expires (no pending timers at test end).
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('변경사항이 저장됐어요'), findsNothing);
    });

    testWidgets('career validation rejects a signed or embedded number', (
      tester,
    ) async {
      await openTab(tester);
      await tester.tap(find.text('프로필 수정'));
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey<String>('profile-career')),
        '-1년',
      );
      await tester.tap(find.text('저장'));
      await tester.pump();

      expect(find.text('경력은 0~80 사이의 연수로 입력해 주세요.'), findsOneWidget);
    });

    testWidgets('gym selection rebuilds the manual gym fields', (tester) async {
      await openTab(tester);
      await tester.tap(find.text('프로필 수정'));
      await tester.pump();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await tester.pump();

      Finder gymNameField() => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == '온케어짐 신촌점',
      );

      expect(tester.widget<TextField>(gymNameField()).enabled, isTrue);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).last,
      );
      dropdown.onChanged!('gym-1');
      await tester.pump();
      expect(tester.widget<TextField>(gymNameField()).enabled, isFalse);

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('소속 없음').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(gymNameField()).enabled, isTrue);
    });

    testWidgets('gym-only failure reports that profile fields were saved', (
      tester,
    ) async {
      final repository = _GymFailureRepository();
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.my,
        extraOverrides: <Override>[
          trainerProfileRepositoryProvider.overrideWithValue(repository),
        ],
      );

      await tester.tap(find.text('프로필 수정'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('profile-phone')),
        '010-9999-0000',
      );
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await tester.pump();
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).last,
      );
      dropdown.onChanged!('gym-1');
      await tester.pump();

      await tester.tap(find.text('저장'));
      await settle(tester);

      expect(find.textContaining('소속 헬스장 변경에 실패했습니다'), findsOneWidget);
      expect(
        container.read(sessionControllerProvider).profile?.phone,
        '010-9999-0000',
      );
    });

    testWidgets('profile update failure restores the server snapshot', (
      tester,
    ) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.my,
        extraOverrides: <Override>[
          trainerProfileRepositoryProvider.overrideWithValue(
            _UpdateFailureRepository(),
          ),
        ],
      );

      await tester.tap(find.text('프로필 수정'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('profile-phone')),
        '010-0000-0000',
      );
      await tester.tap(find.text('저장'));
      await settle(tester);

      expect(find.text('프로필 입력값을 확인해 주세요.'), findsOneWidget);
      expect(
        container.read(sessionControllerProvider).profile?.phone,
        seedTrainerProfile.phone,
      );
      expect(find.text('프로필 수정'), findsOneWidget);
    });
  });
}
