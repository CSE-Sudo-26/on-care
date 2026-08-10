/// One meal in a client's day (아침/점심/저녁), as shown on the 식단
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
  });

  /// Meal label (아침 | 점심 | 저녁).
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
}
