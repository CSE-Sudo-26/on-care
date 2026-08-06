import 'package:flutter/material.dart';

import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/chat_controller.dart';
import 'package:oncare/features/ai_coach/presentation/pages/coach_chat_page.dart';

const LinearGradient _coachGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[AppColors.primary, AppColors.secondary],
);

/// Home-screen entry point to the AI coach. Shows 온이's daily note and an
/// input-styled bar + starter chips that open the interactive chat.
class CoachChatCard extends StatelessWidget {
  const CoachChatCard({this.dietLine, this.exerciseLine, super.key});

  final String? dietLine;
  final String? exerciseLine;

  void _open(BuildContext context, {String? prompt}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoachChatPage(initialMessage: prompt),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> notes = <String>[?dietLine, ?exerciseLine];

    return AppCard(
      outlined: true,
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: _coachGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '온이',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'AI 건강 코치',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.mutedForeground,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (notes.isEmpty)
            Text(
              '오늘 건강에 대해 궁금한 점을 물어보세요. 식단·운동·혈압·혈당 무엇이든 도와드릴게요.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            )
          else
            for (int i = 0; i < notes.length; i++) ...<Widget>[
              Text(
                notes[i],
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              if (i < notes.length - 1) const SizedBox(height: AppSpacing.xs),
            ],
          const SizedBox(height: AppSpacing.md),
          // Input-styled bar (tap → open chat).
          Container(
            decoration: const BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.all(AppRadius.pill),
            ),
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 10, 6, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '온이에게 물어보세요…',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: _coachGradient,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Starter prompt chips.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String p in kCoachPrompts.take(3))
                Material(
                  color: AppColors.accent,
                  borderRadius: const BorderRadius.all(AppRadius.pill),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(AppRadius.pill),
                    onTap: () => _open(context, prompt: p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      child: Text(
                        p,
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
