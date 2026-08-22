import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/number_format.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_ai_analysis_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_day_record_tile.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_exercise_status_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_period_section.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/exercise_line.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart' show EmptyHint;

/// 운동 — 기록 확인 중심 화면. 얼마나 했나(운동 현황) → 무엇을 했나(운동
/// 기록) 순서로 답한다(#1025).
///
/// 배정·취소처럼 루틴을 **관리**하는 일은 프로그램 탭의 몫이다 — 배정된 루틴
/// 목록과 배정·취소가 이미 그 화면에 있다(취소는 #1020). 여기서 같은 목록을
/// 한 번 더 보여주면, 잘못 배정한 루틴을 어느 화면에서 고쳐야 하는지
/// 트레이너가 매번 헷갈린다.
class WorkoutView extends ConsumerStatefulWidget {
  /// Creates the workout view for [client].
  const WorkoutView({super.key, required this.client, this.embedded = false});

  /// The client whose routines, sessions and history are shown.
  final TrainerClient client;

  /// When true, lets the member detail own the single page scroll.
  final bool embedded;

  @override
  ConsumerState<WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends ConsumerState<WorkoutView> {
  /// 기본은 **오늘** — 식단 탭과 첫 화면의 기준을 맞춘다.
  ClientPeriod _period = ClientPeriod.today;

  @override
  Widget build(BuildContext context) {
    final TrainerClient client = widget.client;
    final bool embedded = widget.embedded;
    final AppLocalizations l = AppLocalizations.of(context);
    final history = ref.watch(clientHistoryProvider(client.id));

    // 운동현황이 화면 맨 위다 — "얼마나 했나" 가 "무엇을 했나" 보다 먼저
    // 답해야 할 질문이다(#1025). 기록 목록은 자기 async 상태를 따로 들고
    // 있어, /history 가 실패해도 운동현황은 그대로 보인다.
    final children = <Widget>[
      ClientPeriodSection(
        icon: Icons.monitor_heart_outlined,
        title: l.clientTrendTitle,
        period: _period,
        onChanged: (ClientPeriod p) => setState(() => _period = p),
        child: ClientExerciseStatusCard(clientId: client.id, period: _period),
      ),
      // 기간을 고르면 그 기간의 날짜별 기록과 조언이 따라온다(#1025).
      // 오늘은 아래 기록 카드가 이미 그날을 낱낱이 말하므로 겹치지 않는다.
      if (_period != ClientPeriod.today) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        _DailyExerciseRecords(clientId: client.id, period: _period),
      ],
      const SizedBox(height: AppSpacing.md),
      _ExerciseAiComment(clientId: client.id, period: _period),
      const SizedBox(height: AppSpacing.lg),
      Text(
        l.workoutRecords,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.subtleForeground,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      ...history.when(
        loading: () => const <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
        error: (e, _) => <Widget>[
          EmptyHint(
            message: l.workoutLoadFailed,
            icon: Icons.error_outline,
            action: ActionButton(
              key: ValueKey<String>('workout-history-retry-${client.id}'),
              label: l.actionRetry,
              onPressed: history.isLoading
                  ? null
                  : () => ref.invalidate(clientHistoryProvider(client.id)),
            ),
          ),
        ],
        data: (entries) => <Widget>[
          if (entries.isEmpty)
            EmptyHint(
              message: l.workoutEmpty,
              icon: Icons.fitness_center_outlined,
            ),
          for (final entry in entries) ...<Widget>[
            _HistoryCard(clientId: client.id, entry: entry),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    ];
    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: children,
    );
  }
}

/// 완료 상태 색 — 100% 완료(초록) / 진행 중(주황) / 미시작(회색).
///
/// '부분' 은 진행 상태이지 주의가 아니다. 빨강으로 올리면 아무것도 하지 않은
/// 0%(회색)보다 부분 완료가 더 위험해 보여 척도가 뒤집힌다(#690).
Color _rateColor(int rate) {
  // 100% 초록은 회원 앱이 쓰는 어두운 초록과 같은 토큰이다 — 같은 성취를 두
  // 앱이 다른 초록으로 칠하면 나란히 놓고 이야기할 때 서로 다른 것처럼
  // 보인다(#1025).
  if (rate >= 100) return AppColors.statusNormal;
  if (rate > 0) return AppColors.brandOrange;
  return AppColors.borderStrong;
}

/// A single workout record, styled as a mission card: date/kind, a
/// completion badge, exercise lines (skipped ones struck through), client
/// feedback, trainer note.
class _HistoryCard extends ConsumerStatefulWidget {
  const _HistoryCard({required this.clientId, required this.entry});

  final String clientId;
  final RoutineHistoryEntry entry;

  @override
  ConsumerState<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends ConsumerState<_HistoryCard> {
  bool _saving = false;

  Future<void> _editFeedback() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final String? feedback = await showDialog<String>(
      context: context,
      builder: (_) => _FeedbackDialog(initialValue: widget.entry.trainerNote),
    );
    if (feedback == null || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(clientRepositoryProvider)
          .updateHistoryFeedback(widget.clientId, widget.entry.id, feedback);
      ref.invalidate(clientHistoryProvider(widget.clientId));
      messenger.showSnackBar(SnackBar(content: Text(l.routineFeedbackSaved)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            serverDetailOr(
              l,
              error is AppError ? error.message : null,
              l.routineFeedbackFailed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final RoutineHistoryEntry entry = widget.entry;
    // 미션 카드 — 왼쪽 띠 색이 완료 상태를 한눈에 말한다. 원형 게이지는
    // 지웠다: 몇 개 중 몇 개를 했는지는 바로 아래 줄이 이미 정확히 말하고,
    // 카드 전체가 "이 미션을 깼는가" 를 색 하나로 답하면 충분하다(#1025).
    //
    // 다른 세 변에는 색을 주지 않는다 — `Border` 에 보이는 색이 두 가지면
    // (띠 색 + 회색 테두리) `borderRadius` 와 함께 그릴 수 없어 런타임에
    // 터진다(Flutter `BoxBorder`, 보이는 색이 하나일 때만 둥근 모서리를
    // 그린다). `_NoteBox` 의 왼쪽 띠와 같은 규칙이다.
    final Color statusColor = _rateColor(entry.completionRate);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.dateLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 운동 유형/분류 — 글씨를 키우고 칩으로 올려 카드에서
                    // 눈에 먼저 들어오게 한다(#1025).
                    _RecordTypeChip(label: entry.label),
                    // 옆의 배지에 적힌 67% 가 어디서 나온 값인지 — 배정한 운동
                    // 중 몇 개를 했는가다. 이 한 줄이 없으면 화면 어디에도
                    // 그 분모가 없다(#754).
                    if (entry.exercises.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l.workoutDoneOfTotal(
                            entry.exercises.length,
                            entry.exercises
                                .where((line) => !line.contains('✗'))
                                .length,
                          ),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.disabledForeground,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _MissionBadge(rate: entry.completionRate),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in entry.exercises) ExerciseLine(line: line),
          if (entry.clientFeedback.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _NoteBox(
              title: l.clientFeedback,
              body: entry.clientFeedback,
              color: AppColors.accent,
            ),
          ],
          if (entry.trainerNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _NoteBox(
              title: l.trainerNote,
              body: entry.trainerNote,
              // 노트다. 주의가 아니므로 빨강으로 올리지 않는다(#690).
              color: AppColors.brandOrange,
            ),
          ],
          if (entry.assignedRoutineId != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: ActionButton(
                key: ValueKey<String>('routine-feedback-${entry.id}'),
                label: entry.trainerNote.isEmpty
                    ? l.routineFeedbackWrite
                    : l.routineFeedbackEdit,
                onPressed: _saving ? null : _editFeedback,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.routineFeedbackTitle),
      content: TextField(
        key: const ValueKey<String>('routine-feedback-input'),
        controller: _controller,
        autofocus: true,
        maxLength: 2000,
        maxLines: 5,
        decoration: InputDecoration(hintText: l.routineFeedbackHint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('routine-feedback-save'),
          onPressed: () {
            final String text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.of(context).pop(text);
          },
          child: Text(l.actionSave),
        ),
      ],
    );
  }
}

/// 완료 배지 — 원형 게이지 대신 아이콘·색·글자로 한 번에 말한다(#1025).
///
/// 미션을 깼는지가 중요하지, 정밀한 gauge 가 중요한 자리가 아니다. 100%는
/// 트로피, 진행 중은 깃발, 0%는 빈 원으로 — 숫자를 안 읽어도 색과 아이콘만
/// 으로 상태가 읽힌다.
class _MissionBadge extends StatelessWidget {
  const _MissionBadge({required this.rate});

  final int rate;

  @override
  Widget build(BuildContext context) {
    final Color color = _rateColor(rate);
    final IconData icon = rate >= 100
        ? Icons.emoji_events_outlined
        : rate > 0
        ? Icons.flag_outlined
        : Icons.radio_button_unchecked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: IconLabel(
        icon: icon,
        label: '$rate%',
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// 운동 유형/분류 칩 — 글씨를 키우고 칩으로 올려 시선이 먼저 닿게 한다
/// (#1025). 기록 하나가 실제로 들고 오는 분류는 이 값(세션 종류) 뿐이다 —
/// 개별 운동 항목에는 유산소/근력/유연성 같은 세부 유형이 실려 오지 않는다
/// (#996 스키마는 확정됐지만, 기록에 세부 종목 필드가 내려오는지는 별도
/// 확인이 필요하다).
class _RecordTypeChip extends StatelessWidget {
  const _RecordTypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: const BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.all(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// Left-bordered note box ("고객 피드백" navy / "트레이너 메모" orange).
class _NoteBox extends StatelessWidget {
  const _NoteBox({
    required this.title,
    required this.body,
    required this.color,
  });

  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.4), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기간에 맞는 운동 조언. 식단과 **같은 카드**를 쓴다. (#1025)
///
/// 서버가 만든 문장이다 — 화면이 따로 계산하면 같은 회원의 같은 주를 두 곳이
/// 다르게 말한다(식단이 #1017 에서 겪은 것과 같은 문제다).
class _ExerciseAiComment extends ConsumerWidget {
  const _ExerciseAiComment({required this.clientId, required this.period});

  final String clientId;
  final ClientPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 아직 오지 않았거나 실패하면 카드를 세우지 않는다. 운동에는 식단의
    // `dietAiBalanced` 같은 화면 쪽 대체 문구가 없다 — 없는 조언을 지어내는
    // 대신 자리를 비운다.
    final String message =
        ref
            .watch(
              clientExerciseAdviceProvider((
                clientId: clientId,
                period: period,
              )),
            )
            .valueOrNull ??
        '';
    return ClientAiAnalysisCard(
      cardKey: const ValueKey<String>('exercise-ai-analysis'),
      period: period,
      message: message,
    );
  }
}

/// 기간의 날짜별 운동 기록 — 눌러서 펼친다. (#1025)
///
/// 식단과 같은 줄([ClientDayRecordTile])을 쓴다. 위 [ClientExerciseStatusCard]
/// 가 이미 읽어 둔 같은 기간 데이터를 다시 구독하므로 요청이 더 나가지 않는다.
class _DailyExerciseRecords extends ConsumerStatefulWidget {
  const _DailyExerciseRecords({required this.clientId, required this.period});

  final String clientId;
  final ClientPeriod period;

  @override
  ConsumerState<_DailyExerciseRecords> createState() =>
      _DailyExerciseRecordsState();
}

class _DailyExerciseRecordsState extends ConsumerState<_DailyExerciseRecords> {
  /// 펼쳐 둔 날. 하나만 연다 — 식단과 같은 규칙이다.
  String? _openDay;

  @override
  void didUpdateWidget(_DailyExerciseRecords old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period || old.clientId != widget.clientId) {
      _openDay = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ClientPeriodKey key = clientPeriodKeyNow(
      widget.clientId,
      widget.period,
    );
    final AsyncValue<ClientExercisePeriod> async = ref.watch(
      clientExercisePeriodProvider(key),
    );
    return async.maybeWhen(
      data: (ClientExercisePeriod period) => Column(
        key: const ValueKey<String>('exercise-daily-records'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ClientExerciseDay day in period.days.reversed)
            ClientDayRecordTile(
              date: day.date,
              // 쉰 날과 적지 않은 날을 가르는 기준은 그날 움직인 시간이다.
              logged: day.minutes > 0,
              expanded: _openDay == ymd(day.date),
              onToggle: () => setState(() {
                _openDay = _openDay == ymd(day.date) ? null : ymd(day.date);
              }),
              emptyLabel: l.dietDayEmpty,
              summary:
                  '${day.minutes}${l.unitMinutes} · '
                  '${formatNumber(day.calories)} ${l.unitKcal}',
              details: <({String label, String value})>[
                (
                  label: l.clientTrendWorkoutMinutes,
                  value: '${day.minutes}${l.unitMinutes}',
                ),
                (
                  label: l.metricCalories,
                  value: '${formatNumber(day.calories)} ${l.unitKcal}',
                ),
                if (day.cardioMinutes > 0)
                  (
                    label: l.routineTypeCardio,
                    value: '${day.cardioMinutes}${l.unitMinutes}',
                  ),
                if (day.strengthMinutes > 0)
                  (
                    label: l.routineTypeStrength,
                    value: '${day.strengthMinutes}${l.unitMinutes}',
                  ),
                if (day.stretchingMinutes > 0)
                  (
                    label: l.routineTypeFlexibility,
                    value: '${day.stretchingMinutes}${l.unitMinutes}',
                  ),
                if (day.otherMinutes > 0)
                  (
                    label: l.routineTypeOther,
                    value: '${day.otherMinutes}${l.unitMinutes}',
                  ),
              ],
            ),
        ],
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
