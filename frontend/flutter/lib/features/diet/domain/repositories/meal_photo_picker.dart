import 'package:oncare/features/diet/domain/entities/meal_photo.dart';

/// Picks a food photo for AI analysis. Kept behind an interface so the diet
/// flow can be widget-tested without the camera/photo-library plugin.
abstract class MealPhotoPicker {
  /// Returns the picked photo, or null when the user cancelled the camera or
  /// the gallery (cancelling must not surface as an error).
  ///
  /// Throws [MealPhotoException] when the photo could not be used —
  /// permission denied, unsupported format, too large, unreadable.
  Future<MealPhoto?> pick(MealPhotoSource source);
}
