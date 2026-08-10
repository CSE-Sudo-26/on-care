import 'dart:typed_data';

/// Where a meal photo comes from. Mirrors `image_picker`'s `ImageSource`
/// so the domain/presentation layers don't depend on the plugin (and the
/// picker can be faked in tests).
enum MealPhotoSource { camera, gallery }

/// Image formats `POST /diet/analyze` accepts — keep in sync with
/// `_ALLOWED_MIME` in `backend/app/api/v1/diet.py`. An iPhone photo can be
/// HEIC, which the server rejects with 415, so the picker sniffs the real
/// bytes instead of always claiming `meal.jpg` / `image/jpeg`.
enum MealImageFormat {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const MealImageFormat(this.mimeType, this.extension);

  final String mimeType;
  final String extension;

  /// Detects the format from [bytes]' magic number, or null when the bytes
  /// are not one of the accepted formats (HEIC, an empty file, a truncated
  /// download …). Sniffing the content — not the file name the OS handed us
  /// — is what keeps the uploaded body, extension and MIME in agreement.
  static MealImageFormat? detect(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return MealImageFormat.jpeg;
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return MealImageFormat.png;
    }
    // RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return MealImageFormat.webp;
    }
    return null;
  }
}

/// A food photo ready to upload: the bytes plus a file name and MIME type
/// that actually describe them.
///
/// [fromBytes] is the only way to build one, and it derives the format from
/// the bytes. There is deliberately no constructor taking a format: letting a
/// caller pair PNG bytes with [MealImageFormat.jpeg] would put back exactly
/// the body/extension/MIME mismatch this class exists to prevent.
class MealPhoto {
  const MealPhoto._({required this.bytes, required this.format});

  /// Returns null when [bytes] are not a format the server accepts — HEIC, an
  /// empty file, a truncated download — so the caller can show a message
  /// instead of letting the server answer 415.
  static MealPhoto? fromBytes(Uint8List bytes) {
    final MealImageFormat? format = MealImageFormat.detect(bytes);
    if (format == null) return null;
    return MealPhoto._(bytes: bytes, format: format);
  }

  final Uint8List bytes;
  final MealImageFormat format;

  String get filename => 'meal.${format.extension}';

  String get mimeType => format.mimeType;
}

/// Why picking a meal photo failed. A user cancelling is *not* a failure —
/// the picker returns null for that — so every value here is worth showing
/// a message for.
enum MealPhotoFailure {
  /// Camera access was denied, but the current platform may request it again.
  cameraPermissionDenied,

  /// Camera access can only be restored outside the app.
  cameraPermissionPermanentlyDenied,

  /// Camera access is blocked by a device or account policy.
  cameraPermissionRestricted,

  /// Photo-library access was denied, but may be requested again.
  photoPermissionDenied,

  /// Photo-library access can only be restored outside the app.
  photoPermissionPermanentlyDenied,

  /// Photo-library access is blocked by a device or account policy.
  photoPermissionRestricted,

  /// The picked file is not JPEG/PNG/WebP (an unconverted HEIC, typically).
  unsupportedFormat,

  /// Still over the byte budget after the picker downscaled it.
  tooLarge,

  /// Anything else: unreadable file, plugin/platform error.
  readFailed,
}

class MealPhotoException implements Exception {
  const MealPhotoException(this.failure, {this.cause});

  final MealPhotoFailure failure;
  final Object? cause;

  @override
  String toString() => 'MealPhotoException(${failure.name}, cause: $cause)';
}
