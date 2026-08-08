import 'package:oncare_trainer/shared/models/trainer_profile.dart';

/// Maps a `GET /v1/trainer/me` JSON body (the FastAPI `TrainerMe` schema)
/// into the domain [TrainerProfile]. Kept separate from the Dio
/// repository so the DTO ↔ domain mapping can be unit-tested directly.
///
/// Shape: `{ id, name, email, phone, specialty, career, intro,
/// certifications[], gym { name, address, hours, phone } }`. Missing
/// scalar fields fall back to `''`; a missing/invalid `gym` yields an
/// empty gym; `certifications` keeps only string entries.
TrainerProfile trainerProfileFromJson(Map<String, Object?> json) {
  final gymJson = json['gym'];
  final gym = gymJson is Map<String, Object?>
      ? TrainerGym(
          id: _nullableStr(gymJson['id']),
          name: _str(gymJson['name']),
          address: _str(gymJson['address']),
          hours: _str(gymJson['hours']),
          phone: _str(gymJson['phone']),
        )
      : const TrainerGym(name: '', address: '', hours: '', phone: '');

  final certsRaw = json['certifications'];
  final certifications = certsRaw is List
      ? certsRaw.whereType<String>().toList(growable: false)
      : const <String>[];

  return TrainerProfile(
    name: _str(json['name']),
    email: _str(json['email']),
    phone: _str(json['phone']),
    specialty: _str(json['specialty']),
    career: _str(json['career']),
    intro: _str(json['intro']),
    certifications: certifications,
    gym: gym,
  );
}

String _str(Object? v) => v is String ? v : '';

String? _nullableStr(Object? value) => value?.toString();
