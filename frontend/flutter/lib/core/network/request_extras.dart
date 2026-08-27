/// 요청에 실려 나가지 않고 **인터셉터에게만** 전해지는 값들의 키.
///
/// dio 의 `RequestOptions.extra` 는 로컬 전용이라 네트워크로 나가지 않는다.
library;

/// 방금 고른 끼니 사진의 원본 바이트(`Uint8List`).
///
/// 데모 백엔드(`LocalApiInterceptor`)가 이 바이트를 기록에 함께 저장해
/// `/diet/photos/{entry id}` 로 돌려준다 — 그래야 사진을 찍어 추가한 끼니가
/// 목록·상세의 카드에서 **그 사진으로** 보인다(실서버에 붙었을 때와 같다).
///
/// multipart 본문에서 다시 꺼내지 않고 따로 싣는 이유: `MultipartFile` 의
/// 바이트 스트림은 한 번만 읽을 수 있어서, 인터셉터가 읽어 버리면 정작 실
/// 서버로 나가야 할 요청의 본문이 비고, 실 서버가 처리한 요청(REAL_API=diet)은
/// 이미 다 읽혀 있어 응답 시점에는 남아 있지 않다.
const String kMealPhotoBytesExtra = 'meal_photo_bytes';
