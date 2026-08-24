import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_estimate.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/app_toast.dart';

// Backend value sent as `dayLabel` — DO NOT localize (persisted to the server).
/// The "운동 종류" chip display labels, kept index-1:1 with [ExerciseType] so a
/// saved type round-trips losslessly into the edit sheet (mirrors `_typeLabel`).
/// Only the display strings are localized — the index→type mapping is fixed.
List<String> _exerciseTypeLabels(AppLocalizations l) => <String>[
  l.exTypeWalking, // walking
  l.exTypeCardio, // cardio
  l.exTypeStrength, // strength
  l.exTypeYoga, // yoga
  l.exTypeStretching, // stretching
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
  0 => ExerciseType.walking,
  1 => ExerciseType.cardio,
  2 => ExerciseType.strength,
  3 => ExerciseType.yoga,
  4 => ExerciseType.stretching,
  _ => ExerciseType.other,
};

/// [ExerciseType] → chip index (for pre-filling the edit sheet, lossless).
int _indexFromType(ExerciseType t) => switch (t) {
  ExerciseType.walking => 0,
  ExerciseType.cardio => 1,
  ExerciseType.strength => 2,
  ExerciseType.yoga => 3,
  ExerciseType.stretching => 4,
  ExerciseType.other => 5,
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
}) {
  return showModalBottomSheet<void>(
    context: context,
    // 하단 바·+ 버튼이 시트 위로 올라오지 않도록 루트에 올린다(#791).
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => _ExerciseAddSheet(session: session),
  );
}

class _ExerciseAddSheet extends ConsumerStatefulWidget {
  const _ExerciseAddSheet({this.session});

  final ExerciseSession? session;

  bool get isEdit => session != null;

  @override
  ConsumerState<_ExerciseAddSheet> createState() => _ExerciseAddSheetState();
}

class _ExerciseAddSheetState extends ConsumerState<_ExerciseAddSheet> {
  late int _type = widget.session != null
      ? _indexFromType(widget.session!.type)
      : 1;
  // Intensity is persisted on ExerciseSession, so an edit reopens at the
  // saved level (가벼움/보통/높음); a new session defaults to 보통.
  late int _level = widget.session?.intensity.index ?? 1;
  late double _minutes = widget.session?.minutes.toDouble() ?? 30;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final AppToastHost toast = AppToastHost.of(context);
    final int minutes = _minutes.round();
    if (minutes <= 0) {
      toast.show(l.exEnterDuration, kind: AppToastKind.error);
      return;
    }
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
              minutes: minutes,
              calories: calories,
              intensity: intensity,
              dayLabel: editing.dayLabel,
            );
      } else {
        await ref
            .read(exerciseRepositoryProvider)
            .addSession(
              type: type,
              minutes: minutes,
              calories: calories,
              intensity: intensity,
              dayLabel: kWeekdayLabelsKo[nowKst().weekday - 1],
            );
      }
      // Sheet dismissed mid-save → don't pop the page below.
      if (!mounted) return;
      ref.invalidate(exerciseWeekProvider);
      navigator.pop();
      toast.show(widget.isEdit ? l.exUpdated : l.exLogged,
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              children: <Widget>[
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
                Row(
                  children: <Widget>[
                    _Label(l.exExerciseDuration),
                    const Spacer(),
                    Text(
                      l.exDurationMinutes(_minutes.round()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FigmaColors.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _minutes,
                  min: 5,
                  max: 120,
                  divisions: 23,
                  activeColor: FigmaColors.primary,
                  onChanged: (double v) => setState(() => _minutes = v),
                ),
                const SizedBox(height: 12),
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
                            _minutes.round(),
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
