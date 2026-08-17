import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// 생성한 PDF를 내보내는 두 가지 방법. 테스트가 갈아끼울 수 있도록 인터페이스로
/// 둔다 — 위젯 테스트에서 실제 저장·인쇄 창을 띄울 수는 없다.
abstract interface class ReportPdfActions {
  Future<void> save(Uint8List bytes, String fileName);
  Future<void> print(Uint8List bytes, String fileName);
}

/// `printing` 은 웹·Wasm·네이티브를 모두 지원하고, 웹에서 [Printing.sharePdf] 는
/// 브라우저 다운로드로 동작한다. 예전에는 웹만 `dart:html` 로 직접 Blob·앵커를
/// 다뤘는데, Object URL 을 `click()` 직후 해제해 Safari·Firefox 에서 다운로드가
/// 조용히 실패할 수 있었다. 해제 시점을 손으로 맞추는 대신 플랫폼 구현을 하나로
/// 합쳐 그 문제를 없앴다 — deprecated 된 `dart:html` 의존도 함께 사라진다.
class _PrintingReportPdfActions implements ReportPdfActions {
  const _PrintingReportPdfActions();

  @override
  Future<void> save(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  @override
  Future<void> print(Uint8List bytes, String fileName) =>
      Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
}

final reportPdfActionsProvider = Provider<ReportPdfActions>(
  (_) => const _PrintingReportPdfActions(),
);
