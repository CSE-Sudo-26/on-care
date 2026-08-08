import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';

/// Uploads [imageBytes] to POST /diet/analyze, shows a live "분석 중" state
/// while the recognizer + nutrition mapping runs, then the recognized
/// foods + nutrition. Pops `true` once the user confirms (the entry is
/// already persisted server-side), so the record page can refresh.
class DietAnalyzePage extends ConsumerStatefulWidget {
  const DietAnalyzePage({
    required this.imageBytes,
    required this.mealType,
    super.key,
  });

  final Uint8List imageBytes;
  final String mealType;

  @override
  ConsumerState<DietAnalyzePage> createState() => _DietAnalyzePageState();
}

class _DietAnalyzePageState extends ConsumerState<DietAnalyzePage> {
  DietAnalysisResult? _result;
  bool _loading = true;
  bool _failed = false;
  late final String _idempotencyKey =
      'diet-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await ref
          .read(dietRepositoryProvider)
          .analyze(
            imageBytes: widget.imageBytes,
            filename: 'meal.jpg',
            mealType: widget.mealType,
            idempotencyKey: _idempotencyKey,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.foreground),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          _result != null ? '분석 결과' : '식단 분석',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? _Analyzing(imageBytes: widget.imageBytes)
            : _failed
            ? _Failed(
                onRetry: _run,
                onClose: () => Navigator.of(context).pop(false),
              )
            : _Result(
                imageBytes: widget.imageBytes,
                result: _result!,
                onDone: () => Navigator.of(context).pop(true),
              ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.bytes, this.size = 132});
  final Uint8List bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}

class _Analyzing extends StatelessWidget {
  const _Analyzing({required this.imageBytes});
  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Thumbnail(bytes: imageBytes),
          const SizedBox(height: AppSpacing.xl),
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'AI가 식단을 분석하고 있어요',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '음식 인식 · 영양 정보 계산 중 · 보통 2~3초',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry, required this.onClose});
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: AppColors.warning, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              '분석에 실패했어요',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '잠시 후 다시 시도해 주세요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                OutlinedButton(onPressed: onClose, child: const Text('닫기')),
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.imageBytes,
    required this.result,
    required this.onDone,
  });

  final Uint8List imageBytes;
  final DietAnalysisResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Center(child: _Thumbnail(bytes: imageBytes, size: 160)),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '인식된 음식',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final f in result.foods)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                f.name,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            if (f.isFromDb) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.all(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: const Text(
                                  'DB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${f.calories} kcal',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.all(AppRadius.lg),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _Metric(
                      label: '칼로리',
                      value: '${result.totalCalories}',
                      unit: 'kcal',
                    ),
                    _Metric(
                      label: '나트륨',
                      value: '${result.totalSodiumMg}',
                      unit: 'mg',
                    ),
                    _Metric(
                      label: '당류',
                      value: '${result.totalSugarG}',
                      unit: 'g',
                    ),
                  ],
                ),
              ),
              if (result.coachComment.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.all(AppRadius.lg),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.smart_toy_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          result.coachComment,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(AppRadius.lg),
                ),
              ),
              child: const Text('식단에 추가하기'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
