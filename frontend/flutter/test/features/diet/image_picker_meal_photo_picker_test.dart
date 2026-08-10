import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:oncare/features/diet/data/sources/image_picker_meal_photo_picker.dart';
import 'package:oncare/features/diet/domain/entities/meal_photo.dart';

final Uint8List _jpegBytes = Uint8List.fromList(<int>[
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
]);
final Uint8List _heicBytes = Uint8List.fromList(<int>[
  0x00, 0x00, 0x00, 0x18, // box size
  0x66, 0x74, 0x79, 0x70, // ftyp
  0x68, 0x65, 0x69, 0x63, // heic
]);

/// Records the arguments the picker asked for, and replays [result]/[error].
class _FakePickImage {
  _FakePickImage({this.result, this.error});

  final XFile? result;
  final Object? error;

  ImageSource? source;
  double? maxWidth;
  double? maxHeight;
  int? imageQuality;
  bool? requestFullMetadata;
  int calls = 0;

  Future<XFile?> call({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
  }) async {
    calls += 1;
    this.source = source;
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    this.imageQuality = imageQuality;
    this.requestFullMetadata = requestFullMetadata;
    if (error != null) throw error!;
    return result;
  }
}

XFile _file(Uint8List bytes) => XFile.fromData(bytes, name: 'IMG_0001.HEIC');

void main() {
  test('카메라 촬영에 성공하면 실제 형식에 맞는 MealPhoto 를 돌려준다', () async {
    final _FakePickImage pick = _FakePickImage(result: _file(_jpegBytes));
    final MealPhoto? photo = await ImagePickerMealPhotoPicker(
      pickImage: pick.call,
    ).pick(MealPhotoSource.camera);

    expect(pick.source, ImageSource.camera);
    expect(photo, isNotNull);
    expect(photo!.format, MealImageFormat.jpeg);
    // 파일명이 IMG_0001.HEIC 여도 바이트가 JPEG 이면 JPEG 으로 올린다.
    expect(photo.filename, 'meal.jpg');
    expect(photo.mimeType, 'image/jpeg');
    expect(photo.bytes, _jpegBytes);
  });

  test('보관함 선택도 같은 경로로 동작하고 해상도 상한을 넘긴다', () async {
    final _FakePickImage pick = _FakePickImage(result: _file(_jpegBytes));
    final MealPhoto? photo = await ImagePickerMealPhotoPicker(
      pickImage: pick.call,
    ).pick(MealPhotoSource.gallery);

    expect(pick.source, ImageSource.gallery);
    // 지나치게 큰 사진이 그대로 업로드되지 않도록 축소·재인코딩을 요청한다.
    expect(pick.maxWidth, 1600);
    expect(pick.maxHeight, 1600);
    expect(pick.imageQuality, 85);
    expect(pick.requestFullMetadata, isFalse);
    expect(photo, isNotNull);
  });

  test('사용자가 취소하면 오류가 아니라 null 이다', () async {
    final _FakePickImage pick = _FakePickImage();
    final MealPhoto? photo = await ImagePickerMealPhotoPicker(
      pickImage: pick.call,
    ).pick(MealPhotoSource.camera);

    expect(photo, isNull);
  });

  test('Android/Web의 재요청 가능한 카메라 거부는 denied로 구분한다', () async {
    final _FakePickImage pick = _FakePickImage(
      error: PlatformException(code: 'camera_access_denied'),
    );

    await expectLater(
      ImagePickerMealPhotoPicker(
        pickImage: pick.call,
        platform: TargetPlatform.android,
        isWeb: false,
      ).pick(MealPhotoSource.camera),
      throwsA(
        isA<MealPhotoException>().having(
          (MealPhotoException e) => e.failure,
          'failure',
          MealPhotoFailure.cameraPermissionDenied,
        ),
      ),
    );
  });

  test('iOS 카메라 거부는 앱에서 재요청할 수 없는 영구 거부로 구분한다', () async {
    final _FakePickImage pick = _FakePickImage(
      error: PlatformException(code: 'camera_access_denied'),
    );

    await expectLater(
      ImagePickerMealPhotoPicker(
        pickImage: pick.call,
        platform: TargetPlatform.iOS,
        isWeb: false,
      ).pick(MealPhotoSource.camera),
      throwsA(
        isA<MealPhotoException>().having(
          (MealPhotoException e) => e.failure,
          'failure',
          MealPhotoFailure.cameraPermissionPermanentlyDenied,
        ),
      ),
    );
  });

  test('iOS 13 사진 보관함 거부는 영구 거부로 구분한다', () async {
    final _FakePickImage pick = _FakePickImage(
      error: PlatformException(code: 'photo_access_denied'),
    );

    await expectLater(
      ImagePickerMealPhotoPicker(
        pickImage: pick.call,
        platform: TargetPlatform.iOS,
        isWeb: false,
      ).pick(MealPhotoSource.gallery),
      throwsA(
        isA<MealPhotoException>().having(
          (MealPhotoException e) => e.failure,
          'failure',
          MealPhotoFailure.photoPermissionPermanentlyDenied,
        ),
      ),
    );
  });

  test('restricted 오류는 denied와 별도 상태로 보존한다', () async {
    for (final (code, source, expected)
        in <(String, MealPhotoSource, MealPhotoFailure)>[
          (
            'camera_access_restricted',
            MealPhotoSource.camera,
            MealPhotoFailure.cameraPermissionRestricted,
          ),
          (
            'photo_access_restricted',
            MealPhotoSource.gallery,
            MealPhotoFailure.photoPermissionRestricted,
          ),
        ]) {
      await expectLater(
        ImagePickerMealPhotoPicker(
          pickImage: _FakePickImage(error: PlatformException(code: code)).call,
          platform: TargetPlatform.iOS,
          isWeb: false,
        ).pick(source),
        throwsA(
          isA<MealPhotoException>().having(
            (MealPhotoException e) => e.failure,
            'failure',
            expected,
          ),
        ),
      );
    }
  });

  test('Web에서는 iOS 플랫폼 값이어도 native 영구 거부로 분류하지 않는다', () async {
    await expectLater(
      ImagePickerMealPhotoPicker(
        pickImage: _FakePickImage(
          error: PlatformException(code: 'camera_access_denied'),
        ).call,
        platform: TargetPlatform.iOS,
        isWeb: true,
      ).pick(MealPhotoSource.camera),
      throwsA(
        isA<MealPhotoException>().having(
          (MealPhotoException e) => e.failure,
          'failure',
          MealPhotoFailure.cameraPermissionDenied,
        ),
      ),
    );
  });

  test('서버가 415 로 거절할 HEIC 는 업로드 전에 unsupportedFormat 으로 막는다', () async {
    final _FakePickImage pick = _FakePickImage(result: _file(_heicBytes));

    await expectLater(
      ImagePickerMealPhotoPicker(
        pickImage: pick.call,
      ).pick(MealPhotoSource.camera),
      throwsA(
        isA<MealPhotoException>().having(
          (MealPhotoException e) => e.failure,
          'failure',
          MealPhotoFailure.unsupportedFormat,
        ),
      ),
    );
  });

  test('빈 파일·플랫폼 오류는 readFailed 로 모은다', () async {
    await expectLater(
      ImagePickerMealPhotoPicker(
        pickImage: _FakePickImage(result: _file(Uint8List(0))).call,
      ).pick(MealPhotoSource.gallery),
      throwsA(
        isA<MealPhotoException>().having(
          (MealPhotoException e) => e.failure,
          'failure',
          MealPhotoFailure.readFailed,
        ),
      ),
    );

    await expectLater(
      ImagePickerMealPhotoPicker(
        pickImage: _FakePickImage(
          error: PlatformException(code: 'multiple_request'),
        ).call,
      ).pick(MealPhotoSource.gallery),
      throwsA(
        isA<MealPhotoException>().having(
          (MealPhotoException e) => e.failure,
          'failure',
          MealPhotoFailure.readFailed,
        ),
      ),
    );
  });

  test('8MB 를 넘는 사진은 tooLarge 로 막는다', () async {
    final Uint8List huge = Uint8List(9 * 1024 * 1024)
      ..setRange(0, 4, <int>[0xFF, 0xD8, 0xFF, 0xE0]);

    await expectLater(
      ImagePickerMealPhotoPicker(
        pickImage: _FakePickImage(result: _file(huge)).call,
      ).pick(MealPhotoSource.camera),
      throwsA(
        isA<MealPhotoException>().having(
          (MealPhotoException e) => e.failure,
          'failure',
          MealPhotoFailure.tooLarge,
        ),
      ),
    );
  });
}
