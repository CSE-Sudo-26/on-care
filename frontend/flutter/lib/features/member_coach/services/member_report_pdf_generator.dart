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
  ).map((_Block block) => block.text).toList(growable: false);

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
    final List<_Block> blocks = <_Block>[
      _TextBlock.body(
        l.coachReportPdfPeriod(_date(report.weekStart), _date(report.weekEnd)),
      ),
      // 트레이너가 리포트와 함께 보낸 글을 맨 앞에 둔다 — 트레이너 화면도
      // 지표보다 먼저 `트레이너 피드백` 을 읽게 되어 있다(#1613).
      _TextBlock.section(l.coachReportPdfSectionTrainerNote),
      _TextBlock.body(
        trainerNote.trim().isEmpty
            ? l.coachReportPdfNoTrainerNote
            : trainerNote.trim(),
      ),
      _TextBlock.section(l.coachReportPdfSectionMetrics),
      _bullet(
        l,
        l.coachReportPdfLabelWorkoutDays,
        l.coachReportPdfValueDays('${report.workoutDays}'),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelWorkoutMinutes,
        _value(l, report.exercise.totalMinutes, l.coachReportPdfValueMinutes),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelBurned,
        _value(l, report.exercise.totalCalories, l.coachReportPdfValueKcal),
      ),
      // PT 는 트레이너가 잡는 일정이라 회원 앱이 목록을 못 받는 경로가 있다.
      // 그때 `기록 없음` 이라고만 적으면, 그 주에 PT 로 기록된 운동이 있는데도
      // 아무 일도 없었던 주로 읽힌다(#1613).
      if (report.sessionsBooked > 0)
        _bullet(
          l,
          l.coachReportPdfLabelSessions,
          l.coachReportPdfAttendance(
            '${report.sessionsDone}',
            '${report.sessionsBooked}',
          ),
        )
      else
        _bullet(
          l,
          report.sessionsDone > 0
              ? l.coachReportPdfLabelPtDone
              : l.coachReportPdfLabelSessions,
          report.sessionsDone > 0
              ? l.coachReportPdfValueSessions('${report.sessionsDone}')
              : l.coachReportPdfNoSessions,
        ),
      _bullet(
        l,
        l.coachReportPdfLabelLoggedDays,
        l.coachReportPdfValueDays('$loggedDays'),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelCalories,
        loggedDays == 0
            ? l.coachReportPdfNoData
            : l.coachReportPdfValueKcal('${report.diet.avgCalories.round()}'),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelSodium,
        loggedDays == 0
            ? l.coachReportPdfNoData
            : l.coachReportPdfValueMg('${report.diet.avgSodiumMg.round()}'),
      ),
      // 트레이너 화면은 서버가 세어 준 `나트륨 초과 일수` 를 읽는다. 회원 앱에는
      // 그 값이 없어 회원 자신의 하루 목표로 다시 센다 — 아래 각주가 어느 기준을
      // 썼는지 밝힌다.
      if (report.sodiumOverDays case final int over when loggedDays > 0)
        _bullet(
          l,
          l.coachReportPdfLabelSodiumOver,
          l.coachReportPdfValueDays('$over'),
        ),
      _bullet(
        l,
        l.coachReportPdfLabelSugar,
        loggedDays == 0
            ? l.coachReportPdfNoData
            : l.coachReportPdfValueGram(
                report.diet.avgSugarG.toStringAsFixed(1),
              ),
      ),
      _TextBlock.section(l.coachReportPdfSectionTypes),
      _bullet(
        l,
        l.coachReportPdfLabelCardio,
        _sum(l, report.exercise.cardioMinutes, l.coachReportPdfValueMinutes),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelStrength,
        _sum(l, report.exercise.strengthMinutes, l.coachReportPdfValueMinutes),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelStretching,
        _sum(
          l,
          report.exercise.stretchingMinutes,
          l.coachReportPdfValueMinutes,
        ),
      ),
      _TextBlock.section(l.coachReportPdfSectionMacros),
      _bullet(l, l.homeMacroCarbs, _gram(l, report.avgCarbsG)),
      _bullet(l, l.homeMacroProtein, _gram(l, report.avgProteinG)),
      _bullet(l, l.homeMacroFat, _gram(l, report.avgFatG)),
      _TextBlock.section(l.coachReportPdfSectionChange),
      ..._changes(l, report),
      _TextBlock.section(l.coachReportPdfSectionTrend),
      // 운동 시간·섭취 칼로리·나트륨은 막대로 그린다(#1615). 나머지 한 줄짜리
      // 계열(당류)은 글로 남긴다 — 그래프를 넷까지 늘리면 한 장이 그래프로만
      // 채워져, 무엇을 먼저 볼지가 사라진다.
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
        // 위에서 센 `나트륨 목표 초과 N일` 이 어느 날이었는지 이 선이 답한다.
        target: report.sodiumTarget?.toDouble(),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelSugarShort,
        _series(l, report.sugarByDay, l.coachReportPdfValueGram),
      ),
      _TextBlock.section(l.coachReportPdfSectionDaily),
    ];

    for (int i = 0; i < weekdays.length; i++) {
      // 아직 오지 않은 요일은 `기록 없음` 이 아니다 — 그렇게 적으면 지키지 못한
      // 날처럼 읽힌다. 이번 주 리포트는 늘 뒷날이 비어 있어 절반이 그랬다(#1613).
      if (report.isUpcoming(i)) {
        blocks.add(_TextBlock.body(l.coachReportPdfDayUpcoming(weekdays[i])));
        continue;
      }
      final List<String> done = report.exercisesOn(i, weekdays);
      final int intake = i < report.caloriesByDay.length
          ? report.caloriesByDay[i]
          : 0;
      blocks.add(
        _TextBlock.body(
          l.coachReportPdfDay(
            weekdays[i],
            done.isEmpty ? l.coachReportPdfNoData : done.join(', '),
            intake == 0
                ? l.coachReportPdfNoData
                : l.coachReportPdfValueKcal('$intake'),
          ),
        ),
      );
    }
    // 나트륨 초과를 셌다면 어느 기준으로 셌는지 밝힌다 — 기준을 적지 않으면
    // 트레이너가 보는 초과 일수와 숫자가 달라도 왜 다른지 알 수 없다.
    if (report.sodiumTarget case final int target when loggedDays > 0) {
      blocks.add(_TextBlock.body(l.coachReportPdfSodiumTargetNote('$target')));
    }
    // 이 문서가 어디서 온 값인지 마지막에 한 줄로 밝힌다 — 트레이너가 보낸
    // 파일과 같은 자리에서 열리므로, 같은 것으로 오해하지 않도록.
    blocks.add(_TextBlock.body(l.coachReportPdfPreviewNote, after: 12));
    return blocks;
  }

  static _TextBlock _bullet(AppLocalizations l, String label, String value) =>
      _TextBlock.body(l.coachReportPdfBullet(label, value));

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

  /// `지난주 대비` 줄들. 견줄 주가 없으면 그 사실을 한 줄로 적는다 — 항목만
  /// 빠지면 문서가 그 주에 아무 변화도 없었던 것처럼 읽힌다.
  static List<_TextBlock> _changes(
    AppLocalizations l,
    MemberWeeklyReport report,
  ) {
    final MemberWeeklyReport? last = report.previous;
    if (last == null ||
        (last.exercise.totalMinutes == 0 && last.loggedDays == 0)) {
      return <_TextBlock>[_TextBlock.body(l.coachReportPdfNoPreviousWeek)];
    }
    return <_TextBlock>[
      _change(
        l,
        l.coachReportPdfLabelWorkoutMinutes,
        report.exercise.totalMinutes,
        last.exercise.totalMinutes,
        l.coachReportPdfValueMinutes,
      ),
      _change(
        l,
        l.coachReportPdfLabelBurned,
        report.exercise.totalCalories,
        last.exercise.totalCalories,
        l.coachReportPdfValueKcal,
      ),
      if (report.loggedDays > 0 && last.loggedDays > 0) ...<_TextBlock>[
        _change(
          l,
          l.coachReportPdfLabelCalories,
          report.diet.avgCalories.round(),
          last.diet.avgCalories.round(),
          l.coachReportPdfValueKcal,
        ),
        _change(
          l,
          l.coachReportPdfLabelSodium,
          report.diet.avgSodiumMg.round(),
          last.diet.avgSodiumMg.round(),
          l.coachReportPdfValueMg,
        ),
      ],
    ];
  }

  static _TextBlock _change(
    AppLocalizations l,
    String label,
    int current,
    int previous,
    _Unit unit,
  ) {
    final int delta = current - previous;
    final String deltaText = delta == 0
        ? l.coachReportPdfDeltaSame
        : delta > 0
        ? l.coachReportPdfDeltaUp(unit('$delta'))
        : l.coachReportPdfDeltaDown(unit('${-delta}'));
    return _TextBlock.body(
      l.coachReportPdfChange(
        label,
        unit('$current'),
        unit('$previous'),
        deltaText,
      ),
    );
  }

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

  /// 문서에서 이 덩이가 하는 말. 테스트와 텍스트 추출이 읽는 값이라, 그래프도
  /// 자기 값을 글로 옮겨 놓는다 — 그림만 남으면 무엇을 그렸는지 확인할 길이 없다.
  String get text;

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
