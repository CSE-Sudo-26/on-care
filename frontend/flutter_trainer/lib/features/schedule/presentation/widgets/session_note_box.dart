import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 완료된 세션에 남긴 트레이너 메모 상자.
class SessionNoteBox extends StatelessWidget {
  const SessionNoteBox({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border(
          left: BorderSide(
            color: AppColors.brandOrange.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.schedNote,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              // 메모지 표시다. 주의가 아니므로 빨강으로 올리지 않는다(#690).
              color: AppColors.brandOrange,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
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

/// 아직 메모가 없는 상담 세션의 자리. (#988)
///
/// 상담은 운동 프로그램을 짜는 자리가 아니라 **무슨 이야기를 나눴는지** 를 적는
/// 자리다. 프로그램이 없다는 안내([SessionNoPlanBox])를 그대로 쓰면, 짜야 할
/// 프로그램이 밀려 있는 것처럼 읽힌다.
///
/// `메모 추가` 는 이 설명과 나란히, 박스 오른쪽에 선다. 예전에는 아래
/// [SessionManageRow] 의 다른 동작들과 섞여 있어, "상담은 메모로 남긴다" 는
/// 이 설명과 그 동작을 잇는 자리가 따로 없었다.
class SessionNoNoteBox extends StatelessWidget {
  /// Creates the empty-note hint.
  const SessionNoNoteBox({super.key, required this.onAdd});

  /// 메모를 처음 적는 자리를 연다.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('session-no-note'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.schedNoNote,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.schedNoteOnlyHint,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.subtleForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 키는 이 자리 전체(`_NoteAddChip`)에 둔다 — `session_manage_row.dart`
          // 의 `_ActionChip` 과 같은 규약이라, 테스트가 툴팁 문구를 그 자손에서
          // 찾는 방식(`noteActionLabel`)을 그대로 쓸 수 있다.
          _NoteAddChip(
            key: const ValueKey<String>('session-edit-note-chip'),
            label: l.schedAddNote,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _NoteAddChip extends StatelessWidget {
  const _NoteAddChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: AppColors.brandOrange.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(AppRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(AppRadius.pill),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Icon(
                Icons.note_add_outlined,
                size: 15,
                color: AppColors.brandOrange,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
