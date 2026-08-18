import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/my/data/trainer_settings.dart';
import 'package:oncare_trainer/features/my/data/trainer_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDio extends Mock implements Dio {}

/// A source whose writes always fail — stands in for a dropped network.
class _FailingRepository implements TrainerSettingsRepository {
  const _FailingRepository(this.stored);

  final TrainerSettings stored;

  @override
  Future<TrainerSettings> load() async => stored;

  @override
  Future<TrainerSettings> save(TrainerSettings settings) async {
    throw const NetworkError(message: 'offline');
  }
}

/// A source that records what it was asked to save.
class _RecordingRepository implements TrainerSettingsRepository {
  _RecordingRepository(this._state);

  TrainerSettings _state;
  final List<TrainerSettings> saved = <TrainerSettings>[];

  @override
  Future<TrainerSettings> load() async => _state;

  @override
  Future<TrainerSettings> save(TrainerSettings settings) async {
    saved.add(settings);
    _state = settings;
    return settings;
  }
}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> body) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/trainer/me/settings'),
      statusCode: 200,
      data: body,
    );

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  group('LocalTrainerSettingsRepository', () {
    test('an empty store yields the shared defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = LocalTrainerSettingsRepository(
        await SharedPreferences.getInstance(),
      );

      final settings = await repo.load();
      expect(settings.newMessageAlerts, isTrue);
      expect(settings.sessionReminders, isTrue);
      expect(settings.reminderLeadMinutes, 30);
    });

    test('a stored lead time outside the options falls back', () async {
      // An older build (or a hand-edited store) must not put the picker
      // into a state it cannot render.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'trainer.notify.leadMinutes': 45,
      });
      final repo = LocalTrainerSettingsRepository(
        await SharedPreferences.getInstance(),
      );

      expect((await repo.load()).reminderLeadMinutes, 30);
    });

    test('save round-trips through the store', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = LocalTrainerSettingsRepository(
        await SharedPreferences.getInstance(),
      );

      await repo.save(
        const TrainerSettings(
          newMessageAlerts: false,
          reminderLeadMinutes: 60,
        ),
      );

      final reloaded = await repo.load();
      expect(reloaded.newMessageAlerts, isFalse);
      expect(reloaded.reminderLeadMinutes, 60);
    });
  });

  group('DioTrainerSettingsRepository', () {
    late _MockDio dio;
    late DioTrainerSettingsRepository repo;

    setUp(() {
      dio = _MockDio();
      repo = DioTrainerSettingsRepository(dio);
    });

    test('load decodes the server payload', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/trainer/me/settings'),
      ).thenAnswer(
        (_) async => _ok(<String, dynamic>{
          'notify_new_message': false,
          'notify_session_reminder': true,
          'reminder_lead_minutes': 10,
        }),
      );

      final settings = await repo.load();
      expect(settings.newMessageAlerts, isFalse);
      expect(settings.reminderLeadMinutes, 10);
    });

    test('save returns the SERVER view, not the requested one', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/trainer/me/settings',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(<String, dynamic>{
          'notify_new_message': true,
          'notify_session_reminder': true,
          'reminder_lead_minutes': 30,
        }),
      );

      final result = await repo.save(
        const TrainerSettings(reminderLeadMinutes: 60),
      );

      // The server owns the contract; echoing our own request back would
      // leave a rejected value on screen as if it had stuck.
      expect(result.reminderLeadMinutes, 30);
      final body =
          verify(
                () => dio.put<Map<String, dynamic>>(
                  '/trainer/me/settings',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body['reminder_lead_minutes'], 60);
    });

    test('an HTTP failure surfaces as a typed AppError', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/trainer/me/settings'),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/trainer/me/settings'),
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: RequestOptions(path: '/trainer/me/settings'),
            statusCode: 403,
          ),
        ),
      );

      expect(() => repo.load(), throwsA(isA<ForbiddenError>()));
    });
  });

  group('TrainerSettingsController', () {
    test('loads the stored settings on creation', () async {
      final controller = TrainerSettingsController(
        _RecordingRepository(const TrainerSettings(newMessageAlerts: false)),
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.newMessageAlerts, isFalse);
    });

    test('a toggle applies immediately and persists', () async {
      final repo = _RecordingRepository(const TrainerSettings());
      final controller = TrainerSettingsController(repo);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      await controller.setNewMessageAlerts(false);

      expect(controller.state.newMessageAlerts, isFalse);
      expect(repo.saved.single.newMessageAlerts, isFalse);
    });

    test('a FAILED write rolls back and reports', () async {
      final controller = TrainerSettingsController(
        const _FailingRepository(TrainerSettings()),
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      await controller.setSessionReminders(false);

      // Keeping the flipped value would make the screen claim something
      // the server never accepted.
      expect(controller.state.sessionReminders, isTrue);
      expect(controller.lastError, isNotNull);
    });

    test('a lead time the server would refuse is not sent', () async {
      final repo = _RecordingRepository(const TrainerSettings());
      final controller = TrainerSettingsController(repo);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      await controller.setReminderLead(45);

      expect(repo.saved, isEmpty);
      expect(controller.state.reminderLeadMinutes, 30);
    });
  });
}
