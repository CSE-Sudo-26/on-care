import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/ai_routine_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/content_frame.dart';
import 'package:oncare_trainer/shared/widgets/metric_tile.dart';

/// Minute options offered for every routine item (mock: 10~45분 chips).
const List<int> _minuteOptions = <int>[10, 15, 20, 30, 45];

/// A trainer-added exercise (kept in-memory like the mock).
class _CustomExercise {
  const _CustomExercise({
    required this.name,
    required this.minutes,
    required this.type,
  });
  final String name;
  final int minutes;
  final String type;
}

/// AI 루틴 tab — pick a client, review their diet summary + the AI's
/// suggested routine, tweak names/minutes, add custom exercises, and
/// send. Edits and the sent state are in-memory (mock), matching the
/// Figma behaviour.
class AiRoutinePage extends ConsumerStatefulWidget {
  /// Creates the AI routine tab.
  const AiRoutinePage({super.key});

  @override
  ConsumerState<AiRoutinePage> createState() => _AiRoutinePageState();
}

class _AiRoutinePageState extends ConsumerState<AiRoutinePage> {
  String? _clientId; // null until clients load (defaults to the first)
  final Map<String, int> _minuteEdits = <String, int>{};
  final Map<String, String> _nameEdits = <String, String>{};
  String? _editingNameId;
  final List<_CustomExercise> _custom = <_CustomExercise>[];
  bool _showAddForm = false;
  bool _sent = false;
  Timer? _sentTimer;

  @override
  void dispose() {
    _sentTimer?.cancel();
    super.dispose();
  }

  void _selectClient(String id) {
    if (_clientId == id) return;
    setState(() {
      _clientId = id;
      // A different client gets a clean slate, like the mock.
      _minuteEdits.clear();
      _nameEdits.clear();
      _editingNameId = null;
      _custom.clear();
      _showAddForm = false;
      _sent = false;
    });
    _sentTimer?.cancel();
  }

  void _send() {
    if (_sent) return;
    setState(() => _sent = true);
    _sentTimer?.cancel();
    // Mock: after the confirmation, reset the edits for the next round.
    _sentTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _sent = false;
        _custom.clear();
        _minuteEdits.clear();
        _nameEdits.clear();
        // Close any editing UI too — otherwise an open name editor or
        // add-form would survive the "next round" reset (PR review).
        _editingNameId = null;
        _showAddForm = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ContentFrame(
          child: clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(
              child: Text(
                '고객 정보를 불러오지 못했어요',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ),
            data: (clients) {
              if (clients.isEmpty) {
                return const Center(
                  child: Text(
                    '등록된 고객이 없어요',
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                );
              }
              final selected = clients.firstWhere(
                (c) => c.id == _clientId,
                orElse: () => clients.first,
              );
              return _buildBody(clients, selected);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<TrainerClient> clients, TrainerClient client) {
    final routineAsync = ref.watch(aiRoutineProvider(client.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Text(
          'AI 루틴 생성',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Text(
          '고객 식단 · 건강 데이터 기반',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel('고객 선택'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (final c in clients) ...<Widget>[
              Expanded(
                child: _ClientChip(
                  client: c,
                  selected: c.id == client.id,
                  onTap: () => _selectClient(c.id),
                ),
              ),
              if (c != clients.last) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel('오늘 식단 요약'),
        const SizedBox(height: AppSpacing.sm),
        _DietSummaryCard(client: client),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            _sectionLabel('AI 추천 루틴'),
            const SizedBox(width: AppSpacing.xs),
            const Text(
              '· 수정 가능',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.disabledForeground,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: const BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: BorderRadius.all(AppRadius.pill),
              ),
              child: const Text(
                '✦ 자동 생성',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        routineAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const Text(
            '루틴을 불러오지 못했어요',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final item in items) ...<Widget>[
                _RoutineCard(
                  name: _nameEdits[item.id] ?? item.name,
                  minutes: _minuteEdits[item.id] ?? item.minutes,
                  type: item.type,
                  reason: item.reason,
                  isCustom: false,
                  editingName: _editingNameId == item.id,
                  onNameTap: () => setState(() => _editingNameId = item.id),
                  onNameChanged: (v) => _nameEdits[item.id] = v,
                  onNameDone: () => setState(() => _editingNameId = null),
                  onMinutes: (m) => setState(() => _minuteEdits[item.id] = m),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              for (var i = 0; i < _custom.length; i++) ...<Widget>[
                _RoutineCard(
                  name: _custom[i].name,
                  minutes: _custom[i].minutes,
                  type: _custom[i].type,
                  reason: '트레이너 추가',
                  isCustom: true,
                  onDelete: () => setState(() => _custom.removeAt(i)),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xs),
              _showAddForm
                  ? _AddExerciseForm(
                      onCancel: () => setState(() => _showAddForm = false),
                      onAdd: (name, minutes, type) => setState(() {
                        _custom.add(
                          _CustomExercise(
                            name: name,
                            minutes: minutes,
                            type: type,
                          ),
                        );
                        _showAddForm = false;
                      }),
                    )
                  : _AddExerciseButton(
                      onTap: () => setState(() => _showAddForm = true),
                    ),
              const SizedBox(height: AppSpacing.lg),
              _SendButton(clientName: client.name, sent: _sent, onSend: _send),
              if (_sent)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    '고객 앱에 알림이 전송됐어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: AppColors.subtleForeground,
      ),
    );
  }
}

class _ClientChip extends StatelessWidget {
  const _ClientChip({
    required this.client,
    required this.selected,
    required this.onTap,
  });

  final TrainerClient client;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: selected ? null : Border.all(color: AppColors.borderStrong),
          ),
          child: Column(
            children: <Widget>[
              selected
                  ? Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryForeground.withValues(
                          alpha: 0.25,
                        ),
                      ),
                      child: Text(
                        client.avatar,
                        style: const TextStyle(
                          color: AppColors.primaryForeground,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ClientAvatar(label: client.avatar, size: 32),
              const SizedBox(height: AppSpacing.xs),
              Text(
                client.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.primaryForeground
                      : AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diet summary — the shared metric tiles + the AI's verdict line.
class _DietSummaryCard extends StatelessWidget {
  const _DietSummaryCard({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final over = client.sodiumOverBudget;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              MetricTile(
                label: '칼로리',
                value: client.calories,
                unit: 'kcal',
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: '나트륨',
                value: client.sodiumMg,
                unit: 'mg',
                color: AppColors.accentDark,
                warn: over,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: '당류',
                value: client.sugarG,
                unit: 'g',
                color: AppColors.accentDark,
                warn: client.sugarG > sugarTargetG,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.accentSurface,
              borderRadius: BorderRadius.all(AppRadius.md),
            ),
            child: Text(
              over
                  ? '✦ AI 판단: 나트륨 초과 → 유산소 강화 권장'
                  : '✦ AI 판단: 식단 균형 양호 → 근력 중심 루틴 유지',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One routine card — AI items are editable (name + minutes); custom
/// items carry the orange trainer accent and a delete button.
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.name,
    required this.minutes,
    required this.type,
    required this.reason,
    required this.isCustom,
    this.editingName = false,
    this.onNameTap,
    this.onNameChanged,
    this.onNameDone,
    this.onMinutes,
    this.onDelete,
  });

  final String name;
  final int minutes;
  final String type;
  final String reason;
  final bool isCustom;
  final bool editingName;
  final VoidCallback? onNameTap;
  final ValueChanged<String>? onNameChanged;
  final VoidCallback? onNameDone;
  final ValueChanged<int>? onMinutes;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = isCustom ? AppColors.warning : AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(
          color: isCustom
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(AppRadius.pill),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: editingName
                    ? _NameEditField(
                        initial: name,
                        onChanged: onNameChanged,
                        onDone: onNameDone,
                      )
                    : GestureDetector(
                        onTap: onNameTap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                            if (!isCustom)
                              const Text(
                                '탭하여 수정',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: AppColors.disabledForeground,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              if (isCustom)
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.destructive,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '💡 $reason',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final m in _minuteOptions) ...<Widget>[
                _MinuteChip(
                  minutes: m,
                  selected: minutes == m,
                  accent: accent,
                  onTap: onMinutes == null ? null : () => onMinutes!(m),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              const Spacer(),
              Text(
                '$minutes분',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Inline name editor with a properly owned controller (creating a
/// TextEditingController inside build leaks it and resets state on
/// rebuild — /code-review finding).
class _NameEditField extends StatefulWidget {
  const _NameEditField({
    required this.initial,
    required this.onChanged,
    required this.onDone,
  });

  final String initial;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onDone;

  @override
  State<_NameEditField> createState() => _NameEditFieldState();
}

class _NameEditFieldState extends State<_NameEditField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  )..selection = TextSelection.collapsed(offset: widget.initial.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onDone?.call(),
      onTapOutside: (_) => widget.onDone?.call(),
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.accentSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.minutes,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected ? accent : AppColors.inputBackground,
          borderRadius: const BorderRadius.all(AppRadius.pill),
        ),
        child: Text(
          '$minutes분',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected
                ? AppColors.primaryForeground
                : AppColors.subtleForeground,
          ),
        ),
      ),
    );
  }
}

class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning.withValues(alpha: 0.04),
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: const Text(
            '＋ 운동 직접 추가',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "운동 추가" form — name, type, minutes, 취소/추가하기. Keeps the
/// orange trainer accent from the mock to distinguish manual additions.
class _AddExerciseForm extends StatefulWidget {
  const _AddExerciseForm({required this.onCancel, required this.onAdd});

  final VoidCallback onCancel;
  final void Function(String name, int minutes, String type) onAdd;

  @override
  State<_AddExerciseForm> createState() => _AddExerciseFormState();
}

class _AddExerciseFormState extends State<_AddExerciseForm> {
  final TextEditingController _name = TextEditingController();
  String _type = '근력';
  int _minutes = 15;

  static const List<String> _types = <String>['유산소', '근력', '스트레칭'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '운동 추가',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              hintText: '운동 이름 (예: 레그프레스 3세트)',
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final t in _types) ...<Widget>[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _type == t
                            ? AppColors.warning
                            : AppColors.inputBackground,
                        borderRadius: const BorderRadius.all(AppRadius.md),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _type == t
                              ? AppColors.warningForeground
                              : AppColors.subtleForeground,
                        ),
                      ),
                    ),
                  ),
                ),
                if (t != _types.last) const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final m in _minuteOptions) ...<Widget>[
                GestureDetector(
                  onTap: () => setState(() => _minutes = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _minutes == m
                          ? AppColors.warning
                          : AppColors.inputBackground,
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                    ),
                    child: Text(
                      '$m분',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _minutes == m
                            ? AppColors.warningForeground
                            : AppColors.subtleForeground,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _FormButton(
                  label: '취소',
                  background: AppColors.inputBackground,
                  foreground: AppColors.subtleForeground,
                  onTap: widget.onCancel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FormButton(
                  label: '추가하기',
                  background: AppColors.warning,
                  foreground: AppColors.warningForeground,
                  onTap: () {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    widget.onAdd(name, _minutes, _type);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormButton extends StatelessWidget {
  const _FormButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.clientName,
    required this.sent,
    required this.onSend,
  });

  final String clientName;
  final bool sent;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: sent ? AppColors.success : AppColors.primary,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: sent ? null : onSend,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: Text(
            sent ? '✓ $clientName님에게 전송 완료!' : '검토 완료 · $clientName님에게 전송',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}
