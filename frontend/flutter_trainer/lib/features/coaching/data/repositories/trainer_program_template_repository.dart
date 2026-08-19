import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';

/// 트레이너가 반복해 쓰는 운동 블록. (#920)
///
/// 예전에는 앱 소스의 `const` 목록 셋이었다. 트레이너마다 다른 것이 템플릿의
/// 존재 이유인데 모두가 같은 셋을 봤고, 한국어로 고정된 내용이 영어 화면에도
/// 그대로 남았다.
///
/// 저장한 템플릿이 하나도 없으면 서버가 **시작 구성**(`starter:` id)을 준다 —
/// 빈 화면으로 시작하면 이 기능이 무엇인지 알 수 없다. 시작 구성은 고치거나
/// 지울 대상이 아니고, 편집하면 그 트레이너의 첫 템플릿으로 새로 저장된다.
abstract interface class TrainerProgramTemplateRepository {
  /// 이 빌드에서 템플릿을 만들고 고칠 수 있는가.
  ///
  /// 데모는 읽기 전용이다 — 저장할 백엔드가 없어, 만든 것이 새로고침 한 번에
  /// 사라지면 만들 수 있다고 말한 화면이 거짓이 된다.
  bool get supportsEditing;

  /// 내 템플릿(최근 수정 먼저). 저장한 것이 없으면 시작 구성.
  Future<List<ProgramTemplate>> list();

  /// 새 템플릿을 저장한다.
  Future<ProgramTemplate> create({
    required String name,
    required String goal,
    required List<TemplateExercise> exercises,
  });

  /// 저장된 템플릿을 고친다. 운동 목록은 통째로 교체된다.
  Future<ProgramTemplate> update(
    String id, {
    required String name,
    required String goal,
    required List<TemplateExercise> exercises,
  });

  /// 저장된 템플릿을 지운다.
  Future<void> delete(String id);
}

/// 데모: 시작 구성만, 읽기 전용.
///
/// 실 API 가 시작 구성으로 주는 것과 **같은 셋**이다. 데모 화면이 예전과 똑같이
/// 보여야 하고, 두 빌드가 다른 템플릿을 보여 줄 이유도 없다.
class MockTrainerProgramTemplateRepository
    implements TrainerProgramTemplateRepository {
  const MockTrainerProgramTemplateRepository();

  /// 시작 구성. 데모 화면이 무엇을 보여 주는지 테스트가 그대로 읽는다.
  static const List<ProgramTemplate> starters = <ProgramTemplate>[
    ProgramTemplate(
      id: 'starter:0',
      name: '혈압 관리 기본',
      goal: '혈압 관리 · 초급',
      exercises: <TemplateExercise>[
        TemplateExercise(name: '준비 스트레칭', minutes: 10, type: '스트레칭'),
        TemplateExercise(name: '저강도 걷기', minutes: 20, type: '유산소'),
        TemplateExercise(name: '호흡 이완', minutes: 10, type: '스트레칭'),
      ],
    ),
    ProgramTemplate(
      id: 'starter:1',
      name: '체중 감량 순환',
      goal: '체중 감량 · 중급',
      exercises: <TemplateExercise>[
        TemplateExercise(name: '인터벌 유산소', minutes: 20, type: '유산소'),
        TemplateExercise(name: '전신 서킷', minutes: 20, type: '근력'),
        TemplateExercise(name: '마무리 스트레칭', minutes: 10, type: '스트레칭'),
      ],
    ),
    ProgramTemplate(
      id: 'starter:2',
      name: '하체 근력 A',
      goal: '근력 향상 · 중급',
      exercises: <TemplateExercise>[
        TemplateExercise(name: '레그프레스', minutes: 15, type: '근력'),
        TemplateExercise(name: '루마니안 데드리프트', minutes: 15, type: '근력'),
        TemplateExercise(name: '카프 레이즈', minutes: 10, type: '근력'),
      ],
    ),
  ];

  @override
  bool get supportsEditing => false;

  @override
  Future<List<ProgramTemplate>> list() async => starters;

  @override
  Future<ProgramTemplate> create({
    required String name,
    required String goal,
    required List<TemplateExercise> exercises,
  }) async => throw const ValidationError();

  @override
  Future<ProgramTemplate> update(
    String id, {
    required String name,
    required String goal,
    required List<TemplateExercise> exercises,
  }) async => throw const ValidationError();

  @override
  Future<void> delete(String id) async => throw const ValidationError();
}

/// 실 백엔드 구현.
class DioTrainerProgramTemplateRepository
    implements TrainerProgramTemplateRepository {
  const DioTrainerProgramTemplateRepository(this._dio);

  static const String _base = '/trainer/program-templates';

  final Dio _dio;

  @override
  bool get supportsEditing => true;

  @override
  Future<List<ProgramTemplate>> list() async {
    try {
      final res = await _dio.get<List<dynamic>>(_base);
      return (res.data ?? const <dynamic>[])
          .whereType<Map<String, Object?>>()
          .map(ProgramTemplate.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<ProgramTemplate> create({
    required String name,
    required String goal,
    required List<TemplateExercise> exercises,
  }) => _write(
    () => _dio.post<Map<String, Object?>>(
      _base,
      data: _body(name: name, goal: goal, exercises: exercises),
    ),
  );

  @override
  Future<ProgramTemplate> update(
    String id, {
    required String name,
    required String goal,
    required List<TemplateExercise> exercises,
  }) => _write(
    () => _dio.put<Map<String, Object?>>(
      '$_base/${Uri.encodeComponent(id)}',
      data: _body(name: name, goal: goal, exercises: exercises),
    ),
  );

  @override
  Future<void> delete(String id) async {
    try {
      await _dio.delete<Map<String, Object?>>(
        '$_base/${Uri.encodeComponent(id)}',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const NotFoundError();
      throw AppError.fromDio(e);
    }
  }

  Map<String, Object?> _body({
    required String name,
    required String goal,
    required List<TemplateExercise> exercises,
  }) => <String, Object?>{
    'name': name,
    'goal': goal,
    'exercises': <Map<String, Object?>>[
      for (final exercise in exercises) exercise.toJson(),
    ],
  };

  /// 저장·수정이 같은 실패를 공유하므로 매핑도 공유한다. 409(한도)는 서버가
  /// 이유를 문장으로 주고, 그 문장이 트레이너가 다음에 할 일을 정한다.
  Future<ProgramTemplate> _write(
    Future<Response<Map<String, Object?>>> Function() call,
  ) async {
    try {
      final res = await call();
      final data = res.data;
      if (data == null) throw const ServerError();
      return ProgramTemplate.fromJson(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) throw const NotFoundError();
      if (status == 409 || status == 422 || status == 400) {
        final body = e.response?.data;
        final detail = body is Map ? body['detail'] : null;
        throw ValidationError(message: detail is String ? detail : null);
      }
      throw AppError.fromDio(e);
    }
  }
}

/// 현재 모드에 맞는 저장소.
final trainerProgramTemplateRepositoryProvider =
    Provider<TrainerProgramTemplateRepository>((ref) {
      if (ref.watch(appConfigProvider).useMockApi) {
        return const MockTrainerProgramTemplateRepository();
      }
      return DioTrainerProgramTemplateRepository(ref.watch(dioProvider));
    }, name: 'trainerProgramTemplateRepository');

/// 템플릿을 만들고 고칠 수 있는 빌드인가 — 편집 진입점 노출 조건.
final programTemplateEditingEnabledProvider = Provider<bool>(
  (ref) => ref.watch(trainerProgramTemplateRepositoryProvider).supportsEditing,
  name: 'programTemplateEditingEnabled',
);

/// AI 코칭 탭의 템플릿 목록. 쓰기 뒤에는 invalidate 한다.
final programTemplatesProvider = FutureProvider<List<ProgramTemplate>>(
  (ref) => ref.watch(trainerProgramTemplateRepositoryProvider).list(),
  name: 'programTemplates',
);
