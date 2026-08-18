import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// WeeklyReport를 화면 측정값과 분리된 A4 문서로 만든다.
///
/// 한글은 Flutter의 플랫폼 font fallback으로 페이지에 rasterize한 뒤
/// PDF에 삽입한다. 외부 폰트를 받거나 앱 UI를 스크린샷하지 않고,
/// 리포트 데이터로 문서 레이아웃을 새로 그린다.
class ReportPdfGenerator {
  const ReportPdfGenerator();

  static const int _pageWidth = 1240;
  static const int _pageHeight = 1754;
  static const double _margin = 92;

  Future<Uint8List> generate({
    required WeeklyReport report,
    required String feedback,
    WeeklyReport? previousReport,
  }) async {
    final blocks = _blocks(report, feedback, previousReport);
    final pageImages = <Uint8List>[];
    var recorder = ui.PictureRecorder();
    var canvas = Canvas(recorder);
    double y = _beginPage(canvas, report, 1);
    var pageNumber = 1;

    for (final block in blocks) {
      final painter = TextPainter(
        text: TextSpan(text: block.text, style: block.style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(maxWidth: _pageWidth - (_margin * 2));
      if (y + painter.height + block.after > _pageHeight - _margin) {
        pageImages.add(await _finishPage(recorder));
        recorder = ui.PictureRecorder();
        canvas = Canvas(recorder);
        pageNumber++;
        y = _beginPage(canvas, report, pageNumber);
      }
      painter.paint(canvas, Offset(_margin, y));
      y += painter.height + block.after;
    }
    pageImages.add(await _finishPage(recorder));

    final document = pw.Document();
    for (final image in pageImages) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(
            pw.MemoryImage(image),
            width: PdfPageFormat.a4.width,
            height: PdfPageFormat.a4.height,
            fit: pw.BoxFit.fill,
          ),
        ),
      );
    }
    return document.save();
  }

  /// PDF에 그려질 문서 문구. 렌더러와 테스트가 같은 소스를 쓴다.
  List<String> textContent({
    required WeeklyReport report,
    required String feedback,
    WeeklyReport? previousReport,
  }) => _blocks(
    report,
    feedback,
    previousReport,
  ).map((block) => block.text).toList(growable: false);

  double _beginPage(Canvas canvas, WeeklyReport report, int pageNumber) {
    canvas.drawColor(Colors.white, BlendMode.src);
    final title = pageNumber == 1 ? '주간 코칭 리포트' : '주간 코칭 리포트 (계속)';
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xff173b36),
          fontSize: 38,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _pageWidth - (_margin * 2));
    titlePainter.paint(canvas, const Offset(_margin, 72));
    canvas.drawRect(
      const Rect.fromLTWH(_margin, 132, _pageWidth - _margin * 2, 4),
      Paint()..color = const Color(0xff2f776d),
    );
    return 166;
  }

  Future<Uint8List> _finishPage(ui.PictureRecorder recorder) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(_pageWidth, _pageHeight);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('PDF 페이지를 생성하지 못했습니다.');
    return data.buffer.asUint8List();
  }

  List<_PdfBlock> _blocks(
    WeeklyReport report,
    String feedback,
    WeeklyReport? previous,
  ) {
    final start = _date(report.weekStart);
    final end = _date(report.weekEnd);
    final completion = _value(report.completionAvg, '%');
    final attendance = report.sessionsBooked == 0
        ? '미집계'
        : '${report.sessionsDone}/${report.sessionsBooked}회 (${report.attendanceRate}%)';
    final calories = recordedMean(report.caloriesWeek)?.round();
    final sugar = recordedMean(report.sugarWeek);
    final blocks = <_PdfBlock>[
      _PdfBlock.body('고객  ${report.client.name}'),
      _PdfBlock.body('기간  $start ~ $end'),
      _PdfBlock.section('핵심 지표'),
      _PdfBlock.body('• 운동 수행률: $completion'),
      _PdfBlock.body('• PT 진행: $attendance'),
      _PdfBlock.body('• 평균 나트륨: ${_value(report.sodiumAvg, 'mg')}'),
      _PdfBlock.body('• 나트륨 목표 초과: ${_value(report.sodiumOverDays, '일')}'),
      _PdfBlock.body('• 평균 열량: ${_value(calories, 'kcal')}'),
      _PdfBlock.body(
        '• 평균 당류: ${sugar == null ? '미집계' : '${sugar.toStringAsFixed(1)}g'}',
      ),
      _PdfBlock.section('전주 대비 변화'),
      _PdfBlock.body(
        _comparison(
          '운동 수행률',
          report.completionAvg,
          previous?.completionAvg,
          '%',
        ),
      ),
      _PdfBlock.body(
        _comparison('평균 나트륨', report.sodiumAvg, previous?.sodiumAvg, 'mg'),
      ),
      _PdfBlock.body(
        _comparison(
          'PT 진행 횟수',
          report.sessionsDone,
          previous?.sessionsDone,
          '회',
        ),
      ),
      _PdfBlock.section('주간 추이 (월~일)'),
      _PdfBlock.body('• 운동 수행률: ${_series(report.weekCompletion, '%')}'),
      _PdfBlock.body('• 열량: ${_series(report.caloriesWeek, 'kcal')}'),
      _PdfBlock.body('• 나트륨: ${_series(report.sodiumWeek, 'mg')}'),
      _PdfBlock.body('• 당류: ${_series(report.sugarWeek, 'g')}'),
      _PdfBlock.section('일자별 운동'),
    ];
    const weekdays = <String>['월', '화', '수', '목', '금', '토', '일'];
    for (var i = 0; i < report.days.length && i < weekdays.length; i++) {
      final day = report.days[i];
      final exercises = day.exercises.isEmpty
          ? '기록 없음'
          : day.exercises.join(', ');
      blocks.add(
        _PdfBlock.body(
          '${weekdays[i]}: ${day.completion == 0 ? '미집계' : '${day.completion}%'} · $exercises',
        ),
      );
    }
    blocks.add(_PdfBlock.section('트레이너 피드백'));
    for (final part in _chunks(feedback.trim().isEmpty ? '피드백 없음' : feedback)) {
      blocks.add(_PdfBlock.body(part, after: 12));
    }
    return blocks;
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _value(num? value, String unit) =>
      value == null ? '미집계' : '$value$unit';

  static String _comparison(
    String label,
    num? current,
    num? previous,
    String unit,
  ) {
    if (current == null || previous == null) return '• $label: 미집계';
    final change = current - previous;
    final prefix = change > 0 ? '+' : '';
    return '• $label: $prefix${change.toStringAsFixed(change is int ? 0 : 1)}$unit';
  }

  static String _series(List<num> values, String unit) {
    if (values.length != 7 || values.every((value) => value == 0)) return '미집계';
    return values.map((value) => value == 0 ? '-' : '$value$unit').join(' / ');
  }

  /// 코드 유닛이 아니라 코드 포인트(`runes`) 단위로 자른다. `substring` 은 UTF-16
  /// 경계에서 자르므로, 트레이너가 피드백에 이모지를 쓰면 서로게이트 쌍 중간이
  /// 끊겨 글자가 깨진다.
  static Iterable<String> _chunks(String text) sync* {
    for (final paragraph in text.split('\n')) {
      if (paragraph.isEmpty) {
        yield '';
        continue;
      }
      final runes = paragraph.runes.toList(growable: false);
      for (var start = 0; start < runes.length; start += 180) {
        final end = start + 180 < runes.length ? start + 180 : runes.length;
        yield String.fromCharCodes(runes.sublist(start, end));
      }
    }
  }
}

final reportPdfGeneratorProvider = Provider<ReportPdfGenerator>(
  (_) => const ReportPdfGenerator(),
);

class _PdfBlock {
  const _PdfBlock(this.text, this.style, this.after);

  factory _PdfBlock.section(String text) => _PdfBlock(
    text,
    const TextStyle(
      color: Color(0xff173b36),
      fontSize: 25,
      fontWeight: FontWeight.w800,
      height: 1.35,
    ),
    16,
  );

  factory _PdfBlock.body(String text, {double after = 9}) => _PdfBlock(
    text,
    const TextStyle(color: Color(0xff263331), fontSize: 20, height: 1.5),
    after,
  );

  final String text;
  final TextStyle style;
  final double after;
}
