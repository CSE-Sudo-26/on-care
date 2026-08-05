import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 골든 비교에 허용 오차를 둔다 — `test/golden/` 아래 테스트에만 적용된다
/// (`flutter_test_config.dart` 는 테스트 파일이 있는 디렉터리부터 위로 찾는다).
///
/// 왜 필요한가: 골든 PNG 는 찍은 머신의 글자 안티에일리어싱까지 그대로
/// 담는다. 팀원이 서로 다른 Mac 에서 `flutter test` 를 돌리면 레이아웃·색이
/// 완전히 같아도 글자 가장자리에서 픽셀이 어긋나 실패한다. 실제로
/// `--update-goldens` 로 baseline 을 다시 찍은 적이 있는데(a2b7f0c) 다른
/// 머신에서 또 깨졌다 — 재생성은 기준점만 옮길 뿐 반복을 끊지 못한다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final LocalFileComparator base = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _TolerantGoldenComparator(base.basedir);
  await testMain();
}

/// 관측된 머신 간 드리프트는 0.37%(3,848/1,036,800 px, 최대 채널 차이 80).
/// 0.5% 면 그 드리프트는 흡수하면서도 실제 회귀는 잡는다 — 색을 바꾸면 픽셀의
/// 10% 이상이, 버튼이 밀리면 수 %가 달라져 임계값을 훌쩍 넘는다.
const double _kGoldenDiffTolerance = 0.005;

class _TolerantGoldenComparator extends LocalFileComparator {
  /// [LocalFileComparator] 는 생성자에서 테스트 파일 Uri 를 받아 그 부모를
  /// basedir 로 삼는다. 이미 계산된 basedir 을 그대로 쓰려고 더미 파일명을 붙인다.
  _TolerantGoldenComparator(Uri basedir)
    : super(basedir.resolve('flutter_test_config.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= _kGoldenDiffTolerance) {
      debugPrint(
        '골든 "$golden": 차이 ${(result.diffPercent * 100).toStringAsFixed(2)}% '
        '— 허용 오차 ${(_kGoldenDiffTolerance * 100).toStringAsFixed(1)}% 이내라 통과 '
        '(머신 간 안티에일리어싱 차이로 간주).',
      );
      // 통과시켜도 실패 산출물은 남기지 않는다 — 디스크에 쓰레기를 만들지 않게.
      result.dispose();
      return true;
    }
    // 임계값을 넘으면 기존과 동일하게 test/golden/failures/ 에 비교 이미지를
    // 남기고 실패시킨다.
    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
