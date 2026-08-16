import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/kakao_map/kakao_map_view.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

// Backend value sent as `dayLabel` — DO NOT localize (persisted to the server).
const List<String> _weekdayLabels = <String>['월', '화', '수', '목', '금', '토', '일'];

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

/// Per-intensity multiplier for [_levelLabels] (가벼움 / 보통 / 높음).
const List<double> _intensityFactor = <double>[0.85, 1.0, 1.2];

/// Rough kcal/min per type scaled by intensity, used to estimate burn when the
/// user logs a duration (matches the prototype's estimate ranges).
int _estimateCalories(ExerciseType type, int minutes, int level) {
  final double perMin = switch (type) {
    ExerciseType.cardio => 9,
    ExerciseType.strength => 6,
    ExerciseType.walking => 4,
    ExerciseType.stretching => 3,
    ExerciseType.yoga => 3,
    ExerciseType.other => 5,
  };
  final double factor = (level >= 0 && level < _intensityFactor.length)
      ? _intensityFactor[level]
      : 1.0;
  return (perMin * minutes * factor).round();
}

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
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int minutes = _minutes.round();
    if (minutes <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(l.exEnterDuration)));
      return;
    }
    final ExerciseType type = _typeFromIndex(_type);
    final ExerciseSession? editing = widget.session;
    if (editing != null && editing.id == null) {
      // No id → PUT impossible; don't silently create a duplicate session.
      messenger.showSnackBar(SnackBar(content: Text(l.exCannotEdit)));
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
              dayLabel: _weekdayLabels[DateTime.now().weekday - 1],
            );
      }
      // Sheet dismissed mid-save → don't pop the page below.
      if (!mounted) return;
      ref.invalidate(exerciseWeekProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(widget.isEdit ? l.exUpdated : l.exLogged)),
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.exSaveFailed)));
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
    return GestureDetector(
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

/// "헬스장 찾기" — a live search field, a map placeholder, and the nearby
/// gym list from [nearbyGymsProvider], filtered by the query.
Future<void> showGymLocatorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => const _GymLocatorSheet(),
  );
}

class _GymLocatorSheet extends ConsumerStatefulWidget {
  const _GymLocatorSheet();

  @override
  ConsumerState<_GymLocatorSheet> createState() => _GymLocatorSheetState();
}

class _GymLocatorSheetState extends ConsumerState<_GymLocatorSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Case-insensitive match on gym name or address; empty query returns all.
  List<Gym> _filter(List<Gym> gyms) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return gyms;
    return gyms
        .where(
          (Gym g) =>
              g.name.toLowerCase().contains(q) ||
              g.address.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 제휴 헬스장 + 카카오 Local 주변 헬스장(#329). 트레이너 흐름이 쓰는
    // nearbyGymsProvider 와 달리, 이 시트만 카카오 결과를 함께 본다.
    final AsyncValue<List<Gym>> async = ref.watch(gymFinderResultsProvider);
    // 지도 핀은 아래 목록과 같은 것을 가리켜야 한다 — 검색어로 거른 뒤의 결과를
    // 쓴다. 아직 로딩 중이면 핀 0개로 그려지고, 결과가 도착하면 다시 찍힌다.
    final List<Gym> pinned = _filter(async.valueOrNull ?? const <Gym>[]);
    return _shell(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(child: _handle()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: <Widget>[
                Material(
                  color: FigmaColors.softBlue,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: FigmaColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l.exFindGym,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: FigmaColors.statBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.search,
                        size: 16,
                        color: FigmaColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (String v) => setState(() => _query = v),
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            fontSize: 14,
                            color: FigmaColors.ink,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: l.exGymSearchHint,
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: AppColors.mutedForeground,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.close,
                              size: 15,
                              color: FigmaColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _LocatorMap(gyms: pinned),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Text(
                      l.exNearbyGyms,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AiPill(
                      l.exAiAnalysis,
                      background: FigmaColors.primaryA(0.10),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...async.when(
                  data: (List<Gym> gyms) {
                    final List<Gym> results = _filter(gyms);
                    if (results.isEmpty) {
                      return <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              l.exNoGymMatch(_query),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ];
                    }
                    return <Widget>[
                      for (int i = 0; i < results.length; i++) ...<Widget>[
                        _GymResult(
                          gym: results[i],
                          top: _query.trim().isEmpty && i == 0,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ];
                  },
                  loading: () => const <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                  ],
                  error: (Object e, StackTrace _) => <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: <Widget>[
                          Text(
                            l.exGymsLoadError,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () =>
                                ref.invalidate(gymFinderResultsProvider),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FigmaColors.primary,
                              side: BorderSide(
                                color: FigmaColors.primaryA(0.4),
                              ),
                            ),
                            child: Text(l.actionRetry),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 주변 헬스장 결과 카드. 누르면 그 헬스장 상세로 간다 — 소속 트레이너를 보고
/// 상담을 신청하는 자리다.
///
/// 예전에는 '건강 요약 전달' 버튼이 있었다. 확인을 받고 성공 스낵바를 띄웠지만
/// 실제로는 아무 데도 보내지 않았다(전달받을 서버 경로도, 트레이너앱 화면도
/// 없다). 회원은 자기 건강 정보가 넘어간 것으로 알고 기다리게 된다 — 미구현보다
/// 나쁘다. 그래서 문구를 고치는 대신, 실제로 동작하는 다음 걸음으로 바꿨다(#787).
/// 상담 신청은 운동 목표·건강 목적·메모를 담아 트레이너에게 실제로 저장된다.
class _GymResult extends ConsumerWidget {
  const _GymResult({required this.gym, this.top = false});

  final Gym gym;
  final bool top;

  /// A short, real-data reason line for the AI-styled highlight box. Uses the
  /// gym's first trainer when it has one.
  String _reason(AppLocalizations l, Trainer? trainer) {
    if (trainer != null) {
      final String role = trainer.role != null ? ' · ${trainer.role}' : '';
      return l.exReasonTrainer(trainer.name, role);
    }
    if (gym.weekdayHours != null) {
      final String weekend = gym.weekendHours != null
          ? ' · ${l.exGymWeekendHours(gym.weekendHours!)}'
          : '';
      return l.exReasonHours(l.exGymWeekdayHours(gym.weekdayHours!), weekend);
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 이 헬스장의 대표 트레이너(첫 번째)로 추천 문구와 채팅 상대를 정한다.
    final Trainer? trainer = ref
        .watch(gymTrainersProvider(gym.id))
        .valueOrNull
        ?.firstOrNull;
    final String reason = _reason(l, trainer);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: Key('gym-result-${gym.id}'),
        borderRadius: BorderRadius.circular(20),
        // 시트를 먼저 닫는다 — 상세를 시트 위에 얹으면 뒤로 가기가 시트로
        // 돌아와 운동 탭까지 두 번 걸린다.
        onTap: () {
          Navigator.of(context).pop();
          context.push(AppRoutes.gymDetailPath(gym.id));
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: top ? FigmaColors.primaryA(0.25) : FigmaColors.hairline,
            ),
            boxShadow: kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (top) ...<Widget>[
                AiPill(
                  l.exAiTopPick,
                  background: FigmaColors.primary,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          gym.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: FigmaColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          gym.address,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      // 카카오 Local 은 평점을 주지 않는다(rating 0) — "0.0★" 대신
                      // 뱃지를 통째로 감춘다.
                      if (gym.rating > 0)
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.star,
                              size: 13,
                              color: Color(0xFFF5B400),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              gym.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: FigmaColors.ink,
                              ),
                            ),
                          ],
                        ),
                      Text(
                        '${gym.distanceKm.toStringAsFixed(1)}km',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (gym.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FigmaColors.softBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final String t in gym.tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: FigmaColors.primaryA(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: FigmaColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (reason.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: FigmaColors.ink,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // 이 카드가 어디로 가는지 한 줄로 말해 둔다 — 누를 수 있다는 표시이자,
              // 눌러서 무엇을 할 수 있는지에 대한 답이다.
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l.exGymDetailHint,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: FigmaColors.primary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: FigmaColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── 지도 ──

/// 로케이터 시트 지도의 높이. 실지도와 폴백 그래픽이 같은 자리를 차지해야
/// 폴백으로 떨어질 때 시트 레이아웃이 흔들리지 않는다.
const double _kLocatorMapHeight = 190;

/// 시트 목록에 보이는 헬스장을 카카오맵 핀으로 찍는다. `KAKAO_JS_KEY` 가
/// 없거나 web 이 아니거나 SDK 로드가 실패하면 [_MapPlaceholder] 그래픽으로
/// 폴백한다(#329) — 데모가 비지 않게 하기 위한 요건이다.
class _LocatorMap extends StatelessWidget {
  const _LocatorMap({required this.gyms});

  final List<Gym> gyms;

  @override
  Widget build(BuildContext context) {
    final List<Gym> located = gyms
        .where((Gym g) => g.hasCoordinates)
        .toList(growable: false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: _kLocatorMapHeight,
        width: double.infinity,
        child: KakaoMapView(
          // 지도 중심은 언제나 검색 중심([kGymFinderArea])이다. 첫 결과 좌표를
          // 쓰면 검색어에 따라 중심이 흔들려, 지도 중심과 장소 검색 중심이
          // 같아야 한다는 요건이 깨진다.
          centerLat: kGymFinderArea.lat,
          centerLng: kGymFinderArea.lng,
          markers: <KakaoMapMarker>[
            for (final Gym g in located)
              KakaoMapMarker(lat: g.lat!, lng: g.lng!, title: g.name),
          ],
          fallback: const _MapPlaceholder(),
        ),
      ),
    );
  }
}

/// A lightweight stylised map (roads, blocks, pins) so the locator reads as a
/// map area when the live Kakao Map is unavailable.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: _kLocatorMapHeight,
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: CustomPaint(painter: _MapPainter())),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l.exKakaoMapArea,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEDEEE9),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.8, w, h * 0.2),
      Paint()..color = const Color(0xFFCFE4EF),
    );
    final Paint green = Paint()..color = const Color(0xFFCFE0C4);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.08, w * 0.17, h * 0.22),
      green,
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.63, h * 0.5, w * 0.2, h * 0.22), green);
    final Paint beige = Paint()..color = const Color(0xFFE3D9C7);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.31, h * 0.1, w * 0.22, h * 0.26),
      beige,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.44, w * 0.2, h * 0.28),
      beige,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.61, h * 0.08, w * 0.33, h * 0.28),
      beige,
    );
    final Paint road = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h * 0.4), Offset(w, h * 0.4), road);
    canvas.drawLine(Offset(0, h * 0.74), Offset(w, h * 0.74), road);
    canvas.drawLine(Offset(w * 0.28, 0), Offset(w * 0.28, h), road);
    canvas.drawLine(Offset(w * 0.58, 0), Offset(w * 0.58, h), road);
    canvas.drawLine(Offset(w * 0.85, 0), Offset(w * 0.85, h), road);
    _pin(canvas, Offset(w * 0.28, h * 0.4), selected: true);
    _pin(canvas, Offset(w * 0.58, h * 0.26), selected: false);
    _pin(canvas, Offset(w * 0.72, h * 0.6), selected: false);
  }

  void _pin(Canvas c, Offset p, {required bool selected}) {
    const double r = 7;
    if (selected) {
      c.drawCircle(
        p,
        r * 2,
        Paint()..color = FigmaColors.primary.withValues(alpha: 0.18),
      );
    }
    final Path path = Path()
      ..moveTo(p.dx, p.dy + r * 1.9)
      ..cubicTo(
        p.dx - r * 1.2,
        p.dy + r * 0.2,
        p.dx - r,
        p.dy - r,
        p.dx,
        p.dy - r,
      )
      ..cubicTo(
        p.dx + r,
        p.dy - r,
        p.dx + r * 1.2,
        p.dy + r * 0.2,
        p.dx,
        p.dy + r * 1.9,
      )
      ..close();
    c.drawPath(path, Paint()..color = FigmaColors.primary);
    c.drawCircle(
      Offset(p.dx, p.dy - r * 0.15),
      r * 0.4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
