/// 홈 "AI 추천 식단" 카드 1장에 해당하는 추천 결과.
///
/// 서버는 요리명·태그 같은 **문자열을 내려주지 않는다.** 카드에 쓰이는 사진은 앱
/// 번들 에셋(`assets/images/rec-*`)이고 문구는 로케일별 ARB(`homeMeal*`)라, 서버가
/// 텍스트를 생성하면 영어 화면에 한국어가 섞이고 사진이 없는 요리가 나온다.
///
/// 그래서 계약은 "서버는 [key]로 무엇을 어떤 순서로 보여줄지만 정하고, 그리기는
/// 앱이 한다"이다. [reasonText]만 예외로, 서버가 사용자 수치를 근거로 쓴 개인화
/// 문구가 있으면 담긴다(없으면 앱이 [reasonKey]의 기본 문구를 쓴다).
class MealRecommendation {
  const MealRecommendation({
    required this.key,
    required this.reasonKey,
    this.reasonText,
  });

  factory MealRecommendation.fromJson(Map<String, Object?> json) {
    return MealRecommendation(
      key: json['key']! as String,
      reasonKey: (json['reason_key'] as String?) ?? '',
      reasonText: json['reason_text'] as String?,
    );
  }

  /// 서버 카탈로그와 공유하는 요리 식별자(예: `chicken_salad`).
  final String key;

  /// 추천 이유 코드(예: `sodium`). 앱이 l10n 문구로 번역한다.
  final String reasonKey;

  /// 서버(LLM)가 쓴 개인화 문구. null 이면 [reasonKey] 기본 문구를 쓴다.
  final String? reasonText;
}

/// 서버 카탈로그와 짝을 이루는 기본 노출 순서.
///
/// 홈 화면이 서버 응답을 받기 전(첫 프레임)과 실패했을 때 그리는 순서이고,
/// 목업 모드가 그대로 돌려주는 순서이기도 하다. 값과 순서는 백엔드
/// `app/data/meal_catalog.py` 의 `DEFAULT_ORDER` 와 일치해야 한다.
const List<String> kDefaultMealKeys = <String>[
  'chicken_salad',
  'brown_rice_box',
  'salmon',
  'tofu',
  'namul_bibimbap',
];

/// GET /diet/recommendations 응답 전체.
class MealRecommendations {
  const MealRecommendations({
    required this.items,
    this.basis,
    this.personalized = false,
  });

  factory MealRecommendations.fromJson(Map<String, Object?> json) {
    final raw = (json['items'] as List<Object?>? ?? const <Object?>[]);
    return MealRecommendations(
      items: <MealRecommendation>[
        for (final Object? item in raw)
          MealRecommendation.fromJson(item! as Map<String, Object?>),
      ],
      basis: json['basis'] as String?,
      personalized: (json['personalized'] as bool?) ?? false,
    );
  }

  final List<MealRecommendation> items;

  /// 추천 근거 한 줄(예: "최근 3일 평균 나트륨 2,400mg · 권장 초과").
  /// 개인화가 실제로 일어났는지 화면에서 확인할 수 있게 서버가 채워 준다.
  final String? basis;

  /// false 면 근거 데이터가 없어 기본 순서로 내려온 것이다.
  final bool personalized;

  /// 서버를 아직 못 받았거나 실패했을 때 그리는 기본 추천.
  ///
  /// `reasonText` 를 비워 두므로 카드 문구는 앱의 l10n 기본값(`homeMealReason*`)이
  /// 쓰이고, 결과적으로 화면이 서버 연동 이전과 완전히 동일해진다.
  static const MealRecommendations fallback = MealRecommendations(
    items: <MealRecommendation>[
      MealRecommendation(key: 'chicken_salad', reasonKey: 'sodium'),
      MealRecommendation(key: 'brown_rice_box', reasonKey: 'glucose'),
      MealRecommendation(key: 'salmon', reasonKey: 'omega'),
      MealRecommendation(key: 'tofu', reasonKey: 'low_cal'),
      MealRecommendation(key: 'namul_bibimbap', reasonKey: 'fiber'),
    ],
  );
}
