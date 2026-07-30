import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/trainer_routine_options_repository.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/routine_options.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// The 3-step AI routine flow: 1) analyse the member + steer the request,
/// 2) compare the A/B plans the AI generated from their data, 3) pick, edit
/// and send — the selected plan is assigned so the member receives it.
class AiRoutineOptionsFlow extends ConsumerStatefulWidget {
  const AiRoutineOptionsFlow({required this.client, super.key});

  final TrainerClient client;

  @override
  ConsumerState<AiRoutineOptionsFlow> createState() =>
      _AiRoutineOptionsFlowState();
}

class _AiRoutineOptionsFlowState extends ConsumerState<AiRoutineOptionsFlow> {
  int _step = 0; // 0 = 분석·조종, 1 = A/B 비교, 2 = 수정·전송

  // Step 1 steering inputs.
  int _minutes = 30;
  String _intensity = 'moderate';
  final TextEditingController _note = TextEditingController();

  bool _generating = false;
  RoutineOptions? _options;

  // Step 2 selection / step 3 edits.
  String _selectedKey = 'A';
  List<RoutineExercise> _edited = <RoutineExercise>[];
  final TextEditingController _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    _comment.dispose();
    super.dispose();
  }

  RoutinePlan get _selectedPlan =>
      _selectedKey == 'A' ? _options!.planA : _options!.planB;

  Future<void> _generate() async {
    if (_generating) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generating = true);
    try {
      final options = await ref
          .read(trainerRoutineOptionsRepositoryProvider)
          .generate(
            widget.client.id,
            availableMinutes: _minutes,
            intensityPreference: _intensity,
            trainerNote: _note.text,
          );
      if (!mounted) return;
      setState(() {
        _options = options;
        _step = 1;
      });
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('AI 생성에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _chooseAndEdit() {
    setState(() {
      _edited = List<RoutineExercise>.of(_selectedPlan.exercises);
      _step = 2;
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_edited.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운동을 하나 이상 남겨 주세요')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(trainerRoutineRepositoryProvider)
          .assignRoutine(widget.client.id, _composeRoutine());
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('전송에 실패했어요. 다시 시도해 주세요')),
      );
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('✓ ${widget.client.name}님에게 루틴을 전송했어요')),
    );
    navigator.pop(true);
  }

  AssignedRoutine _composeRoutine() {
    final total = _edited.fold<int>(0, (s, e) => s + e.minutes);
    final counts = <String, int>{};
    for (final e in _edited) {
      counts[e.type] = (counts[e.type] ?? 0) + 1;
    }
    var type = '근력';
    var best = 0;
    counts.forEach((t, c) {
      if (c > best) {
        best = c;
        type = t;
      }
    });
    final comment = _comment.text.trim();
    return AssignedRoutine(
      id: '',
      name: 'AI 맞춤 루틴 ($_selectedKey안)',
      minutes: total,
      type: type,
      reason: comment.isEmpty ? _selectedPlan.reason : comment,
      source: 'ai',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.foreground,
        title: Text('AI 루틴 · ${widget.client.name}'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _StepHeader(step: _step),
            Expanded(
              child: switch (_step) {
                0 => _buildSteer(),
                1 => _buildCompare(),
                _ => _buildEditSend(),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- Step 1: analyse + steer -------------------------------------------

  Widget _buildSteer() {
    final c = widget.client;
    final over = c.sodiumOverBudget;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: <Widget>[
        _card(
          title: '회원 분석',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _analysisRow('목표', c.goal),
              _analysisRow(
                '오늘 나트륨',
                '${c.sodiumMg}mg${over ? ' · 목표 초과' : ''}',
                warn: over,
              ),
              _analysisRow('마지막 루틴', c.lastRoutine),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _card(
          title: '방향 설정',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('가능한 운동 시간', style: _labelStyle),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: <int>[20, 30, 45, 60]
                    .map((m) => _choiceChip('$m분', _minutes == m,
                        () => setState(() => _minutes = m)))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('강도', style: _labelStyle),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: <(String, String)>[
                  ('낮음', 'low'),
                  ('보통', 'moderate'),
                  ('높음', 'high'),
                ]
                    .map((e) => _choiceChip(e.$1, _intensity == e.$2,
                        () => setState(() => _intensity = e.$2)))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('주의사항 (선택)', style: _labelStyle),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  hintText: '예: 무릎 부담이 적은 운동 중심',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _primaryButton(
          label: _generating ? 'AI가 분석 중…' : '✦ AI로 A/B 루틴 생성',
          busy: _generating,
          onTap: _generate,
        ),
      ],
    );
  }

  // ---- Step 2: compare A/B ------------------------------------------------

  Widget _buildCompare() {
    final o = _options!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accentSurface,
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Text(
            '✦ ${o.analysis.goal} · 오늘 나트륨 ${o.analysis.sodiumTodayMg}mg'
            '${o.analysis.sodiumOverTarget ? '(초과)' : ''} · 완료율 '
            '${o.analysis.avgCompletionRate}% 기준으로 생성했어요'
            '${o.generatedBy == 'rule' ? ' (규칙 기반)' : ''}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _planCard(o.planA),
        const SizedBox(height: AppSpacing.md),
        _planCard(o.planB),
        const SizedBox(height: AppSpacing.xl),
        _primaryButton(label: '$_selectedKey안 선택하고 수정', onTap: _chooseAndEdit),
      ],
    );
  }

  Widget _planCard(RoutinePlan plan) {
    final selected = _selectedKey == plan.key;
    return GestureDetector(
      onTap: () => setState(() => _selectedKey = plan.key),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.all(AppRadius.card),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderStrong,
            width: selected ? 2 : 1,
          ),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? AppColors.accent : AppColors.mutedForeground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${plan.key}안 · ${plan.label}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const Spacer(),
                Text(
                  '총 ${plan.totalMinutes}분 · 강도 ${plan.intensity}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final e in plan.exercises)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '· ${e.name} · ${e.minutes}분 (${e.type})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                plan.rationale,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Step 3: edit + send -----------------------------------------------

  Widget _buildEditSend() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: <Widget>[
        Text(
          '$_selectedKey안 · ${_selectedPlan.label} — 수정 후 전송',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (int i = 0; i < _edited.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.all(AppRadius.card),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${_edited[i].name} · ${_edited[i].minutes}분 (${_edited[i].type})',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.mutedForeground,
                  onPressed: () => setState(() => _edited.removeAt(i)),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _comment,
          decoration: InputDecoration(
            hintText: '트레이너 코멘트 (회원에게 함께 전달)',
            isDense: true,
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _primaryButton(
          label: _sending ? '전송 중…' : '회원에게 전송',
          busy: _sending,
          onTap: _send,
        ),
      ],
    );
  }

  // ---- shared bits -------------------------------------------------------

  Widget _card({required String title, required Widget child}) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.all(AppRadius.card),
          border: Border.all(color: AppColors.borderStrong),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      );

  Widget _analysisRow(String label, String value, {bool warn = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 78,
              child: Text(label, style: _labelStyle),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: warn ? AppColors.warning : AppColors.foreground,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _choiceChip(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: on ? AppColors.accent : AppColors.inputBackground,
            borderRadius: const BorderRadius.all(AppRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: on ? AppColors.accentForeground : AppColors.mutedForeground,
            ),
          ),
        ),
      );

  Widget _primaryButton({
    required String label,
    required VoidCallback onTap,
    bool busy = false,
  }) =>
      Material(
        color: busy ? AppColors.disabledForeground : AppColors.primary,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: const BorderRadius.all(AppRadius.lg),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryForeground,
              ),
            ),
          ),
        ),
      );
}

const TextStyle _labelStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w700,
  color: AppColors.mutedForeground,
);

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['1 분석', '2 A/B 비교', '3 전송'];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < labels.length; i++) ...<Widget>[
            Expanded(
              child: Container(
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i <= step ? AppColors.accent : AppColors.inputBackground,
                  borderRadius: const BorderRadius.all(AppRadius.pill),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: i <= step
                        ? AppColors.accentForeground
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
            if (i < labels.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
