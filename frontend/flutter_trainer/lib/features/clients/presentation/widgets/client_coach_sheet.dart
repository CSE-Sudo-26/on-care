import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_coach_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 담당 회원에 대해 AI 에게 묻는 시트를 연다. (#497)
Future<void> showClientCoachSheet(
  BuildContext context, {
  required String memberId,
  required String clientName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ClientCoachSheet(memberId: memberId, clientName: clientName),
  );
}

/// AI 코칭 상담 — 이 회원에 대해 묻고, 근거와 함께 답을 받는다.
///
/// 탭이 아니라 시트인 이유: 트레이너가 상시로 보는 화면이 아니라 판단이 필요할
/// 때 한 번 여는 도구다. 대상이 l.coachSheetThisClient이라 고객 상세에서 연다.
///
/// 대화를 이어 가지 않는다 — 서버 엔드포인트가 무상태이고, 회원 앱의 대화
/// 저장(#274)과는 별개 도메인이다. 한 번에 한 질문으로 충분하다.
class _ClientCoachSheet extends ConsumerStatefulWidget {
  const _ClientCoachSheet({required this.memberId, required this.clientName});

  final String memberId;
  final String clientName;

  @override
  ConsumerState<_ClientCoachSheet> createState() => _ClientCoachSheetState();
}

class _ClientCoachSheetState extends ConsumerState<_ClientCoachSheet> {
  final TextEditingController _question = TextEditingController();
  bool _asking = false;
  ClientCoachAnswer? _answer;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final String message = _question.text.trim();
    // 빈 질문은 서버도 400 이다. 왕복할 이유가 없다.
    if (message.isEmpty || _asking) return;

    setState(() {
      _asking = true;
      _error = null;
    });
    try {
      final ClientCoachAnswer answer = await ref
          .read(clientCoachRepositoryProvider)
          .ask(memberId: widget.memberId, message: message);
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _asking = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      final AppLocalizations l = AppLocalizations.of(context);
      setState(() {
        // 서버가 준 사유가 있으면 그대로(서버 문구의 다국어는 별건), 없으면
        // 오류 종류에 맞는 문구를 화면이 붙인다. (#501)
        _error =
            e.message ??
            switch (e) {
              NotFoundError() => l.coachNotMyClient,
              ValidationError() => l.coachDemoUnavailable,
              _ => l.coachAskFailed,
            };
        _asking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(l.coachSheetTitle(widget.clientName)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l.coachSheetSubtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _question,
                maxLines: 3,
                maxLength: 1000,
                enabled: !_asking,
                onSubmitted: (_) => _ask(),
                decoration: InputDecoration(
                  hintText: l.coachSheetHint,
                  filled: true,
                  fillColor: AppColors.inputBackground,
                ),
              ),
              if (_asking) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _Note(tone: AppColors.destructive, text: _error!),
              ],
              if (_answer != null && !_asking) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _Note(tone: AppColors.primary, text: _answer!.reply),
                if (_answer!.sources.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l.coachSheetSources,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.subtleForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  for (final String source in _answer!.sources)
                    Text(
                      '· $source',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _asking ? null : () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
        ActionButton(
          label: _answer == null ? l.coachSheetAsk : l.coachSheetAskAgain,
          primary: true,
          onPressed: _asking ? null : _ask,
        ),
      ],
    );
  }
}

/// 답변·오류를 담는 색 있는 블록.
class _Note extends StatelessWidget {
  const _Note({required this.tone, required this.text});

  final Color tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(AppRadius.card),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppColors.foreground,
        ),
      ),
    );
  }
}
