import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'report_pdf_actions_base.dart';

ReportPdfActions createReportPdfActions() => _NativeReportPdfActions();

class _NativeReportPdfActions implements ReportPdfActions {
  @override
  Future<void> save(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  @override
  Future<void> print(Uint8List bytes, String fileName) =>
      Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
}
