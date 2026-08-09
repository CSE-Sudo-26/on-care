import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/meal_photo.dart';
import 'package:oncare/features/diet/domain/repositories/meal_photo_picker.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/widgets/diet_flows.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

final Uint8List _jpegBytes = Uint8List.fromList(<int>[
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
]);

/// Plays back one picker outcome: a photo, a cancel (null), or a failure.
class _FakeMealPhotoPicker implements MealPhotoPicker {
  _FakeMealPhotoPicker({this.photo, this.failure});

  final MealPhoto? photo;
  final MealPhotoFailure? failure;
  MealPhotoSource? requestedSource;

  @override
  Future<MealPhoto?> pick(MealPhotoSource source) async {
    requestedSource = source;
    if (failure != null) throw MealPhotoException(failure!);
    return photo;
  }
}

class _RecordingDietRepository extends MockDietRepository {
  MealPhoto? uploaded;

  @override
  Future<DietAnalysisResult> analyze({
    required MealPhoto photo,
    required String mealType,
    String? idempotencyKey,
  }) {
    uploaded = photo;
    return super.analyze(
      photo: photo,
      mealType: mealType,
      idempotencyKey: idempotencyKey,
    );
  }
}

Future<void> _pumpAddSheet(
  WidgetTester tester, {
  required MealPhotoPicker picker,
  required _RecordingDietRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        mealPhotoPickerProvider.overrideWithValue(picker),
        dietRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDietAddSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('카메라로 촬영한 사진은 형식에 맞는 MIME 으로 분석 요청된다', (
    WidgetTester tester,
  ) async {
    final _FakeMealPhotoPicker picker = _FakeMealPhotoPicker(
      photo: MealPhoto(bytes: _jpegBytes, format: MealImageFormat.jpeg),
    );
    final _RecordingDietRepository repository = _RecordingDietRepository();
    await _pumpAddSheet(tester, picker: picker, repository: repository);

    await tester.tap(find.text('사진 찍기'));
    await tester.pumpAndSettle();

    expect(picker.requestedSource, MealPhotoSource.camera);
    expect(repository.uploaded?.filename, 'meal.jpg');
    expect(repository.uploaded?.mimeType, 'image/jpeg');
    expect(find.text('분석 완료!'), findsOneWidget);
  });

  testWidgets('보관함에서 고른 PNG 는 png 확장자·MIME 으로 올라간다', (
    WidgetTester tester,
  ) async {
    final _FakeMealPhotoPicker picker = _FakeMealPhotoPicker(
      photo: MealPhoto(
        bytes: Uint8List.fromList(<int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]),
        format: MealImageFormat.png,
      ),
    );
    final _RecordingDietRepository repository = _RecordingDietRepository();
    await _pumpAddSheet(tester, picker: picker, repository: repository);

    await tester.tap(find.text('사진 선택'));
    await tester.pumpAndSettle();

    expect(picker.requestedSource, MealPhotoSource.gallery);
    expect(repository.uploaded?.filename, 'meal.png');
    expect(repository.uploaded?.mimeType, 'image/png');
  });

  testWidgets('촬영을 취소하면 오류 없이 추가 시트에 머무른다', (WidgetTester tester) async {
    final _FakeMealPhotoPicker picker = _FakeMealPhotoPicker();
    final _RecordingDietRepository repository = _RecordingDietRepository();
    await _pumpAddSheet(tester, picker: picker, repository: repository);

    await tester.tap(find.text('사진 찍기'));
    await tester.pumpAndSettle();

    expect(repository.uploaded, isNull);
    // 취소는 오류가 아니므로 안내를 띄우지 않는다.
    expect(find.byKey(const Key('dietPhotoFailureNotice')), findsNothing);
    // 시트가 닫히지 않아 바로 다시 시도할 수 있다.
    expect(find.byKey(const Key('dietAddSheet')), findsOneWidget);
  });

  testWidgets('카메라 권한이 거부되면 안내 메시지를 보여주고 앱은 살아있다', (WidgetTester tester) async {
    final _FakeMealPhotoPicker picker = _FakeMealPhotoPicker(
      failure: MealPhotoFailure.cameraPermissionDenied,
    );
    final _RecordingDietRepository repository = _RecordingDietRepository();
    await _pumpAddSheet(tester, picker: picker, repository: repository);

    await tester.tap(find.text('사진 찍기'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 시트에 가려지지 않도록 안내를 시트 안에 그린다.
    expect(find.byKey(const Key('dietPhotoFailureNotice')), findsOneWidget);
    expect(find.textContaining('카메라 접근이 허용되지 않았어요'), findsOneWidget);
    expect(repository.uploaded, isNull);
    expect(find.byKey(const Key('dietAddSheet')), findsOneWidget);
  });

  testWidgets('서버가 받지 않는 형식은 형식 안내 메시지를 보여준다', (WidgetTester tester) async {
    final _FakeMealPhotoPicker picker = _FakeMealPhotoPicker(
      failure: MealPhotoFailure.unsupportedFormat,
    );
    final _RecordingDietRepository repository = _RecordingDietRepository();
    await _pumpAddSheet(tester, picker: picker, repository: repository);

    await tester.tap(find.text('사진 선택'));
    await tester.pumpAndSettle();

    expect(find.textContaining('지원하지 않는 사진 형식'), findsOneWidget);
    expect(repository.uploaded, isNull);
  });

  testWidgets('분석 API 가 실패해도 같은 사진으로 다시 시도할 수 있다', (WidgetTester tester) async {
    final _FakeMealPhotoPicker picker = _FakeMealPhotoPicker(
      photo: MealPhoto(bytes: _jpegBytes, format: MealImageFormat.jpeg),
    );
    final _FailingOnceDietRepository repository = _FailingOnceDietRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          mealPhotoPickerProvider.overrideWithValue(picker),
          dietRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDietAddSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 찍기'));
    await tester.pumpAndSettle();

    expect(find.text('분석 실패'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('분석 완료!'), findsOneWidget);
  });
}

class _FailingOnceDietRepository extends MockDietRepository {
  int calls = 0;

  @override
  Future<DietAnalysisResult> analyze({
    required MealPhoto photo,
    required String mealType,
    String? idempotencyKey,
  }) {
    calls += 1;
    if (calls == 1) throw StateError('network down');
    return super.analyze(
      photo: photo,
      mealType: mealType,
      idempotencyKey: idempotencyKey,
    );
  }
}
