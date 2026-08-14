/// Daily sodium target (mg). Over this, the list card metric, the diet
/// summary tile, and the AI comment all flip to the warning case.
const int sodiumTargetMg = 2000;

/// Daily calorie target (kcal). The weekly trend chart colours a day red
/// above this, the same way the member app's home tab does.
const int calorieTargetKcal = 2000;

/// Daily sugar target (g). Over this, the diet summary 당류 tile warns.
const int sugarTargetG = 50;

/// A trainer's client, as shown on the 고객 관리 list and detail screens.
/// Decoded from the drift `TrainerClients` row (the `weekCompletionJson`
/// column becomes a `List<int>` here).
class TrainerClient {
  /// Creates a client.
  const TrainerClient({
    required this.id,
    required this.name,
    required this.avatar,
    required this.goal,
    required this.lastMessage,
    required this.lastTime,
    required this.active,
    required this.calories,
    required this.sodiumMg,
    required this.sugarG,
    this.carbsG = 0,
    this.proteinG = 0,
    this.fatG = 0,
    required this.lastRoutine,
    required this.weekCompletion,
    required this.sodiumWeek,
    this.caloriesWeek = const <int>[],
    this.sugarWeek = const <double>[],
    this.gender = '',
    this.age,
  });

  /// Row id (e.g. `seed-client-1`).
  final String id;

  /// Display name (e.g. 김민수).
  final String name;

  /// Single-char avatar label (e.g. 김).
  final String avatar;

  /// Optional roster demographic supplied by the API (`male` / `female` /
  /// `other`). Older API and local-demo rows do not carry it yet.
  final String gender;

  /// Optional international age supplied by the API.
  final int? age;

  /// Goal label (e.g. 혈압 관리 · 체중 감량).
  final String goal;

  /// Preview of the most recent chat message.
  final String lastMessage;

  /// Relative time label for [lastMessage] (e.g. 방금).
  final String lastTime;

  /// Whether the client is currently active.
  final bool active;

  /// Today's total calories (kcal).
  final int calories;

  /// Today's sodium (mg).
  final int sodiumMg;

  /// Today's sugar (g).
  final double sugarG;

  /// Today's carbohydrate intake (g).
  final double carbsG;

  /// Today's protein intake (g).
  final double proteinG;

  /// Today's fat intake (g).
  final double fatG;

  /// Label for the last routine sent (e.g. 오늘 / 어제 / 5일 전).
  final String lastRoutine;

  /// This week's daily completion rates (7 entries, 월→일).
  final List<int> weekCompletion;

  /// Last 7 days of daily sodium (mg), oldest→today (index 6 == today's
  /// [sodiumMg]). Empty for pre-v2 rows (before the next re-seed
  /// backfills it).
  final List<int> sodiumWeek;

  /// 최근 7일 일별 칼로리·당류. [sodiumWeek] 와 같은 창이라 한 그래프에서 지표만
  /// 바꿔 볼 수 있다(#746). 당류는 소수를 유지한다.
  final List<int> caloriesWeek;
  final List<double> sugarWeek;

  /// Stable display gender for roster rows that predate demographic fields.
  ///
  /// The demo roster is presentation fixture data. Keeping the fallback on
  /// the stable client id means same-name members still receive distinct,
  /// repeatable identity details without changing the persisted Drift schema.
  String get rosterGender {
    if (gender == 'male' || gender == 'female' || gender == 'other') {
      return gender;
    }
    return _demographicSeed.isEven ? 'female' : 'male';
  }

  /// Roster age, constrained to the requested twenties/thirties fixture range
  /// when the source does not provide one.
  int get rosterAge => age ?? 20 + (_demographicSeed % 20);

  int get _demographicSeed => id.runes.fold<int>(0, (sum, rune) => sum + rune);

  /// Sodium exceeds the [sodiumTargetMg] daily target — surfaced as a
  /// warning on the list card and counted by the AI summary.
  bool get sodiumOverBudget => sodiumMg > sodiumTargetMg;

  /// Sugar exceeds the [sugarTargetG] daily target.
  bool get sugarOverBudget => sugarG > sugarTargetG;

  /// Days in [sodiumWeek] that were over the daily target.
  int get sodiumOverDays =>
      sodiumWeek.where((mg) => mg > sodiumTargetMg).length;

  /// 이번 주 평균 나트륨(mg), 기록이 없으면 `null`.
  ///
  /// **기록된 날만** 나눈다. 주간 계열이 월→일로 고정되면서 아직 오지 않은
  /// 요일이 0 으로 들어오는데, 그 0 까지 나누면 주 초반에는 평균이 실제보다
  /// 낮게 나와 주의 배지가 조용해진다. 이행률 평균(`recordedCompletionMean`)
  /// 이 쓰는 규칙과 같다.
  int? get sodiumWeekAvg {
    final recorded = sodiumWeek.where((mg) => mg > 0).toList(growable: false);
    if (recorded.isEmpty) return null;
    return (recorded.reduce((a, b) => a + b) / recorded.length).round();
  }
}
