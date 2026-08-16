// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'report_pdf_actions_base.dart';

ReportPdfActions createReportPdfActions() => _WebReportPdfActions();

class _WebReportPdfActions implements ReportPdfActions {
  @override
  Future<void> save(Uint8List bytes, String fileName) async {
    final blob = html.Blob(<Object>[bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      html.AnchorElement(href: url)
        ..download = fileName
        ..click();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Future<void> print(Uint8List bytes, String fileName) =>
      Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
}
