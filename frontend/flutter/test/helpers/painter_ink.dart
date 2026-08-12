import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rasterizes [painter] at [size] and counts the pixels it actually painted.
///
/// Chart entry animations live inside `CustomPaint`, so the widget tree says
/// nothing about whether a bar grew or an arc swept. Comparing ink across
/// frames does: more ink means more chart got drawn.
///
/// `Picture.toImage` is genuinely async, so this must run inside
/// [WidgetTester.runAsync] — calling it in the fake-async zone hangs the test.
Future<int> painterInk(CustomPainter painter, Size size) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final ui.Image image = await recorder.endRecording().toImage(
    size.width.ceil(),
    size.height.ceil(),
  );
  final ByteData pixels = (await image.toByteData())!;
  image.dispose();
  int ink = 0;
  for (int i = 3; i < pixels.lengthInBytes; i += 4) {
    if (pixels.getUint8(i) > 0) ink++;
  }
  return ink;
}
