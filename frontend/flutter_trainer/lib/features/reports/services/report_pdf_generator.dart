import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// 값에 단위를 붙이는 arb 패턴. `l.reportsPdfValueMg` 처럼 tear-off 로 넘긴다 —
/// `1890mg` 와 `2 days` 처럼 단위가 붙는 자리와 띄어쓰기가 언어마다 다르다.
typedef _Unit = String Function(String value);

/// WeeklyReport를 화면 측정값과 분리된 A4 문서로 만든다.
///
/// 한글은 Flutter의 플랫폼 font fallback으로 페이지에 rasterize한 뒤
/// PDF에 삽입한다. 외부 폰트를 받거나 앱 UI를 스크린샷하지 않고,
/// 리포트 데이터로 문서 레이아웃을 새로 그린다.
///
/// 문구는 전부 [AppLocalizations] 에서 온다. 이 PDF 는 회원이 실제로 받아 보는
/// 산출물이라, 화면은 영어인데 문서만 한국어로 나가면 안 된다(#964).
class ReportPdfGenerator {
  const ReportPdfGenerator();

  static const int _pageWidth = 1240;
  static const int _pageHeight = 1754;
  static const double _margin = 92;

  Future<Uint8List> generate({
    required AppLocalizations l,
    required WeeklyReport report,
    required String feedback,
    WeeklyReport? previousReport,
  }) async {
    final blocks = _blocks(l, report, feedback, previousReport);
    final pageImages = <Uint8List>[];
    var recorder = ui.PictureRecorder();
    var canvas = Canvas(recorder);
    double y = _beginPage(canvas, l, 1);
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
        y = _beginPage(canvas, l, pageNumber);
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
    required AppLocalizations l,
    required WeeklyReport report,
    required String feedback,
    WeeklyReport? previousReport,
  }) => _blocks(
    l,
    report,
    feedback,
    previousReport,
  ).map((block) => block.text).toList(growable: false);

  double _beginPage(Canvas canvas, AppLocalizations l, int pageNumber) {
    canvas.drawColor(Colors.white, BlendMode.src);
    final title = pageNumber == 1
        ? l.reportsPdfDocTitle
        : l.reportsPdfDocTitleContinued;
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
    // 화면에 뜨지 않는 내부 오류다 — 호출부가 잡아서 로케일이 붙은
    // `reportsPdfGenerationFailed` 를 대신 보여 준다.
    if (data == null) throw StateError('failed to rasterize a PDF page');
    return data.buffer.asUint8List();
  }

  List<_PdfBlock> _blocks(
    AppLocalizations l,
    WeeklyReport report,
    String feedback,
    WeeklyReport? previous,
  ) {
    final completion = _value(
      l,
      report.completionAvg,
      l.reportsPdfValuePercent,
    );
    final attendance = report.sessionsBooked == 0
        ? l.reportsPdfNoData
        : l.reportsPdfAttendance(
            '${report.sessionsDone}',
            '${report.sessionsBooked}',
            '${report.attendanceRate}',
          );
    final calories = recordedMean(report.caloriesWeek)?.round();
    final sugar = recordedMean(report.sugarWeek);
    final blocks = <_PdfBlock>[
      _PdfBlock.body(l.reportsPdfClient(report.client.name)),
      _PdfBlock.body(
        l.reportsPdfPeriod(_date(report.weekStart), _date(report.weekEnd)),
      ),
      _PdfBlock.section(l.reportsPdfSectionMetrics),
      _bullet(l, l.reportsPdfLabelCompletion, completion),
      _bullet(l, l.reportsPdfLabelSessions, attendance),
      _bullet(
        l,
        l.reportsAverageSodium,
        _value(l, report.sodiumAvg, l.reportsPdfValueMg),
      ),
      _bullet(
        l,
        l.reportsPdfLabelSodiumOver,
        _value(l, report.sodiumOverDays, l.reportsPdfValueDays),
      ),
      _bullet(
        l,
        l.reportsPdfLabelCalories,
        _value(l, calories, l.reportsPdfValueKcal),
      ),
      _bullet(
        l,
        l.reportsPdfLabelSugar,
        sugar == null
            ? l.reportsPdfNoData
            : l.reportsPdfValueGram(sugar.toStringAsFixed(1)),
      ),
      _PdfBlock.section(l.reportsPdfSectionChange),
      _PdfBlock.body(
        _comparison(
          l,
          l.reportsPdfLabelCompletion,
          report.completionAvg,
          previous?.completionAvg,
          l.reportsPdfValuePercent,
        ),
      ),
      _PdfBlock.body(
        _comparison(
          l,
          l.reportsAverageSodium,
          report.sodiumAvg,
          previous?.sodiumAvg,
          l.reportsPdfValueMg,
        ),
      ),
      _PdfBlock.body(
        _comparison(
          l,
          l.reportsPdfLabelSessionCount,
          report.sessionsDone,
          previous?.sessionsDone,
          l.reportsPdfValueSessions,
        ),
      ),
      _PdfBlock.section(l.reportsPdfSectionTrend),
      _bullet(
        l,
        l.reportsPdfLabelCompletion,
        _series(l, report.weekCompletion, l.reportsPdfValuePercent),
      ),
      _bullet(
        l,
        l.reportsPdfLabelCaloriesShort,
        _series(l, report.caloriesWeek, l.reportsPdfValueKcal),
      ),
      _bullet(
        l,
        l.reportsPdfLabelSodiumShort,
        _series(l, report.sodiumWeek, l.reportsPdfValueMg),
      ),
      _bullet(
        l,
        l.reportsPdfLabelSugarShort,
        _series(l, report.sugarWeek, l.reportsPdfValueGram),
      ),
      _PdfBlock.section(l.reportsPdfSectionDaily),
    ];
    final weekdays = weekdayNames(l);
    for (var i = 0; i < report.days.length && i < weekdays.length; i++) {
      final day = report.days[i];
      blocks.add(
        _PdfBlock.body(
          l.reportsPdfDay(
            weekdays[i],
            day.completion == 0
                ? l.reportsPdfNoData
                : l.reportsPdfValuePercent('${day.completion}'),
            day.exercises.isEmpty ? l.chartNoRecord : day.exercises.join(', '),
          ),
        ),
      );
    }
    blocks.add(_PdfBlock.section(l.reportsFeedbackTitle));
    final body = feedback.trim().isEmpty ? l.reportsPdfNoFeedback : feedback;
    for (final part in _chunks(body)) {
      blocks.add(_PdfBlock.body(part, after: 12));
    }
    return blocks;
  }

  static _PdfBlock _bullet(AppLocalizations l, String label, String value) =>
      _PdfBlock.body(l.reportsPdfBullet(label, value));

  /// 문서에 남는 날짜는 두 로케일 모두 `YYYY-MM-DD` 다. 화면의 `8월 5일` 과
  /// 달리 PDF 는 회원이 저장해 두고 나중에 다시 여는 파일이라 연도가 필요하고,
  /// `08/05` 처럼 월·일 순서를 두고 헷갈릴 여지가 없어야 한다. 자리(구분자·
  /// 앞뒤 문구)는 `reportsPdfPeriod` 가 로케일별로 정한다.
  static String _date(DateTime value) => ymd(value);

  static String _value(AppLocalizations l, num? value, _Unit unit) =>
      value == null ? l.reportsPdfNoData : unit('$value');

  static String _comparison(
    AppLocalizations l,
    String label,
    num? current,
    num? previous,
    _Unit unit,
  ) {
    if (current == null || previous == null) {
      return l.reportsPdfBullet(label, l.reportsPdfNoData);
    }
    final change = current - previous;
    final prefix = change > 0 ? '+' : '';
    return l.reportsPdfBullet(
      label,
      unit('$prefix${change.toStringAsFixed(change is int ? 0 : 1)}'),
    );
  }

  static String _series(AppLocalizations l, List<num> values, _Unit unit) {
    if (values.length != 7 || values.every((value) => value == 0)) {
      return l.reportsPdfNoData;
    }
    return values.map((value) => value == 0 ? '-' : unit('$value')).join(' / ');
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
