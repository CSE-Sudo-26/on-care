import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_load.dart'
    show setsFromStrengthMinutes;
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/widgets/exercise_flows.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 회원이 **직접 적은** 그날의 운동 기록. (#1428)
///
/// 하단 내비게이션의 `+` 로 저장한 기록은 주간 통계·그래프에만 반영되고,
/// 오늘 화면 어디에도 개별 기록이 남지 않았다 — 방금 적은 것을 되짚거나 고칠
/// 자리가 없었다. 식단 탭이 `식사 추가` 버튼과 끼니 목록을 한 화면에 두는 것과
/// 같은 짜임으로, 이 자리에서 추가하고 그 결과를 바로 본다.
///
/// PT 일지와 트레이너가 배정한 개인운동은 여기 넣지 않는다 — 회원이 적은 것과
/// 트레이너가 만든 것은 고칠 수 있는지부터 다르다.
class OwnExerciseRecords extends ConsumerWidget {
  /// Creates the section for [date] out of [week].
  const OwnExerciseRecords({super.key, required this.week, required this.date});

  /// [date] 가 속한 주의 자료. 기록은 이 안에 이미 들어 있다.
  final ExerciseWeek week;

  /// 지금 보고 있는 날. 추가 폼의 기본 날짜이자 목록을 거르는 기준이다.
  final DateTime date;

  /// [date] 의 회원 기록만. 요일 라벨로 거른다 — 주간 자료가 요일로 묶여 온다.
  List<ExerciseSession> _sessionsOf() {
    final int i = date.weekday - 1;
    final String dayLabel = i < week.dayLabels.length ? week.dayLabels[i] : '';
    if (dayLabel.isEmpty) return const <ExerciseSession>[];
    return week.sessions
        .where(
          (ExerciseSession s) =>
              s.dayLabel == dayLabel && s.source == ExerciseSource.member,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<ExerciseSession> sessions = _sessionsOf();
    return Column(
      key: const ValueKey<String>('exercise-own-records'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            // 좁은 화면·큰 배율에서는 제목이 먼저 줄어든다 — 추가 버튼이
            // 밀려 나가면 이 자리에서 적을 방법이 사라진다(#766 과 같은 종류).
            Flexible(
              child: Text(
                l.exOwnRecords,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 하단 `+` → 운동과 **같은 시트**를 연다. 다른 점은 기본 날짜뿐이다
            // — 지금 보고 있는 날로 열려 어제를 보다 적은 기록이 오늘로 새지
            // 않는다.
            Flexible(
              child: _AddExerciseButton(
                onTap: () => showExerciseAddSheet(context, initialDate: date),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                l.exOwnRecordsEmpty,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          )
        else
          for (final ExerciseSession s in sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OwnRecordCard(session: s),
            ),
      ],
    );
  }
}

class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Material(
      key: const ValueKey<String>('exercise-add-button'),
      color: FigmaColors.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.add, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l.exAddExercise,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 기록 한 줄 — 이름·유형·운동량·강도·칼로리와 수정·삭제.
class _OwnRecordCard extends ConsumerWidget {
  const _OwnRecordCard({required this.session});

  final ExerciseSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String title = session.name.isNotEmpty
        ? session.name
        : exerciseTypeLabel(l, session.type);
    return Container(
      key: session.id == null
          ? null
          : ValueKey<String>('exercise-own-record-${session.id}'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FigmaColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                // 유형·운동량·강도·칼로리를 한 줄로. 저장한 값 그대로다 —
                // 목록에서 다시 계산하면 시트가 보여 준 수와 갈린다.
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _Tag(text: exerciseTypeLabel(l, session.type)),
                    _Tag(text: exerciseAmountLabel(l, session)),
                    _Tag(text: _intensityLabel(l, session.intensity)),
                    Text(
                      '${NumberFormat('#,###').format(session.calories)} '
                      '${l.unitKcal}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: session.id == null
                ? null
                : ValueKey<String>('exercise-own-record-edit-${session.id}'),
            tooltip: l.exEditExercise,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: AppColors.mutedForeground,
            onPressed: () => showExerciseAddSheet(context, session: session),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: session.id == null
                ? null
                : ValueKey<String>('exercise-own-record-delete-${session.id}'),
            tooltip: l.exDeleteExercise,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: AppColors.destructive,
            onPressed: () =>
                confirmDeleteExerciseSession(context, ref, session),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: FigmaColors.statBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.foreground,
        ),
      ),
    );
  }
}

String _intensityLabel(AppLocalizations l, ExerciseIntensity intensity) =>
    switch (intensity) {
      ExerciseIntensity.light => l.exLevelLight,
      ExerciseIntensity.moderate => l.exLevelModerate,
      ExerciseIntensity.high => l.exLevelHigh,
    };

/// 기록 한 줄이 말하는 **양**. 근력은 세트·횟수(·중량)로, 나머지는 분으로
/// 읽는다 — 홈 운동 카드·운동 현황 링·주간 목표가 이미 근력을 세트로 세므로,
/// 목록만 분으로 적으면 같은 기록이 화면마다 다른 수로 보인다. (#1262, #1310)
String exerciseAmountLabel(AppLocalizations l, ExerciseSession s) {
  if (s.type != ExerciseType.strength) {
    return '${s.minutes}${l.unitMinutes}';
  }
  final int sets = s.sets ?? setsFromStrengthMinutes(s.minutes.toDouble());
  final int? reps = s.reps;
  final double? weight = s.weight;
  final StringBuffer buffer = StringBuffer(l.exSetsCount(sets));
  // 횟수·중량은 적었을 때만 붙인다 — 이 칸이 생기기 전 기록에 아무도 적지
  // 않은 수가 뜨면 안 된다.
  if (reps != null && reps > 0) buffer.write(' · ${l.exRepsCount(reps)}');
  if (weight != null && weight > 0) {
    buffer.write(' · ${NumberFormat('#,##0.#').format(weight)}${l.exUnitKg}');
  }
  return buffer.toString();
}

/// 운동 유형 → 화면 라벨. 유형별 분해 카드와 같은 문구를 쓴다.
String exerciseTypeLabel(AppLocalizations l, ExerciseType type) =>
    switch (type) {
      ExerciseType.cardio || ExerciseType.walking => l.exTypeCardio,
      ExerciseType.strength => l.exTypeStrength,
      ExerciseType.stretching || ExerciseType.yoga => l.exTypeFlexibility,
      // 기타는 기타라고 적는다 — 유산소로 적으면 하지 않은 운동을 한 것처럼
      // 읽힌다.
      ExerciseType.other => l.exTypeOtherChip,
    };
