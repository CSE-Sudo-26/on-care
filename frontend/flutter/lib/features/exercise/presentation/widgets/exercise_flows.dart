import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/core/utils/portrait_date_picker.dart';
import 'package:oncare/design_system/atoms/app_number_stepper.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_estimate.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_load.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/app_toast.dart';

// Backend value sent as `dayLabel` — DO NOT localize (persisted to the server).
/// The "운동 종류" chip display labels — 유산소 / 근력 / 스트레칭 / 기타 네 가지다
/// (#996). 걷기는 유산소로, 요가·스트레칭은 스트레칭으로 접혀 있다: 유형은 집계
/// 축이지 운동 이름이 아니라, 서버·트레이너 앱도 이 네 가지만 쓴다.
/// Only the display strings are localized — the index→type mapping is fixed.
List<String> _exerciseTypeLabels(AppLocalizations l) => <String>[
  l.exTypeCardio, // cardio
  l.exTypeStrength, // strength
  l.exTypeFlexibility, // flexibility (= ExerciseType.stretching)
  l.exTypeOtherChip, // other
];

/// Intensity chip display labels (가벼움 / 보통 / 높음), index-1:1 with
/// [_intensityFactor]. Only the display strings are localized.
List<String> _levelLabels(AppLocalizations l) => <String>[
  l.exLevelLight,
  l.exLevelModerate,
  l.exLevelHigh,
];

/// Chip index → backend [ExerciseType] (1:1 with [_exerciseTypeLabels]).
ExerciseType _typeFromIndex(int i) => switch (i) {
  0 => ExerciseType.cardio,
  1 => ExerciseType.strength,
  2 => ExerciseType.stretching, // 스트레칭 버킷
  _ => ExerciseType.other,
};

/// [ExerciseType] → chip index. 옛 값(걷기·요가)으로 저장된 기록도 자기 버킷
/// 칩을 켠 채 열린다 — 유형이 넷으로 접힌 뒤에도 예전 기록은 남아 있다.
int _indexFromType(ExerciseType t) => switch (t) {
  ExerciseType.cardio || ExerciseType.walking => 0,
  ExerciseType.strength => 1,
  ExerciseType.stretching || ExerciseType.yoga => 2,
  ExerciseType.other => 3,
};

/// 칩 index → 강도. `_levelLabels` 와 1:1 이다.
ExerciseIntensity _intensityFromIndex(int level) => switch (level) {
  0 => ExerciseIntensity.light,
  2 => ExerciseIntensity.high,
  _ => ExerciseIntensity.moderate,
};

/// 어림 칼로리. 표는 [estimateExerciseCalories] 한 곳에 있다 — 추천 개인운동
/// 체크(#1131)도 같은 값을 써야 같은 운동이 화면마다 다른 칼로리로 적히지 않는다.
int _estimateCalories(ExerciseType type, int minutes, int level) =>
    estimateExerciseCalories(
      type,
      minutes,
      intensity: _intensityFromIndex(level),
    );

Widget _shell(BuildContext context, Widget child) => ConstrainedBox(
  constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * 0.9,
    // Match the main content width so the sheet scales with the viewport
    // like the tab pages. The theme lifts the modal route cap to this
    // width too (see AppTheme._bottomSheetTheme); this centres the child.
    maxWidth: AppBreakpoints.contentMaxWidth,
  ),
  child: Container(
    key: const Key('exerciseAddSheet'),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(top: false, child: child),
  ),
);

Widget _handle() => Container(
  margin: const EdgeInsets.only(top: 12, bottom: 4),
  width: 36,
  height: 4,
  decoration: BoxDecoration(
    color: const Color(0xFFDDE3EA),
    borderRadius: BorderRadius.circular(999),
  ),
);

// ─────────────────────────────────────────────────────── 운동 추가 ──

/// A compact "운동 추가" sheet: pick a type + duration/intensity, then save.
/// Pass [session] to open in edit mode (pre-filled → PUT); omit it to add.
Future<void> showExerciseAddSheet(
  BuildContext context, {
  ExerciseSession? session,
  DateTime? initialDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // 하단 바·+ 버튼이 시트 위로 올라오지 않도록 루트에 올린다(#791).
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) =>
        _ExerciseAddSheet(session: session, initialDate: initialDate),
  );
}

/// 기록 하나를 지운다 — 확인창을 거친 뒤에만 지운다. (#1428)
///
/// 목록에서 바로 지울 수 있어야 추가한 기록을 되돌릴 자리가 생긴다. 서버가 준
/// id 가 없는 기록(데모 시드의 옛 행)은 지울 수 없다 — 조용히 실패하는 대신
/// 그렇다고 말한다.
Future<bool> confirmDeleteExerciseSession(
  BuildContext context,
  WidgetRef ref,
  ExerciseSession session,
) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final AppToastHost toast = AppToastHost.of(context);
  final String? id = session.id;
  if (id == null) {
    toast.show(l.exCannotDelete, kind: AppToastKind.error);
    return false;
  }
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(l.exDeleteExercise),
      content: Text(l.exDeleteExerciseBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l.actionCancel),
        ),
        // 되돌릴 수 없는 쪽은 파괴적 색으로 말한다.
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
          child: Text(l.actionDelete),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await ref.read(exerciseRepositoryProvider).deleteSession(id);
    // 목록·주간 통계·그래프가 한 번에 최신이 된다 — 추가 경로와 같은 무효화다.
    ref.invalidate(exerciseWeekProvider);
    toast.show(l.exDeleted, kind: AppToastKind.success);
    return true;
  } on Object {
    toast.show(l.exDeleteFailed, kind: AppToastKind.error);
    return false;
  }
}

class _ExerciseAddSheet extends ConsumerStatefulWidget {
  const _ExerciseAddSheet({this.session, this.initialDate});

  final ExerciseSession? session;

  /// 새 기록의 기본 날짜. 운동 탭 안에서 열면 그 탭에서 보고 있는 날이다 —
  /// 어제를 보다가 추가했는데 오늘로 저장되면 방금 적은 기록이 목록에서
  /// 사라진다(#1428). 하단 `+` 로 열면 null 이라 오늘이 기본값이다.
  final DateTime? initialDate;

  bool get isEdit => session != null;

  @override
  ConsumerState<_ExerciseAddSheet> createState() => _ExerciseAddSheetState();
}

class _ExerciseAddSheetState extends ConsumerState<_ExerciseAddSheet> {
  late int _type = widget.session != null
      ? _indexFromType(widget.session!.type)
      : 0; // 기본값은 유산소 — 칩 목록의 첫 칸이다.
  // Intensity is persisted on ExerciseSession, so an edit reopens at the
  // saved level (가벼움/보통/높음); a new session defaults to 보통.
  late int _level = widget.session?.intensity.index ?? 1;
  late double _minutes = widget.session?.minutes.toDouble() ?? 30;
  // 근력은 시간이 아니라 **세트·횟수·중량**으로 재는 운동이다
  // (#1262, #1276, #1310). 분과 따로 들고 있어야 유형을 근력↔유산소로 오갈 때
  // 각자의 값이 남는다 — 하나로 쓰면 30분이 30세트가 되어 돌아온다.
  late double _sets = _initialSets(widget.session);
  late double _reps = (widget.session?.reps ?? 10).toDouble();
  late double _weight = widget.session?.weight ?? 20;
  // 기본값은 오늘. 지난 기록을 고치면 그 기록의 날짜로 열린다 — 오늘로
  // 되돌리면 기록을 고치기만 해도 이번 주로 옮겨 간다.
  late DateTime _date = _dateOnly(
    widget.session?.date ?? widget.initialDate ?? nowKst(),
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.session?.name ?? '',
  );
  bool _saving = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 편집 시트가 열릴 세트 수. 기록이 세트를 들고 있으면 그 값, 세트를 모르는
  /// 옛 근력 기록이면 분에서 환산한 값, 새 기록이면 12세트다.
  static double _initialSets(ExerciseSession? session) {
    if (session == null || session.type != ExerciseType.strength) return 12;
    final int? recorded = session.sets;
    if (recorded != null && recorded > 0) return recorded.toDouble();
    return setsFromStrengthMinutes(
      session.minutes.toDouble(),
    ).clamp(1, 40).toDouble();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// 지금 고른 유형이 근력인가 — 세트·횟수·중량으로 묻고 그렇게 저장할지
  /// 가른다.
  bool get _isStrength => _typeFromIndex(_type) == ExerciseType.strength;

  /// 근력 기록의 분. 세트 수에 세트당 벽시계 시간(휴식 포함)을 곱한 값이다 —
  /// 서버는 여전히 분(>0)을 요구하고, 주간 운동 시간도 분으로 센다.
  int get _strengthMinutes =>
      (_sets.round() * kStrengthMinutesPerSetWithRest).round();

  /// 저장·칼로리 계산이 쓰는 분. 근력이면 세트에서 환산한 값이다.
  int get _effectiveMinutes =>
      _isStrength ? _strengthMinutes : _minutes.round();

  Future<void> _pickDate() async {
    final DateTime now = nowKst();
    final DateTime? picked = await showPortraitDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      // 앞으로 한 기록은 없다 — 아직 하지 않은 운동을 적을 자리가 아니다.
      lastDate: _dateOnly(now),
    );
    if (picked != null) setState(() => _date = _dateOnly(picked));
  }

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final AppToastHost toast = AppToastHost.of(context);
    final String name = _name.text.trim();
    if (name.isEmpty) {
      toast.show(l.exEnterName, kind: AppToastKind.error);
      return;
    }
    final int minutes = _effectiveMinutes;
    if (minutes <= 0) {
      toast.show(
        _isStrength ? l.exEnterSets : l.exEnterDuration,
        kind: AppToastKind.error,
      );
      return;
    }
    // 근력이 아니면 세트·횟수·중량을 싣지 않는다 — 유산소를 세트로 세는
    // 화면은 없고, 유형을 바꾼 수정에서는 null 이 옛 값을 지운다.
    final int? sets = _isStrength ? _sets.round() : null;
    final int? reps = _isStrength ? _reps.round() : null;
    final double? weight = _isStrength ? _weight : null;
    final ExerciseType type = _typeFromIndex(_type);
    final ExerciseSession? editing = widget.session;
    if (editing != null && editing.id == null) {
      // No id → PUT impossible; don't silently create a duplicate session.
      toast.show(l.exCannotEdit, kind: AppToastKind.error);
      return;
    }
    // Intensity is persisted now, so always recompute calories from the
    // (restored or edited) level — no more preserving stale values.
    final ExerciseIntensity intensity = ExerciseIntensity.values[_level];
    final int calories = _estimateCalories(type, minutes, _level);

    setState(() => _saving = true);
    try {
      // 서버(mock 모드는 drift)에 저장 → 주간 데이터 무효화로 통계·차트·목록 반영.
      if (editing != null) {
        await ref
            .read(exerciseRepositoryProvider)
            .updateSession(
              id: editing.id!,
              type: type,
              name: name,
              minutes: minutes,
              calories: calories,
              intensity: intensity,
              date: _date,
              sets: sets,
              reps: reps,
              weight: weight,
            );
      } else {
        await ref
            .read(exerciseRepositoryProvider)
            .addSession(
              type: type,
              name: name,
              minutes: minutes,
              calories: calories,
              intensity: intensity,
              date: _date,
              sets: sets,
              reps: reps,
              weight: weight,
            );
      }
      // Sheet dismissed mid-save → don't pop the page below.
      if (!mounted) return;
      ref.invalidate(exerciseWeekProvider);
      navigator.pop();
      toast.show(
        widget.isEdit ? l.exUpdated : l.exLogged,
        kind: AppToastKind.success,
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      toast.show(l.exSaveFailed, kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<String> types = _exerciseTypeLabels(l);
    final List<String> levels = _levelLabels(l);
    // Block back/drag dismiss while the save request is in flight.
    final Widget sheet = _shell(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(child: _handle()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.isEdit ? l.exEditExercise : l.exAddExercise,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: FigmaColors.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    l.exSave,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              key: const Key('exerciseAddContent'),
              shrinkWrap: true,
              // 아래 여백을 준다 — 0 이면 마지막 칼로리 상자가 시트 끝선에
              // 붙어 잘린 것처럼 보였다.
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: <Widget>[
                _Label(l.exExerciseDate),
                const SizedBox(height: 10),
                _DateField(
                  key: const Key('exerciseDateField'),
                  date: _date,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 20),
                _Label(l.exExerciseType),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int i = 0; i < types.length; i++)
                      _chip(
                        types[i],
                        _type == i,
                        () => setState(() => _type = i),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _Label(l.exExerciseName),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('exerciseNameField'),
                  controller: _name,
                  textInputAction: TextInputAction.done,
                  maxLength: 100,
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: l.exExerciseNameHint,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: FigmaColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: FigmaColors.hairline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: FigmaColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 근력은 세트·횟수·중량으로, 나머지는 분으로 묻는다
                // (#1262, #1276, #1310).
                // 화면 여러 곳(홈 운동 카드·운동 현황 링·주간 목표)이 근력을
                // 세트로 읽는데 기록만 분이면, 회원이 적지 않은 수가 화면에 뜬다.
                if (_isStrength) ...<Widget>[
                  _Label(l.exExerciseSets),
                  const SizedBox(height: 10),
                  AppNumberStepper(
                    key: const Key('exerciseSetsStepper'),
                    value: _sets,
                    min: 1,
                    max: 40,
                    suffix: l.exUnitSets,
                    onChanged: (double v) => setState(() => _sets = v),
                  ),
                  const SizedBox(height: 20),
                  _Label(l.exExerciseReps),
                  const SizedBox(height: 10),
                  AppNumberStepper(
                    key: const Key('exerciseRepsStepper'),
                    value: _reps,
                    min: 1,
                    max: 999,
                    suffix: l.exUnitReps,
                    onChanged: (double v) => setState(() => _reps = v),
                  ),
                  const SizedBox(height: 20),
                  _Label(l.exExerciseWeight),
                  const SizedBox(height: 10),
                  AppNumberStepper(
                    key: const Key('exerciseWeightStepper'),
                    value: _weight,
                    min: 0,
                    max: 500,
                    // 원판은 0.5kg 단위로 붙는다 — 버튼 한 번에 1kg 이 실용적인
                    // 걸음이고, 소수 자리는 직접 적어 채운다.
                    decimals: 1,
                    suffix: l.exUnitKg,
                    onChanged: (double v) => setState(() => _weight = v),
                  ),
                ] else ...<Widget>[
                  _Label(l.exExerciseDuration),
                  const SizedBox(height: 10),
                  AppNumberStepper(
                    key: const Key('exerciseMinutesStepper'),
                    value: _minutes,
                    min: 1,
                    max: 600,
                    suffix: l.exUnitMinutes,
                    onChanged: (double v) => setState(() => _minutes = v),
                  ),
                ],
                const SizedBox(height: 20),
                _Label(l.exExerciseIntensity),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    for (int i = 0; i < levels.length; i++) ...<Widget>[
                      Expanded(
                        child: _chip(
                          levels[i],
                          _level == i,
                          () => setState(() => _level = i),
                          center: true,
                        ),
                      ),
                      if (i < levels.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FigmaColors.softBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.local_fire_department,
                        color: FigmaColors.heartOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.exEstimatedCalories,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      Text(
                        l.unitKcalValue(
                          _estimateCalories(
                            _typeFromIndex(_type),
                            _effectiveMinutes,
                            _level,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return PopScope(canPop: !_saving, child: sheet);
  }

  Widget _chip(
    String label,
    bool on,
    VoidCallback onTap, {
    bool center = false,
  }) {
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: center ? Alignment.center : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on ? FigmaColors.primaryA(0.10) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? FigmaColors.primary : FigmaColors.hairline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: on ? FigmaColors.primary : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// 날짜 한 칸 — 눌러서 달력을 연다. 기본값은 오늘이다.
class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap, super.key});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FigmaColors.hairline),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: FigmaColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                // 로케일이 정하는 날짜 문구. 하드코딩한 'yyyy.MM.dd' 로 적으면
                // 영어 화면에도 한국식 표기가 남는다.
                MaterialLocalizations.of(context).formatFullDate(date),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.ink,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: FigmaColors.ink,
    ),
  );
}

// ─────────────────────────────────────────────────────── 헬스장 찾기 ──
