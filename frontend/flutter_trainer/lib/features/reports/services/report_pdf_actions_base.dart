import 'dart:typed_data';

abstract interface class ReportPdfActions {
  Future<void> save(Uint8List bytes, String fileName);
  Future<void> print(Uint8List bytes, String fileName);
}
