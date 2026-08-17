import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_suggestion.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_form_fields.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 수정 후 추천으로 나가는 값. 취소는 null 이다.
typedef RoutineSuggestionEdit = ({
  String name,
  int minutes,
  String type,
  String reason,
});

/// Opens the minimal editor for one AI personal-exercise suggestion (#790).
///
/// 개인운동 하나를 고치려고 정규 프로그램 편집기로 보내지 않는다 — 그쪽은 여러
/// 세션과 운동 구성을 다루는 화면이라, `8분 스트레칭을 10분으로` 같은 판단에
/// 필요한 것보다 훨씬 크다. 그래서 이 dialog 는 승인 판단에 필요한 필드만 둔다.
///
/// **강도 필드는 없다.** 배정 루틴에는 강도가 없고(회원 화면도 보여 주지 않는다),
/// 넣더라도 어디에도 닿지 않는 값이 된다. 강도 조절은 시간·운동 유형과 회원에게
/// 전달할 메모로 표현한다.
Future<RoutineSuggestionEdit?> showRoutineSuggestionEditDialog(
  BuildContext context,
  RoutineSuggestion suggestion,
) {
  return showDialog<RoutineSuggestionEdit>(
    context: context,
    builder: (_) => RoutineSuggestionEditDialog(suggestion: suggestion),
  );
}

/// The minimal edit form for a pending suggestion.
class RoutineSuggestionEditDialog extends StatefulWidget {
  /// Creates the dialog for [suggestion].
  const RoutineSuggestionEditDialog({super.key, required this.suggestion});

  /// The suggestion being edited. Values seed the form.
  final RoutineSuggestion suggestion;

  @override
  State<RoutineSuggestionEditDialog> createState() =>
      _RoutineSuggestionEditDialogState();
}

class _RoutineSuggestionEditDialogState
    extends State<RoutineSuggestionEditDialog> {
  /// 서버 스키마(`RoutineSuggestionApproveRequest`)와 같은 상한. 여기서 막으면
  /// 422 왕복 없이 그 자리에서 알 수 있다.
  static const int _nameMaxLength = 100;
  static const int _reasonMaxLength = 200;

  late final TextEditingController _name = TextEditingController(
    text: widget.suggestion.name,
  );
  late final TextEditingController _reason = TextEditingController(
    text: widget.suggestion.reason,
  );
  late String _type = widget.suggestion.type;
  late int _minutes = widget.suggestion.minutes;

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    // 이름을 지운 채 보내면 서버가 400 이다. 버튼을 막는 대신 그대로 두는 편이
    // 낫다 — 이름을 지운 것은 대개 다시 쓰려는 중이다.
    if (name.isEmpty) return;
    Navigator.of(context).pop((
      name: name,
      minutes: _minutes,
      type: _type,
      reason: _reason.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      title: Text(
        l.suggestionEditTitle,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _FieldLabel(l.suggestionEditName),
              TextField(
                key: const ValueKey<String>('suggestion-edit-name'),
                controller: _name,
                maxLength: _nameMaxLength,
                decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              RoutineMinutesSlider(
                minutes: _minutes,
                onChanged: (next) => setState(() => _minutes = next),
              ),
              const SizedBox(height: AppSpacing.sm),
              RoutineCategoryChips(
                keyPrefix: 'suggestion-edit-type',
                value: _type,
                onChanged: (next) => setState(() => _type = next),
              ),
              const SizedBox(height: AppSpacing.md),
              _FieldLabel(l.suggestionEditMemo),
              TextField(
                key: const ValueKey<String>('suggestion-edit-memo'),
                controller: _reason,
                maxLength: _reasonMaxLength,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: l.suggestionEditMemoHint,
                  border: const OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('suggestion-edit-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('suggestion-edit-submit'),
          onPressed: _submit,
          child: Text(l.suggestionEditSubmit),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.subtleForeground,
        ),
      ),
    );
  }
}
