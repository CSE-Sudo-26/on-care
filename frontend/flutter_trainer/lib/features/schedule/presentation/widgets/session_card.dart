import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_chips.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_ended_box.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_manage_row.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_note_box.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_program_section.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';

/// 타임라인의 세션 한 건 — 접으면 시간·이름·상태, 펼치면 그날 할 일.
///
/// 완료된 세션은 프로그램과 메모를 보여 주고 고객에게 보낼 수 있다. 예정된
/// 세션은 계획(없으면 [SessionNoPlanBox])과 수정·삭제·채팅 동선을 연다.
/// 취소·노쇼로 끝난 세션은 [SessionEndedBox] 로 그 기록을 남긴다.
class SessionCard extends ConsumerWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    this.onCancel,
    this.onNoShow,
    required this.programDateLabel,
    required this.sendingProgram,
    required this.onSendProgram,
    required this.inlineEditor,
  });

  final ScheduleSession session;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;
  final VoidCallback onDelete;
  final VoidCallback onChat;

  /// 예정 세션의 `취소`·`노쇼` 기록 처리. 대상이 아니면 null 이라 화면에 나오지
  /// 않는다 — 서버가 409 로 막을 동작을 아예 내놓지 않는다(#871).
  final VoidCallback? onCancel;
  final VoidCallback? onNoShow;
  final String programDateLabel;
  final Widget? inlineEditor;

  /// 이 세션의 프로그램 전송이 진행 중인가. (#822)
  final bool sendingProgram;

  /// 완료한 세션의 프로그램을 회원에게 보낸다.
  final VoidCallback onSendProgram;

  /// 예정 sessions only — flips to 완료 and logs the 운동기록.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final s = session;
    final roster =
        ref.watch(clientsProvider).valueOrNull ?? const <TrainerClient>[];
    final client = findClientIdentity(
      roster,
      clientId: session.clientId,
      clientName: session.clientName,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(
          color: s.isDone
              ? AppColors.border
              : AppColors.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: s.expandable ? onToggle : null,
            borderRadius: const BorderRadius.all(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  // 시각은 일 보기 타임라인의 왼쪽 홈통이 그리던 값이다. 보기가
                  // 시간표 하나로 모이면서 그 홈통이 사라졌으므로, 카드가 직접
                  // 말한다 — 상세 패널에서 "몇 시 약속인가" 가 빠지면 카드만
                  // 보고는 알 수 없다(#988).
                  SizedBox(
                    width: 46,
                    child: Text(
                      s.time,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: s.isFinished
                            ? AppColors.disabledForeground
                            : AppColors.foreground,
                      ),
                    ),
                  ),
                  ClientAvatar(
                    // Guard: a non-gap row with an empty name must not
                    // crash `.characters.first`.
                    label: s.clientName.isEmpty
                        ? '?'
                        : s.clientName.characters.first,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (client == null)
                          // 로스터에 없는 고객은 이름 뒤에 `(신규)` 로 그
                          // 사실을 단다 — 이름 자리에 `신규 고객` 이라는
                          // 분류명을 넣으면 서로 구분되지 않는다(#988).
                          Text(
                            clientNameWithNewTag(
                              l,
                              roster,
                              clientId: s.clientId,
                              clientName: s.clientName,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          )
                        else ...<Widget>[
                          ClientIdentity(
                            client: client,
                            nameStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                          // 오늘 만날 회원이 무엇을 목표로 하는 사람인지는
                          // 세션 종류·소요 시간만큼 자리에서 필요하다(#898).
                          ClientGoalLabel(client: client),
                        ],
                      ],
                    ),
                  ),
                  // 세션 종류·소요 시간은 **이 약속이 무엇인가**를 말한다.
                  // 프로필 열 세 번째 줄에 가장 흐린 색으로 두었더니 회원의
                  // 부가 정보처럼 읽혔다 — 정작 하루를 훑을 때는 "몇 분짜리 무슨
                  // 수업인가" 로 앞뒤 일정을 가늠한다(#938). 비어 있던 오른쪽
                  // 여백으로 옮겨 상태 칩 옆에 세운다.
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: SessionTypeChip(
                        label: l.sessionTypeAndDuration(
                          sessionTypeLabel(l, s.type),
                          s.durationMinutes,
                        ),
                        muted: s.isDone,
                      ),
                    ),
                  ),
                  SessionStatusChip(status: s.status),
                  if (s.expandable) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.disabledForeground,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Divider(height: 1, color: AppColors.borderStrong),
                  const SizedBox(height: AppSpacing.md),
                  if (inlineEditor != null)
                    inlineEditor!
                  else ...<Widget>[
                    if (s.program.isNotEmpty)
                      for (var i = 0; i < s.program.length; i++) ...<Widget>[
                        SessionProgramRow(index: i + 1, item: s.program[i]),
                        const SizedBox(height: AppSpacing.sm),
                      ]
                    else if (s.isUpcoming) ...<Widget>[
                      // 예정 session without a plan yet.
                      const SessionNoPlanBox(),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (s.note.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      SessionNoteBox(note: s.note),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    // 취소는 삭제와 달리 기록이라, 그 기록을 볼 수 있어야
                    // 만든 의미가 있다(#871).
                    if (s.isCancelled || s.isNoShow) ...<Widget>[
                      SessionEndedBox(session: s),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    SessionManageRow(
                      onEditSchedule: onEditSchedule,
                      onEditProgram: onEditProgram,
                      onDelete: onDelete,
                      onCancel: onCancel,
                      onNoShow: onNoShow,
                      onChat: onChat,
                      onComplete: onComplete,
                    ),
                    if (s.isDone && s.program.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _SendButton(
                        clientName: s.clientName,
                        dateLabel: programDateLabel,
                        sent: s.programSent,
                        sending: sendingProgram,
                        onSend: (s.programSent || sendingProgram)
                            ? null
                            : onSendProgram,
                      ),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.clientName,
    required this.dateLabel,
    required this.sent,
    required this.sending,
    required this.onSend,
  });

  final String clientName;
  final String dateLabel;

  /// 이미 보낸 세션인가. 보낸 뒤에는 같은 자리에서 그 사실을 말한다 — 다시
  /// 누를 수 있게 두면 트레이너가 두 번 보냈는지 알 수 없다.
  final bool sent;

  /// 전송이 진행 중인가.
  final bool sending;

  /// 보내기. 이미 보냈거나 진행 중이면 null 이다.
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color foreground = sent
        ? AppColors.success
        : (sending ? AppColors.disabledForeground : AppColors.primary);
    return Material(
      color: AppColors.inputBackground,
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: InkWell(
        key: const ValueKey<String>('schedule-send-program'),
        onTap: onSend,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (sending)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  sent ? Icons.check_circle_outline : Icons.send_outlined,
                  size: 15,
                  color: foreground,
                ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  sent
                      ? l.schedSentTo(clientName)
                      : l.schedSentProgramTo(clientName, dateLabel),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: foreground,
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
