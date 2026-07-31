/// GET /users/me/profile — the consolidated profile the settings modals
/// edit (내 프로필 + 건강 목표).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.birthDate = '',
    this.dailyCalories,
    this.dailySodiumMg,
    this.dailySugarG,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String birthDate;
  final int? dailyCalories;
  final int? dailySodiumMg;

  /// 일일 당류 제한(g). 홈 영양 현황의 목표 당류와 같은 값을 공유한다.
  final int? dailySugarG;

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    phone: (json['phone'] as String?) ?? '',
    birthDate: (json['birth_date'] as String?) ?? '',
    dailyCalories: (json['daily_calories'] as num?)?.toInt(),
    dailySodiumMg: (json['daily_sodium_mg'] as num?)?.toInt(),
    dailySugarG: (json['daily_sugar_g'] as num?)?.toInt(),
  );
}
