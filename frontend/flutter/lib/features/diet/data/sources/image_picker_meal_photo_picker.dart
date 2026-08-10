import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:oncare/features/diet/domain/entities/meal_photo.dart';
import 'package:oncare/features/diet/domain/repositories/meal_photo_picker.dart';

/// Signature of `ImagePicker.pickImage`, injected so tests can drive the
/// camera/gallery outcomes (success, cancel, permission denied) without a
/// platform channel.
typedef PickImage =
    Future<XFile?> Function({
      required ImageSource source,
      double? maxWidth,
      double? maxHeight,
      int? imageQuality,
      bool requestFullMetadata,
    });

/// [MealPhotoPicker] backed by `image_picker`.
///
/// Two things it guarantees on top of the plugin:
/// * the returned bytes, extension and MIME type agree (the format is
///   sniffed from the bytes, not assumed to be JPEG — an iPhone photo can
///   come back as HEIC, which `/diet/analyze` rejects with 415);
/// * the upload stays small — the picker downscales to [_maxDimension] and
///   re-encodes at [_imageQuality], and anything still over [_maxBytes] is
///   rejected before it reaches the network.
class ImagePickerMealPhotoPicker implements MealPhotoPicker {
  ImagePickerMealPhotoPicker({
    PickImage? pickImage,
    TargetPlatform? platform,
    bool? isWeb,
  }) : _pickImage = pickImage ?? ImagePicker().pickImage,
       _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb;

  /// Longest-edge cap. Downscaling here also makes iOS re-encode the capture
  /// to JPEG, so a HEIC original normally never reaches the format check.
  static const double _maxDimension = 1600;
  static const int _imageQuality = 85;

  /// Guard for the rare case a platform hands back something huge anyway
  /// (a 1600px JPEG at quality 85 is ~0.5 MB, so this is headroom).
  static const int _maxBytes = 8 * 1024 * 1024;

  static const String _cameraAccessDenied = 'camera_access_denied';
  static const String _cameraAccessRestricted = 'camera_access_restricted';
  static const String _photoAccessDenied = 'photo_access_denied';
  static const String _photoAccessRestricted = 'photo_access_restricted';

  final PickImage _pickImage;
  final TargetPlatform _platform;
  final bool _isWeb;

  @override
  Future<MealPhoto?> pick(MealPhotoSource source) async {
    final XFile? file;
    try {
      file = await _pickImage(
        source: source == MealPhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _imageQuality,
        // We only upload the selected bytes. On iOS 14+ this keeps PHPicker
        // permissionless instead of requesting library access for metadata.
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      throw MealPhotoException(_failureOf(error, source), cause: error);
    } on Object catch (error) {
      throw MealPhotoException(MealPhotoFailure.readFailed, cause: error);
    }
    // Cancelled — the caller returns to the sheet with no error shown.
    if (file == null) return null;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on Object catch (error) {
      throw MealPhotoException(MealPhotoFailure.readFailed, cause: error);
    }
    if (bytes.isEmpty) {
      throw const MealPhotoException(MealPhotoFailure.readFailed);
    }
    if (bytes.length > _maxBytes) {
      throw const MealPhotoException(MealPhotoFailure.tooLarge);
    }

    // Derives the format from the bytes, so the part we upload can't claim a
    // type the body doesn't have.
    final MealPhoto? photo = MealPhoto.fromBytes(bytes);
    if (photo == null) {
      throw const MealPhotoException(MealPhotoFailure.unsupportedFormat);
    }
    return photo;
  }

  MealPhotoFailure _failureOf(PlatformException error, MealPhotoSource source) {
    final bool isNativeIos = !_isWeb && _platform == TargetPlatform.iOS;
    return switch (error.code) {
      _cameraAccessRestricted => MealPhotoFailure.cameraPermissionRestricted,
      _photoAccessRestricted => MealPhotoFailure.photoPermissionRestricted,
      _cameraAccessDenied =>
        isNativeIos
            ? MealPhotoFailure.cameraPermissionPermanentlyDenied
            : MealPhotoFailure.cameraPermissionDenied,
      _photoAccessDenied =>
        isNativeIos
            ? MealPhotoFailure.photoPermissionPermanentlyDenied
            : MealPhotoFailure.photoPermissionDenied,
      // Older plugin versions report a bare "access denied" without saying
      // which permission; fall back to the source the user tapped.
      _ when error.code.contains('denied') => switch ((source, isNativeIos)) {
        (MealPhotoSource.camera, true) =>
          MealPhotoFailure.cameraPermissionPermanentlyDenied,
        (MealPhotoSource.camera, false) =>
          MealPhotoFailure.cameraPermissionDenied,
        (MealPhotoSource.gallery, true) =>
          MealPhotoFailure.photoPermissionPermanentlyDenied,
        (MealPhotoSource.gallery, false) =>
          MealPhotoFailure.photoPermissionDenied,
      },
      _ => MealPhotoFailure.readFailed,
    };
  }
}
