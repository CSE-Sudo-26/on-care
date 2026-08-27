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

    for (final _Block block in blocks) {
      final TextPainter painter = TextPainter(
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
      _Block.body(
        l.coachReportPdfPeriod(_date(report.weekStart), _date(report.weekEnd)),
      ),
      // 트레이너가 리포트와 함께 보낸 글을 맨 앞에 둔다 — 트레이너 화면도
      // 지표보다 먼저 `트레이너 피드백` 을 읽게 되어 있다(#1613).
      _Block.section(l.coachReportPdfSectionTrainerNote),
      _Block.body(
        trainerNote.trim().isEmpty
            ? l.coachReportPdfNoTrainerNote
            : trainerNote.trim(),
      ),
      _Block.section(l.coachReportPdfSectionMetrics),
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
      _Block.section(l.coachReportPdfSectionTypes),
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
      _Block.section(l.coachReportPdfSectionMacros),
      _bullet(l, l.homeMacroCarbs, _gram(l, report.avgCarbsG)),
      _bullet(l, l.homeMacroProtein, _gram(l, report.avgProteinG)),
      _bullet(l, l.homeMacroFat, _gram(l, report.avgFatG)),
      _Block.section(l.coachReportPdfSectionChange),
      ..._changes(l, report),
      _Block.section(l.coachReportPdfSectionTrend),
      _bullet(
        l,
        l.coachReportPdfLabelMinutesShort,
        _series(l, report.minutesByDay, l.coachReportPdfValueMinutes),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelCaloriesShort,
        _series(l, report.caloriesByDay, l.coachReportPdfValueKcal),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelSodiumShort,
        _series(l, report.sodiumByDay, l.coachReportPdfValueMg),
      ),
      _bullet(
        l,
        l.coachReportPdfLabelSugarShort,
        _series(l, report.sugarByDay, l.coachReportPdfValueGram),
      ),
      _Block.section(l.coachReportPdfSectionDaily),
    ];

    for (int i = 0; i < weekdays.length; i++) {
      // 아직 오지 않은 요일은 `기록 없음` 이 아니다 — 그렇게 적으면 지키지 못한
      // 날처럼 읽힌다. 이번 주 리포트는 늘 뒷날이 비어 있어 절반이 그랬다(#1613).
      if (report.isUpcoming(i)) {
        blocks.add(_Block.body(l.coachReportPdfDayUpcoming(weekdays[i])));
        continue;
      }
      final List<String> done = report.exercisesOn(i, weekdays);
      final int intake = i < report.caloriesByDay.length
          ? report.caloriesByDay[i]
          : 0;
      blocks.add(
        _Block.body(
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
      blocks.add(_Block.body(l.coachReportPdfSodiumTargetNote('$target')));
    }
    // 이 문서가 어디서 온 값인지 마지막에 한 줄로 밝힌다 — 트레이너가 보낸
    // 파일과 같은 자리에서 열리므로, 같은 것으로 오해하지 않도록.
    blocks.add(_Block.body(l.coachReportPdfPreviewNote, after: 12));
    return blocks;
  }

  static _Block _bullet(AppLocalizations l, String label, String value) =>
      _Block.body(l.coachReportPdfBullet(label, value));

  /// `지난주 대비` 줄들. 견줄 주가 없으면 그 사실을 한 줄로 적는다 — 항목만
  /// 빠지면 문서가 그 주에 아무 변화도 없었던 것처럼 읽힌다.
  static List<_Block> _changes(AppLocalizations l, MemberWeeklyReport report) {
    final MemberWeeklyReport? last = report.previous;
    if (last == null ||
        (last.exercise.totalMinutes == 0 && last.loggedDays == 0)) {
      return <_Block>[_Block.body(l.coachReportPdfNoPreviousWeek)];
    }
    return <_Block>[
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
      if (report.loggedDays > 0 && last.loggedDays > 0) ...<_Block>[
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

  static _Block _change(
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
    return _Block.body(
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

/// 문서 한 줄. 화면 측정값과 무관하게 문서 레이아웃을 새로 그린다.
class _Block {
  const _Block(this.text, this.style, this.after);

  factory _Block.section(String text) => _Block(
    text,
    const TextStyle(
      color: Color(0xff10384a),
      fontSize: 25,
      fontWeight: FontWeight.w800,
      height: 1.35,
    ),
    16,
  );

  factory _Block.body(String text, {double after = 9}) => _Block(
    text,
    const TextStyle(color: Color(0xff26333a), fontSize: 20, height: 1.5),
    after,
  );

  final String text;
  final TextStyle style;
  final double after;
}

/// 미리보기 문서를 만드는 서비스.
final memberReportPdfGeneratorProvider = Provider<MemberReportPdfGenerator>(
  (_) => const MemberReportPdfGenerator(),
  name: 'memberReportPdfGenerator',
);
