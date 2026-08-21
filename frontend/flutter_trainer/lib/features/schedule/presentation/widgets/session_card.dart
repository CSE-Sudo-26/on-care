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
    // 상담은 운동 프로그램을 짜는 자리가 아니다 — 무슨 이야기를 나눴는지를 적는
    // 자리다. 그래서 프로그램 목록도, "아직 계획된 프로그램이 없어요" 안내도,
    // 회원에게 보내는 버튼도 두지 않는다. 남는 것은 메모뿐이다(#988).
    final noteOnly = s.type == SessionType.consultation;
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
              // 머리글은 두 줄이다. 카드가 폭 340 짜리 상세 패널에 살게 되면서
              // (#988) 시각·아바타·이름·목표·칩 둘·화살표를 한 줄에 세우면
              // 이름이 `김…`, 목표가 `혈압 관리 …` 로 잘렸다. 잘린 이름은
              // 누구인지 말하지 못하므로, 칩을 아랫줄로 내려 이름에 폭을 준다.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 시각은 일 보기 타임라인의 왼쪽 홈통이 그리던 값이다.
                      // 보기가 시간표 하나로 모이면서 그 홈통이 사라졌으므로,
                      // 카드가 직접 말한다 — 상세 패널에서 "몇 시 약속인가" 가
                      // 빠지면 카드만 보고는 알 수 없다(#988).
                      SizedBox(
                        width: 46,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.foreground,
                                ),
                              )
                            else ...<Widget>[
                              // 이름과 성별·나이를 세로로 쌓는다. 한 줄에
                              // 나란히 두면 좁은 패널에서 이름이 먼저 잘린다.
                              ClientIdentity(
                                client: client,
                                stacked: true,
                                maxLines: 2,
                                nameStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.foreground,
                                ),
                              ),
                              // 오늘 만날 회원이 무엇을 목표로 하는 사람인지는
                              // 세션 종류·소요 시간만큼 자리에서 필요하다(#898).
                              const SizedBox(height: 2),
                              ClientGoalLabel(client: client),
                            ],
                          ],
                        ),
                      ),
                      if (s.expandable) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.disabledForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // 세션 종류·소요 시간은 **이 약속이 무엇인가**를 말한다.
                  // 프로필 열 세 번째 줄에 가장 흐린 색으로 두었더니 회원의
                  // 부가 정보처럼 읽혔다(#938). 그래서 흐린 글씨가 아니라
                  // 상태 칩과 나란한 알약으로 둔다 — 자리는 아랫줄이지만
                  // 위계는 상태와 같다.
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 46 + 32 + AppSpacing.md,
                    ),
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        SessionTypeChip(
                          label: l.sessionTypeAndDuration(
                            sessionTypeLabel(l, s.type),
                            s.durationMinutes,
                          ),
                          muted: s.isDone,
                          // 시간표 블록과 같은 표현을 쓴다 — 상담은 비운다(#1013).
                          outlined: noteOnly,
                        ),
                        SessionStatusChip(status: s.status),
                      ],
                    ),
                  ),
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
                    if (!noteOnly)
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
                    ] else if (noteOnly) ...<Widget>[
                      const SessionNoNoteBox(),
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
                      noteOnly: noteOnly,
                      onDelete: onDelete,
                      onCancel: onCancel,
                      onNoShow: onNoShow,
                      onChat: onChat,
                      onComplete: onComplete,
                    ),
                    if (!noteOnly &&
                        s.isDone &&
                        s.program.isNotEmpty) ...<Widget>[
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
