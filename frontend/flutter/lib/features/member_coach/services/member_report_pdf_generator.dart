import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare/features/member_coach/domain/entities/member_weekly_report.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// 값에 단위를 붙이는 arb 패턴. `l.coachReportPdfValueMg` 처럼 tear-off 로 넘긴다
/// — `1890mg` 와 `2 days` 처럼 단위가 붙는 자리와 띄어쓰기가 언어마다 다르다.
typedef _Unit = String Function(String value);

/// [MemberWeeklyReport] 를 A4 문서로 만든다. (#1600)
///
/// 트레이너 앱의 `ReportPdfGenerator` 와 같은 방법이다 — 한글은 Flutter 의
/// 플랫폼 폰트 대체로 페이지에 그린 뒤 그림으로 PDF 에 넣는다. 외부 폰트를
/// 받지도, 앱 화면을 스크린샷하지도 않는다.
///
/// 문구는 전부 [AppLocalizations] 에서 온다 — 화면은 영어인데 문서만 한국어로
/// 열리면 안 된다.
class MemberReportPdfGenerator {
  /// Creates the generator.
  const MemberReportPdfGenerator();

  static const int _pageWidth = 1240;
  static const int _pageHeight = 1754;
  static const double _margin = 92;

  /// 리포트 한 부를 PDF 바이트로 만든다.
  Future<Uint8List> generate({
    required AppLocalizations l,
    required MemberWeeklyReport report,
    String trainerNote = '',
  }) async {
    final List<_Block> blocks = _blocks(l, report, trainerNote);
    final List<Uint8List> pageImages = <Uint8List>[];
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    double y = _beginPage(canvas, l, 1);
    int pageNumber = 1;

    const double contentWidth = _pageWidth - (_margin * 2);
    for (final _Block block in blocks) {
      final double height = block.height(contentWidth);
      if (y + height + block.after > _pageHeight - _margin) {
        pageImages.add(await _finishPage(recorder));
        recorder = ui.PictureRecorder();
        canvas = Canvas(recorder);
        pageNumber++;
        y = _beginPage(canvas, l, pageNumber);
      }
      block.paint(canvas, Offset(_margin, y), contentWidth);
      y += height + block.after;
    }
    pageImages.add(await _finishPage(recorder));

    final pw.Document document = pw.Document();
    for (final Uint8List image in pageImages) {
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

  /// 문서에 적히는 문구. 렌더러와 테스트가 같은 소스를 쓴다.
  List<String> textContent({
    required AppLocalizations l,
    required MemberWeeklyReport report,
    String trainerNote = '',
  }) => _blocks(
    l,
    report,
    trainerNote,
  ).expand((_Block block) => block.textLines).toList(growable: false);

  double _beginPage(Canvas canvas, AppLocalizations l, int pageNumber) {
    canvas.drawColor(Colors.white, BlendMode.src);
    final String title = pageNumber == 1
        ? l.coachReportPdfDocTitle
        : l.coachReportPdfDocTitleContinued;
    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xff10384a),
          fontSize: 38,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _pageWidth - (_margin * 2));
    titlePainter.paint(canvas, const Offset(_margin, 72));
    canvas.drawRect(
      const Rect.fromLTWH(_margin, 132, _pageWidth - _margin * 2, 4),
      Paint()..color = const Color(0xff3eafdf),
    );
    return 166;
  }

  Future<Uint8List> _finishPage(ui.PictureRecorder recorder) async {
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(_pageWidth, _pageHeight);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    picture.dispose();
    // 화면에 뜨지 않는 내부 오류다 — 호출부가 잡아서 로케일이 붙은 실패 문구를
    // 대신 보여 준다.
    if (data == null) throw StateError('failed to rasterize a PDF page');
    return data.buffer.asUint8List();
  }

  List<_Block> _blocks(
    AppLocalizations l,
    MemberWeeklyReport report,
    String trainerNote,
  ) {
    final List<String> weekdays = <String>[
      l.dietWeekdayMon,
      l.dietWeekdayTue,
      l.dietWeekdayWed,
      l.dietWeekdayThu,
      l.dietWeekdayFri,
      l.dietWeekdaySat,
      l.dietWeekdaySun,
    ];
    final int loggedDays = report.diet.loggedDays;
    final MemberWeeklyReport? last = report.previous;

    return <_Block>[
      // 머리띠 — 언제, 얼마나. 아래 표와 그래프를 무엇에 견줄지가 여기서 정해진다.
      _BandBlock(
        text: l.coachReportPdfPeriod(
          _date(report.weekStart),
          _date(report.weekEnd),
        ),
        // 띠가 말하는 값도 글로 남긴다 — 표·그래프와 같은 규칙이다.
        textLines: <String>[
          l.coachReportPdfPeriod(
            _date(report.weekStart),
            _date(report.weekEnd),
          ),
          l.coachReportPdfBullet(
            l.coachReportPdfLabelWorkoutDays,
            l.coachReportPdfValueDays('${report.workoutDays}'),
          ),
          l.coachReportPdfBullet(
            l.coachReportPdfLabelWorkoutMinutes,
            _value(
              l,
              report.exercise.totalMinutes,
              l.coachReportPdfValueMinutes,
            ),
          ),
          l.coachReportPdfBullet(
            report.sessionsBooked == 0 && report.sessionsDone > 0
                ? l.coachReportPdfLabelPtDone
                : l.coachReportPdfLabelSessions,
            _sessions(l, report),
          ),
        ],
        cells: <(String, String, double)>[
          (
            l.coachReportPdfBandPeriod,
            '${_date(report.weekStart)} ~ ${_date(report.weekEnd)}',
            1.8,
          ),
          (
            l.coachReportPdfLabelWorkoutDays,
            l.coachReportPdfValueDays('${report.workoutDays}'),
            1,
          ),
          (
            l.coachReportPdfLabelWorkoutMinutes,
            _value(
              l,
              report.exercise.totalMinutes,
              l.coachReportPdfValueMinutes,
            ),
            1,
          ),
          (l.coachReportPdfLabelSessions, _sessions(l, report), 1.1),
        ],
      ),

      _TextBlock.section(l.coachReportPdfSectionTrainerNote),
      _TextBlock.body(
        trainerNote.trim().isEmpty
            ? l.coachReportPdfNoTrainerNote
            : trainerNote.trim(),
      ),

      // 같은 지표의 이번 주·지난주·변화가 한 줄에 선다. 예전에는 `주요 지표` 와
      // `지난주 대비` 로 나뉘어 있어, 같은 값을 두 곳에서 찾아 견줘야 했다.
      _TextBlock.section(l.coachReportPdfSectionMetrics),
      () {
        final List<List<String>> rows = _metricRows(
          l,
          report,
          last,
          loggedDays,
        );
        return _TableBlock(
          text: l.coachReportPdfSectionMetrics,
          header: <String>[
            l.coachReportPdfColumnMetric,
            l.coachReportPdfColumnThisWeek,
            l.coachReportPdfColumnLastWeek,
            l.coachReportPdfColumnChange,
          ],
          weights: const <double>[0.4, 0.2, 0.2, 0.2],
          rows: rows,
          textLines: <String>[
            for (final List<String> row in rows)
              row[2].isEmpty
                  ? l.coachReportPdfBullet(row[0], row[1])
                  : l.coachReportPdfChange(row[0], row[1], row[2], row[3]),
          ],
        );
      }(),

      // 지난주 칸이 통째로 비면 왜 비었는지 말해 준다 — 빈 칸만 남기면 그 주에
      // 아무 일도 없었던 것으로 읽힌다.
      if (last == null ||
          (last.exercise.totalMinutes == 0 && last.loggedDays == 0))
        _TextBlock.body(l.coachReportPdfNoPreviousWeek),

      // 평균 하나를 숫자로만 적으면 그것이 회원 목표에 견줘 어디쯤인지 읽는
      // 사람이 계산해야 한다.
      if (loggedDays > 0) ...<_Block>[
        _TextBlock.section(l.coachReportPdfSectionGoals),
        ..._gauges(l, report),
      ],

      _TextBlock.section(l.coachReportPdfSectionTrend),
      _chart(
        l,
        report,
        weekdays,
        title: l.coachReportPdfLabelMinutesShort,
        values: report.minutesByDay,
        unit: l.coachReportPdfValueMinutes,
      ),
      _chart(
        l,
        report,
        weekdays,
        title: l.coachReportPdfLabelCaloriesShort,
        values: report.caloriesByDay.map((int v) => v.toDouble()).toList(),
        unit: l.coachReportPdfValueKcal,
      ),
      _chart(
        l,
        report,
        weekdays,
        title: l.coachReportPdfLabelSodiumShort,
        values: report.sodiumByDay.map((int v) => v.toDouble()).toList(),
        unit: l.coachReportPdfValueMg,
        target: report.sodiumTarget?.toDouble(),
      ),

      _TextBlock.section(l.coachReportPdfSectionDaily),
      _TableBlock(
        text: l.coachReportPdfSectionDaily,
        header: <String>[
          l.coachReportPdfColumnWeekday,
          l.coachReportPdfColumnWorkout,
          l.coachReportPdfColumnIntake,
        ],
        weights: const <double>[0.12, 0.66, 0.22],
        alignRightFrom: 2,
        rows: <List<String>>[
          for (int i = 0; i < weekdays.length; i++)
            _dailyRow(l, report, weekdays, i),
        ],
        // 표가 아니라 글이던 시절의 줄과 같은 문장이다 — 문서가 말하는 값이
        // 배치를 바꿨다고 달라지지는 않는다.
        textLines: <String>[
          for (int i = 0; i < weekdays.length; i++)
            if (report.isUpcoming(i))
              l.coachReportPdfDayUpcoming(weekdays[i])
            else
              l.coachReportPdfDay(
                weekdays[i],
                report.exercisesOn(i, weekdays).isEmpty
                    ? l.coachReportPdfNoData
                    : report.exercisesOn(i, weekdays).join(', '),
                (i < report.caloriesByDay.length
                            ? report.caloriesByDay[i]
                            : 0) ==
                        0
                    ? l.coachReportPdfNoData
                    : l.coachReportPdfValueKcal('${report.caloriesByDay[i]}'),
              ),
        ],
      ),

      if (report.sodiumTarget case final int target when loggedDays > 0)
        _TextBlock.body(l.coachReportPdfSodiumTargetNote('$target')),
      _TextBlock.body(l.coachReportPdfPreviewNote, after: 12),
    ];
  }

  /// 주간 요약 표의 본문. 지난주가 없으면 그 두 칸을 비운다 — 0 으로 적으면
  /// 아무것도 안 한 주가 된다.
  List<List<String>> _metricRows(
    AppLocalizations l,
    MemberWeeklyReport report,
    MemberWeeklyReport? last,
    int loggedDays,
  ) {
    final bool hasLast =
        last != null && (last.exercise.totalMinutes > 0 || last.loggedDays > 0);
    final bool bothLogged = loggedDays > 0 && (last?.loggedDays ?? 0) > 0;

    List<String> row(
      String label,
      String current, {
      num? now,
      num? then,
      _Unit? unit,
    }) {
      if (now == null || then == null || unit == null) {
        return <String>[label, current, '', ''];
      }
      final num delta = now - then;
      final String change = delta == 0
          ? l.coachReportPdfDeltaSame
          : delta > 0
          ? l.coachReportPdfDeltaUp(unit(_trim(delta.toDouble())))
          : l.coachReportPdfDeltaDown(unit(_trim(-delta.toDouble())));
      return <String>[label, current, unit(_trim(then.toDouble())), change];
    }

    return <List<String>>[
      row(
        l.coachReportPdfLabelWorkoutMinutes,
        _value(l, report.exercise.totalMinutes, l.coachReportPdfValueMinutes),
        now: hasLast ? report.exercise.totalMinutes : null,
        then: hasLast ? last.exercise.totalMinutes : null,
        unit: l.coachReportPdfValueMinutes,
      ),
      row(
        l.coachReportPdfLabelBurned,
        _value(l, report.exercise.totalCalories, l.coachReportPdfValueKcal),
        now: hasLast ? report.exercise.totalCalories : null,
        then: hasLast ? last.exercise.totalCalories : null,
        unit: l.coachReportPdfValueKcal,
      ),
      row(
        l.coachReportPdfLabelCardio,
        _sum(l, report.exercise.cardioMinutes, l.coachReportPdfValueMinutes),
      ),
      row(
        l.coachReportPdfLabelStrength,
        _sum(l, report.exercise.strengthMinutes, l.coachReportPdfValueMinutes),
      ),
      row(
        l.coachReportPdfLabelStretching,
        _sum(
          l,
          report.exercise.stretchingMinutes,
          l.coachReportPdfValueMinutes,
        ),
      ),
      row(
        l.coachReportPdfLabelLoggedDays,
        l.coachReportPdfValueDays('$loggedDays'),
      ),
      row(
        l.coachReportPdfLabelCalories,
        loggedDays == 0
            ? l.coachReportPdfNoData
            : l.coachReportPdfValueKcal('${report.diet.avgCalories.round()}'),
        now: bothLogged ? report.diet.avgCalories.round() : null,
        then: bothLogged ? last!.diet.avgCalories.round() : null,
        unit: l.coachReportPdfValueKcal,
      ),
      row(
        l.coachReportPdfLabelSodium,
        loggedDays == 0
            ? l.coachReportPdfNoData
            : l.coachReportPdfValueMg('${report.diet.avgSodiumMg.round()}'),
        now: bothLogged ? report.diet.avgSodiumMg.round() : null,
        then: bothLogged ? last!.diet.avgSodiumMg.round() : null,
        unit: l.coachReportPdfValueMg,
      ),
      // 트레이너 화면이 세는 `나트륨 초과 일수` 와 같은 자리. 표에서 빠지면
      // 아래 게이지의 빨강이 무엇을 뜻하는지 숫자로 답할 데가 없다.
      if (report.sodiumOverDays case final int over when loggedDays > 0)
        row(
          l.coachReportPdfLabelSodiumOver,
          l.coachReportPdfValueDays('$over'),
        ),
      row(
        l.coachReportPdfLabelSugar,
        loggedDays == 0
            ? l.coachReportPdfNoData
            : l.coachReportPdfValueGram(
                report.diet.avgSugarG.toStringAsFixed(1),
              ),
      ),
      row(l.homeMacroCarbs, _gram(l, report.avgCarbsG)),
      row(l.homeMacroProtein, _gram(l, report.avgProteinG)),
      row(l.homeMacroFat, _gram(l, report.avgFatG)),
    ];
  }

  /// 회원 목표가 있는 지표만 게이지로 그린다. 기준이 없는 값에 눈금을 그리면
  /// 그 눈금이 어디서 온 것인지 말할 수 없다.
  List<_Block> _gauges(AppLocalizations l, MemberWeeklyReport report) {
    final List<_Block> out = <_Block>[];
    void add(String label, double value, int? target, _Unit unit) {
      if (target == null || target <= 0) return;
      out.add(
        _GaugeBlock(
          text: l.coachReportPdfBullet(
            label,
            l.coachReportPdfGoalOf(unit(_trim(value)), unit('$target')),
          ),
          label: label,
          value: value,
          target: target.toDouble(),
          valueLabel: unit(_trim(value)),
          targetLabel: l.coachReportPdfChartTarget(unit('$target')),
        ),
      );
    }

    add(
      l.coachReportPdfLabelCalories,
      report.diet.avgCalories,
      report.calorieTarget,
      l.coachReportPdfValueKcal,
    );
    add(
      l.coachReportPdfLabelSodium,
      report.diet.avgSodiumMg,
      report.sodiumTarget,
      l.coachReportPdfValueMg,
    );
    add(
      l.coachReportPdfLabelSugar,
      report.diet.avgSugarG,
      report.sugarTarget,
      l.coachReportPdfValueGram,
    );
    return out;
  }

  List<String> _dailyRow(
    AppLocalizations l,
    MemberWeeklyReport report,
    List<String> weekdays,
    int i,
  ) {
    if (report.isUpcoming(i)) {
      return <String>[weekdays[i], l.coachReportPdfUpcoming, ''];
    }
    final List<String> done = report.exercisesOn(i, weekdays);
    final int intake = i < report.caloriesByDay.length
        ? report.caloriesByDay[i]
        : 0;
    return <String>[
      weekdays[i],
      done.isEmpty ? l.coachReportPdfNoData : done.join(', '),
      intake == 0
          ? l.coachReportPdfNoData
          : l.coachReportPdfValueKcal('$intake'),
    ];
  }

  /// 머리띠의 PT 칸. 잡힌 일정을 못 받는 경로(데모)에서는 그 주에 PT 로 기록된
  /// 운동을 세어 적는다 — 자세한 사정은 `sessionsDone` 쪽에 적어 두었다(#1613).
  static String _sessions(AppLocalizations l, MemberWeeklyReport report) {
    if (report.sessionsBooked > 0) {
      return l.coachReportPdfAttendance(
        '${report.sessionsDone}',
        '${report.sessionsBooked}',
      );
    }
    return report.sessionsDone > 0
        ? l.coachReportPdfValueSessions('${report.sessionsDone}')
        : l.coachReportPdfNoSessions;
  }

  /// 요일별 막대 하나. 글로 적던 계열([_series])을 그대로 그림으로 옮긴다 —
  /// 문서가 말하는 값은 같아야 하므로 [_ChartBlock.text] 도 같은 줄을 든다.
  static _ChartBlock _chart(
    AppLocalizations l,
    MemberWeeklyReport report,
    List<String> weekdays, {
    required String title,
    required List<double> values,
    required _Unit unit,
    double? target,
  }) => _ChartBlock(
    title: title,
    text: l.coachReportPdfBullet(title, _series(l, values, unit)),
    values: values,
    labels: weekdays,
    upcoming: <bool>[
      for (int i = 0; i < weekdays.length; i++) report.isUpcoming(i),
    ],
    format: (double value) => unit(_trim(value)),
    target: target,
    targetLabel: target == null
        ? null
        : l.coachReportPdfChartTarget(unit(_trim(target))),
  );

  /// 요일별 계열의 합. 유형별 시간처럼 계열만 있는 값을 한 줄로 적을 때 쓴다.
  static String _sum(AppLocalizations l, List<double> values, _Unit unit) {
    if (values.isEmpty) return l.coachReportPdfNoData;
    final double total = values.fold<double>(0, (double a, double b) => a + b);
    return total == 0 ? l.coachReportPdfNoData : unit(_trim(total));
  }

  static String _gram(AppLocalizations l, double? value) => value == null
      ? l.coachReportPdfNoData
      : l.coachReportPdfValueGram(value.toStringAsFixed(1));

  /// 문서에 남는 날짜는 두 로케일 모두 `YYYY-MM-DD` 다. 회원이 저장해 두고 나중에
  /// 다시 여는 파일이라 연도가 필요하고, `08/05` 처럼 월·일 순서를 두고 헷갈릴
  /// 여지가 없어야 한다.
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _value(AppLocalizations l, num? value, _Unit unit) =>
      value == null || value == 0 ? l.coachReportPdfNoData : unit('$value');

  /// 일곱 칸이 아니거나 전부 0 이면 추이가 아니다 — 줄을 지어내지 않는다.
  static String _series(AppLocalizations l, List<num> values, _Unit unit) {
    if (values.length != 7 || values.every((num value) => value == 0)) {
      return l.coachReportPdfNoData;
    }
    return values
        .map(
          (num value) => value == 0
              ? '-'
              : unit(value is double ? _trim(value) : '$value'),
        )
        .join(' / ');
  }

  /// `30.0분` 대신 `30분`. 소수점이 실제로 있는 값만 한 자리로 적는다.
  static String _trim(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}

/// 문서의 한 덩이. 화면 측정값과 무관하게 문서 레이아웃을 새로 그린다.
///
/// 글줄과 그래프가 같은 것으로 취급돼야 페이지 넘김이 한 곳에서 끝난다 — 높이를
/// 스스로 재고 스스로 그린다.
sealed class _Block {
  const _Block(this.after);

  /// 이 덩이 아래에 두는 여백.
  final double after;

  /// 문서에서 이 덩이가 하는 말. 테스트와 텍스트 추출이 읽는 값이라, 표와
  /// 그래프도 자기 값을 글로 옮겨 놓는다 — 그림만 남으면 무엇을 그렸는지 확인할
  /// 길이 없다.
  String get text;

  /// 여러 줄을 담는 덩이(표)는 이쪽을 채운다. 기본은 [text] 한 줄이다.
  List<String> get textLines => <String>[text];

  double height(double width);

  void paint(Canvas canvas, Offset offset, double width);
}

/// 글줄 하나.
class _TextBlock extends _Block {
  const _TextBlock(this.text, this.style, super.after);

  factory _TextBlock.section(String text) => _TextBlock(
    text,
    const TextStyle(
      color: Color(0xff10384a),
      fontSize: 25,
      fontWeight: FontWeight.w800,
      height: 1.35,
    ),
    16,
  );

  factory _TextBlock.body(String text, {double after = 9}) => _TextBlock(
    text,
    const TextStyle(color: Color(0xff26333a), fontSize: 20, height: 1.5),
    after,
  );

  @override
  final String text;
  final TextStyle style;

  TextPainter _painter(double width) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: width);

  @override
  double height(double width) => _painter(width).height;

  @override
  void paint(Canvas canvas, Offset offset, double width) =>
      _painter(width).paint(canvas, offset);
}

/// 머리띠 — 기간과 그 주를 요약하는 숫자 몇 개를 한 줄에 둔다. (#1619)
///
/// 인바디 결과지의 맨 윗줄과 같은 자리다. 문서를 펴자마자 "언제, 얼마나" 가
/// 끝나야 아래의 표와 그래프를 무엇에 견줄지가 정해진다.
class _BandBlock extends _Block {
  const _BandBlock({
    required this.text,
    required this.cells,
    required this.textLines,
  }) : super(20);

  static const double _height = 92;

  @override
  final String text;

  @override
  final List<String> textLines;

  /// (제목, 값, 너비 비율) 칸들. 기간처럼 긴 값은 넓은 칸을 준다.
  final List<(String, String, double)> cells;

  @override
  double height(double width) => _height;

  @override
  void paint(Canvas canvas, Offset offset, double width) {
    final Rect box = Rect.fromLTWH(offset.dx, offset.dy, width, _height);
    canvas.drawRect(box, Paint()..color = const Color(0xfff2f7fa));
    canvas.drawRect(
      box,
      Paint()
        ..color = const Color(0xffcfdde6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final double total = cells.fold<double>(
      0,
      (double a, (String, String, double) c) => a + c.$3,
    );
    double left = offset.dx;
    for (int i = 0; i < cells.length; i++) {
      final double slot = width * cells[i].$3 / total;
      if (i > 0) {
        canvas.drawLine(
          Offset(left, offset.dy + 14),
          Offset(left, offset.dy + _height - 14),
          Paint()
            ..color = const Color(0xffcfdde6)
            ..strokeWidth = 2,
        );
      }
      final (String title, String value, _) = cells[i];
      _paintCentred(canvas, title, _bandTitle, left, slot, offset.dy + 18);
      _paintCentred(canvas, value, _bandValue, left, slot, offset.dy + 46);
      left += slot;
    }
  }

  static void _paintCentred(
    Canvas canvas,
    String value,
    TextStyle style,
    double left,
    double slot,
    double top,
  ) {
    // 칸을 넘치면 글자를 줄인다. 넘친 채로 그리면 다음 줄로 흘러 띠 밖으로
    // 삐져나간다 — 기간(`2026-08-24 ~ 2026-08-30`)이 실제로 그랬다.
    final double room = slot - 16;
    TextPainter painter = _fit(value, style, room);
    for (final double size in <double>[20, 17, 15]) {
      if (painter.width <= room && painter.didExceedMaxLines == false) break;
      painter = _fit(value, style.copyWith(fontSize: size), room);
    }
    painter.paint(canvas, Offset(left + (slot - painter.width) / 2, top));
  }

  static TextPainter _fit(String value, TextStyle style, double room) =>
      TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: room);

  static const TextStyle _bandTitle = TextStyle(
    color: Color(0xff5b6b76),
    fontSize: 17,
  );
  static const TextStyle _bandValue = TextStyle(
    color: Color(0xff10384a),
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );
}

/// 표 하나. 머리 행과 본문 행을 같은 열 너비로 그린다. (#1619)
///
/// 같은 지표의 이번 주·지난주·변화가 한 줄에 서야 견줄 수 있다. 글줄로 늘어놓던
/// 것을 여기로 옮긴다.
class _TableBlock extends _Block {
  const _TableBlock({
    required this.text,
    required this.header,
    required this.rows,
    required this.weights,
    required this.textLines,
    this.alignRightFrom = 1,
  }) : super(20);

  static const double _rowHeight = 40;
  static const double _pad = 12;

  @override
  final String text;

  @override
  final List<String> textLines;

  final List<String> header;
  final List<List<String>> rows;

  /// 열 너비 비율. 합이 1 이 아니어도 비율로 나눈다.
  final List<double> weights;

  /// 이 열부터는 오른쪽으로 붙인다 — 숫자는 자릿수를 맞춰야 견줘진다.
  final int alignRightFrom;

  @override
  double height(double width) => _rowHeight * (rows.length + 1);

  @override
  void paint(Canvas canvas, Offset offset, double width) {
    final double total = weights.fold<double>(0, (double a, double b) => a + b);
    final List<double> widths = <double>[
      for (final double w in weights) width * w / total,
    ];

    canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy, width, _rowHeight),
      Paint()..color = const Color(0xffe4eef4),
    );
    for (int r = 0; r < rows.length; r++) {
      if (r.isOdd) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + _rowHeight * (r + 1),
          width,
          _rowHeight,
        ),
        Paint()..color = const Color(0xfff7fafc),
      );
    }

    final Paint line = Paint()
      ..color = const Color(0xffcfdde6)
      ..strokeWidth = 1.5;
    for (int r = 0; r <= rows.length + 1; r++) {
      final double y = offset.dy + _rowHeight * r;
      canvas.drawLine(Offset(offset.dx, y), Offset(offset.dx + width, y), line);
    }

    void paintRow(List<String> cells, double top, TextStyle style) {
      double x = offset.dx;
      for (int c = 0; c < cells.length && c < widths.length; c++) {
        final TextPainter painter = TextPainter(
          text: TextSpan(text: cells[c], style: style),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: widths[c] - _pad * 2);
        final double left = c >= alignRightFrom
            ? x + widths[c] - _pad - painter.width
            : x + _pad;
        painter.paint(
          canvas,
          Offset(left, top + (_rowHeight - painter.height) / 2),
        );
        x += widths[c];
      }
    }

    paintRow(header, offset.dy, _headerStyle);
    for (int r = 0; r < rows.length; r++) {
      paintRow(rows[r], offset.dy + _rowHeight * (r + 1), _cellStyle);
    }
  }

  static const TextStyle _headerStyle = TextStyle(
    color: Color(0xff10384a),
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle _cellStyle = TextStyle(
    color: Color(0xff26333a),
    fontSize: 18,
  );
}

/// 목표를 눈금으로 둔 가로 게이지. (#1619)
///
/// 인바디의 `표준이하 / 표준 / 표준이상` 자리다. 평균값 하나를 숫자로만 적으면
/// 그것이 회원 목표에 견줘 어디쯤인지 읽는 사람이 계산해야 한다.
class _GaugeBlock extends _Block {
  const _GaugeBlock({
    required this.text,
    required this.label,
    required this.value,
    required this.target,
    required this.valueLabel,
    required this.targetLabel,
  }) : super(16);

  static const double _height = 62;
  static const double _barHeight = 22;
  static const double _labelWidth = 250;

  @override
  final String text;

  final String label;
  final double value;
  final double target;
  final String valueLabel;
  final String targetLabel;

  @override
  double height(double width) => _height;

  @override
  void paint(Canvas canvas, Offset offset, double width) {
    _paint(canvas, label, _labelStyle, Offset(offset.dx, offset.dy + 6));

    final double left = offset.dx + _labelWidth;
    final double barWidth = width - _labelWidth;
    final double top = offset.dy + 4;
    // 눈금은 목표의 1.5 배까지 — 목표가 가운데 조금 왼쪽에 서서, 넘긴 정도가
    // 눈에 들어온다.
    final double span = target * 1.5;
    final double fill = (value / span).clamp(0.0, 1.0) * barWidth;
    final double mark = (target / span).clamp(0.0, 1.0) * barWidth;
    final bool over = value > target;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, _barHeight),
        const Radius.circular(11),
      ),
      Paint()..color = const Color(0xffe9f0f4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, fill, _barHeight),
        const Radius.circular(11),
      ),
      Paint()..color = over ? const Color(0xffb3261e) : const Color(0xff3eafdf),
    );
    // 목표 눈금. 막대 위아래로 조금 넘겨 그어, 채워진 색과 섞이지 않는다.
    canvas.drawLine(
      Offset(left + mark, top - 6),
      Offset(left + mark, top + _barHeight + 6),
      Paint()
        ..color = const Color(0xff10384a)
        ..strokeWidth = 3,
    );
    _paint(
      canvas,
      targetLabel,
      _targetStyle,
      Offset(left + mark + 6, top + _barHeight + 8),
    );
    _paint(
      canvas,
      valueLabel,
      over ? _overStyle : _valueStyle,
      Offset(left, top + _barHeight + 8),
    );
  }

  static void _paint(Canvas canvas, String value, TextStyle style, Offset at) {
    TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )
      ..layout()
      ..paint(canvas, at);
  }

  static const TextStyle _labelStyle = TextStyle(
    color: Color(0xff26333a),
    fontSize: 19,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle _valueStyle = TextStyle(
    color: Color(0xff26333a),
    fontSize: 17,
  );
  static const TextStyle _overStyle = TextStyle(
    color: Color(0xffb3261e),
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle _targetStyle = TextStyle(
    color: Color(0xff5b6b76),
    fontSize: 16,
  );
}

/// 요일별 값 하나를 막대로 그린다. (#1615)
///
/// 일곱 칸을 `30분 / - / 45분 / …` 로 늘어놓으면 어느 날이 높고 낮은지 눈으로
/// 훑어 견줘야 한다. 트레이너 리포트 탭은 같은 값을 막대로 보여 주므로, 같은 주를
/// 두 사람이 다른 밀도로 읽지 않도록 문서도 막대로 그린다.
class _ChartBlock extends _Block {
  const _ChartBlock({
    required this.title,
    required this.text,
    required this.values,
    required this.labels,
    required this.upcoming,
    required this.format,
    this.target,
    this.targetLabel,
  }) : super(22);

  static const double _barsHeight = 190;
  static const double _titleHeight = 30;
  static const double _labelHeight = 30;

  /// 그래프 위에 적는 이름.
  final String title;

  @override
  final String text;

  /// 월→일 일곱 칸.
  final List<double> values;

  /// 요일 표시.
  final List<String> labels;

  /// 아직 오지 않은 요일. 막대를 그리지 않는다 — 0 으로 그리면 지키지 못한 날처럼
  /// 읽힌다(#1613 의 요일별 상세와 같은 규칙).
  final List<bool> upcoming;

  /// 막대 위에 적는 값. 단위를 붙이는 자리는 로케일이 정한다.
  final String Function(double value) format;

  /// 하루 목표. 있으면 가로선으로 얹고, 넘긴 날의 막대를 달리 칠한다.
  final double? target;
  final String? targetLabel;

  @override
  double height(double width) => _titleHeight + _barsHeight + _labelHeight;

  @override
  void paint(Canvas canvas, Offset offset, double width) {
    _text(title, _titleStyle).paint(canvas, offset);

    final double top = offset.dy + _titleHeight;
    final double bottom = top + _barsHeight;
    final Paint axis = Paint()
      ..color = const Color(0xffd3dde3)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(offset.dx, bottom),
      Offset(offset.dx + width, bottom),
      axis,
    );

    // 축은 값이 있는 막대와 목표선을 모두 담을 만큼만 높인다. 0 뿐인 주에도
    // 눈금이 무너지지 않도록 바닥값을 둔다.
    final double peak = <double>[
      ...values,
      if (target case final double t) t,
      1,
    ].reduce((double a, double b) => a > b ? a : b);
    final double scale = _barsHeight * 0.78 / peak;

    // 목표선은 막대보다 **먼저** 긋는다. 나중에 그으면 막대 위에 적은 값 글자를
    // 가로질러, 그 숫자가 선에 붙은 것처럼 읽힌다.
    if (target case final double t) {
      _dashedLine(canvas, offset.dx, offset.dx + width, bottom - t * scale);
    }

    final int count = labels.length;
    final double slot = width / count;
    final double barWidth = slot * 0.46;
    for (int i = 0; i < count; i++) {
      final double centre = offset.dx + slot * i + slot / 2;
      _text(labels[i], _labelStyle).paint(
        canvas,
        Offset(centre - _text(labels[i], _labelStyle).width / 2, bottom + 6),
      );
      if (i < upcoming.length && upcoming[i]) continue;
      final double value = i < values.length ? values[i] : 0;
      if (value <= 0) continue;
      final double barHeight = value * scale;
      final bool over = target != null && value > target!;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centre - barWidth / 2,
            bottom - barHeight,
            barWidth,
            barHeight,
          ),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        Paint()
          ..color = over ? const Color(0xffb3261e) : const Color(0xff3eafdf),
      );
      // 값은 막대 **안에** 적는다. 막대 위에 적으면 목표선 바로 아래에 있는
      // 막대의 숫자가 선 위로 올라가, 목표를 넘긴 값처럼 읽힌다.
      final bool inside = barHeight >= 46;
      final TextPainter valueText = _text(
        format(value),
        inside
            ? _insideValueStyle
            : over
            ? _overValueStyle
            : _valueStyle,
      );
      valueText.paint(
        canvas,
        Offset(
          centre - valueText.width / 2,
          inside ? bottom - barHeight + 8 : bottom - barHeight - 26,
        ),
      );
    }

    // 목표선 글자는 막대 위에 얹는다 — 선 자체는 막대 아래에 이미 깔았다.
    if (target case final double t) {
      final TextPainter targetText = _text(
        targetLabel ?? format(t),
        _targetStyle,
      );
      targetText.paint(
        canvas,
        Offset(offset.dx + width - targetText.width, bottom - t * scale - 26),
      );
    }
  }

  /// 목표선은 점선이다 — 실선으로 그으면 막대와 같은 무게로 읽힌다.
  void _dashedLine(Canvas canvas, double from, double to, double y) {
    final Paint paint = Paint()
      ..color = const Color(0xff7d8f9b)
      ..strokeWidth = 2;
    for (double x = from; x < to; x += 16) {
      canvas.drawLine(Offset(x, y), Offset(x + 9, y), paint);
    }
  }

  static TextPainter _text(String value, TextStyle style) => TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();

  static const TextStyle _titleStyle = TextStyle(
    color: Color(0xff26333a),
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle _labelStyle = TextStyle(
    color: Color(0xff5b6b76),
    fontSize: 18,
  );
  static const TextStyle _insideValueStyle = TextStyle(
    color: Color(0xffffffff),
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle _valueStyle = TextStyle(
    color: Color(0xff26333a),
    fontSize: 17,
  );
  static const TextStyle _overValueStyle = TextStyle(
    color: Color(0xffb3261e),
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle _targetStyle = TextStyle(
    color: Color(0xff5b6b76),
    fontSize: 17,
  );
}

/// 미리보기 문서를 만드는 서비스.
final memberReportPdfGeneratorProvider = Provider<MemberReportPdfGenerator>(
  (_) => const MemberReportPdfGenerator(),
  name: 'memberReportPdfGenerator',
);
