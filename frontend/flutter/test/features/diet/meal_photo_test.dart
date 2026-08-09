import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/domain/entities/meal_photo.dart';

/// Magic-number prefixes; the detector only reads the header, so a short
/// body is enough to stand in for a real photo.
Uint8List _jpeg() =>
    Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
Uint8List _png() => Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
]);
Uint8List _webp() => Uint8List.fromList(<int>[
  0x52, 0x49, 0x46, 0x46, // RIFF
  0x24, 0x00, 0x00, 0x00, // size
  0x57, 0x45, 0x42, 0x50, // WEBP
]);

/// `ftypheic` box — what an iPhone photo looks like when it is not converted.
Uint8List _heic() => Uint8List.fromList(<int>[
  0x00, 0x00, 0x00, 0x18, // box size
  0x66, 0x74, 0x79, 0x70, // ftyp
  0x68, 0x65, 0x69, 0x63, // heic
]);

void main() {
  group('MealImageFormat.detect', () {
    test('JPEG/PNG/WebP 는 실제 바이트로 판별한다', () {
      expect(MealImageFormat.detect(_jpeg()), MealImageFormat.jpeg);
      expect(MealImageFormat.detect(_png()), MealImageFormat.png);
      expect(MealImageFormat.detect(_webp()), MealImageFormat.webp);
    });

    test('서버가 받지 않는 형식(HEIC)·빈 바이트는 null 이다', () {
      expect(MealImageFormat.detect(_heic()), isNull);
      expect(MealImageFormat.detect(Uint8List(0)), isNull);
      // Truncated header must not be read as a match.
      expect(
        MealImageFormat.detect(Uint8List.fromList(<int>[0xFF, 0xD8])),
        isNull,
      );
    });
  });

  group('MealPhoto', () {
    test('파일명 확장자와 MIME 이 실제 형식과 일치한다', () {
      final MealPhoto jpeg = MealPhoto(
        bytes: _jpeg(),
        format: MealImageFormat.jpeg,
      );
      expect(jpeg.filename, 'meal.jpg');
      expect(jpeg.mimeType, 'image/jpeg');

      final MealPhoto png = MealPhoto(
        bytes: _png(),
        format: MealImageFormat.png,
      );
      expect(png.filename, 'meal.png');
      expect(png.mimeType, 'image/png');

      final MealPhoto webp = MealPhoto(
        bytes: _webp(),
        format: MealImageFormat.webp,
      );
      expect(webp.filename, 'meal.webp');
      expect(webp.mimeType, 'image/webp');
    });
  });
}
