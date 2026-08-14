/// One meal in a client's day (아침/점심/저녁/간식), as shown on the 식단
/// sub-tab. Decoded from the drift `ClientDietEntries` row.
class ClientDietEntry {
  /// Creates a meal entry.
  const ClientDietEntry({
    required this.meal,
    required this.items,
    required this.calories,
    required this.sodiumMg,
    this.carbsG = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.photoUrl,
  });

  /// Meal label (아침 | 점심 | 저녁 | 간식).
  final String meal;

  /// Foods eaten, comma-joined (e.g. "오트밀, 바나나").
  final String items;

  /// Calories for this meal (kcal).
  final int calories;

  /// Sodium for this meal (mg).
  final int sodiumMg;

  /// Carbohydrates in this meal (g).
  final double carbsG;

  /// Protein in this meal (g).
  final double proteinG;

  /// Fat in this meal (g).
  final double fatG;

  /// API path of the photo the member uploaded for this meal (#699),
  /// relative to the API base. Null when the member recorded the meal before
  /// photos were stored, or the photo could not be saved — the card then
  /// reads exactly as it did before.
  ///
  /// 담당 트레이너 전용 경로다(`/trainer/clients/<id>/diet/photos/<photo>`).
  /// 회원 앱이 받는 경로와 다르며, 접근 판정은 서버가 담당 링크로 한다.
  final String? photoUrl;
}
