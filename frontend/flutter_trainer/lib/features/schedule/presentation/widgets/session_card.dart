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

/// 상세 패널의 세션 한 건 — 시간·상태·누구인가와 그날 할 일.
///
/// 완료된 세션은 프로그램과 메모를 보여 주고 고객에게 보낼 수 있다. 예정된
/// 세션은 계획(없으면 [SessionNoPlanBox])과 수정·삭제·채팅 동선을 연다.
/// 취소·노쇼로 끝난 세션은 [SessionEndedBox] 로 그 기록을 남긴다.
///
/// 카드는 **늘 펼친 상태**다(#1012). 접었다 펴는 손잡이가 머리글에 있었지만,
/// 이 카드가 서는 자리는 이미 한 세션만 골라 보여 주는 상세 패널이라 접을
/// 것이 없었다 — 눌러도 아무 일도 일어나지 않는 화살표였다.
class SessionCard extends ConsumerWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onEditNote,
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
  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;

  /// 운동 목록 없이 메모만 여는 자리. 세션 종류와 상관없이 있다(#1011).
  final VoidCallback onEditNote;

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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            // 머리글은 **무엇이 어떻게 됐나 → 누구인가** 순서다. (#1012)
            //
            //   [완료]  12:00–12:50 (50분)
            //   [프로필]  이지수  여성 · 32세          [1:1 PT]
            //             체지방 감량
            //
            // 첫 줄은 약속에 관한 값만 담는다. 아바타를 그 줄에 세우면 사람이
            // 먼저 눈에 들어와, 상태·시각을 먼저 찾는 훑기와 어긋난다.
            // 소요 시간은 시각 옆 괄호에 둔다 — 종류와 묶어 `1:1 PT · 50분`
            // 으로 두었더니 서로 다른 두 값이 한 덩어리로 읽혔다.
            //
            // 종류 알약은 둘째 줄 오른쪽 끝이다. 시각 옆에 두었을 때는 그
            // 줄이 세 값으로 빽빽한데 프로필 줄 오른쪽은 통째로 비어 있었다.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SessionStatusChip(status: s.status),
                    const SizedBox(width: AppSpacing.xs),
                    // 시각은 잘리면 안 되는 값이라 글자를 자르는 대신 통째로
                    // 작게 그린다 — 폭 340 패널에 큰 글자 배율이 겹치면 이
                    // 줄이 먼저 넘친다.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          // 소요 시간(`(50분)`)은 적지 않는다 — 시작·끝 시각이
                          // 이미 그 값을 말하고 있어, 옆에 다시 적으면 같은
                          // 사실을 두 번 읽게 된다.
                          _timeRange(l, s),
                          maxLines: 1,
                          style: TextStyle(
                            // 시각은 이 카드에서 가장 먼저 읽는 값이다 —
                            // 상태 칩(10.5)과 같은 크기로 두었더니 어느
                            // 것이 제목인지 알 수 없었다(#1012).
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: s.isFinished
                                ? AppColors.disabledForeground
                                : AppColors.foreground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  // 프로필(아바타)과 이름을 세로 가운데로 맞춘다 — 전에는
                  // `start` 로 둬서 아바타가 이름보다 커서 이름 줄이 위로
                  // 붙어 보였다. `Row` 의 기본값이 가운데라 값을 명시하지
                  // 않는다.
                  children: <Widget>[
                    ClientAvatar(
                      // Guard: a non-gap row with an empty name must not
                      // crash `.characters.first`.
                      label: s.clientName.isEmpty
                          ? '?'
                          : s.clientName.characters.first,
                      size: 34,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (client == null)
                            // 로스터에 없는 고객(상담으로 잡힌 가망 고객)은
                            // 이름만 부른다. 뒤에 `(신규)` 를 달아 두었더니
                            // 네 글자 이름이 그 표에 밀려 잘렸다 — 신규라는
                            // 사실은 종류 알약(`상담`)이 이미 말한다(#1012).
                            Text(
                              s.clientName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                            // 세션 종류만큼 자리에서 필요하다(#898).
                            ClientGoalLabel(client: client),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // 종류는 흐린 글씨가 아니라 알약으로 둔다 — 회원의 부가
                    // 정보가 아니라 이 약속이 무엇인가를 말하는 값이다(#938).
                    // 상태는 첫 줄의 SessionStatusChip 이 이미 말하므로 여기서
                    // 되풀이하지 않는다. 소요 시간도 위 시각 줄이 이미 말해
                    // 다시 붙이지 않는다(#1012).
                    SessionTypeChip(
                      label: sessionTypeLabel(l, s.type),
                      muted: s.isDone,
                      prominent: true,
                      // 시간표 블록과 같은 표현 — 상담은 비운다(#1013).
                      outlined: noteOnly,
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                    SessionNoNoteBox(onAdd: onEditNote),
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
                    onEditNote: onEditNote,
                    hasNote: s.note.trim().isNotEmpty,
                    hasProgram: !noteOnly,
                    // 상담이면서 아직 메모가 없으면 `메모 추가` 는 위
                    // `SessionNoNoteBox` 안으로 옮겨 갔다(#1012).
                    showEditNote: !(noteOnly && s.note.trim().isEmpty),
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

/// `12:00–12:50` — 시작과 끝. 시각은 자르지 않는다(#1012).
///
/// `12–12:50` 으로 줄였더니 그 자리가 무엇을 가리키는지 한 번 더 생각해야
/// 했다. 시간표 블록과 같은 규칙이다.
String _timeRange(AppLocalizations l, ScheduleSession session) {
  final start = clockMinutes(session.time);
  if (start == null) return session.time;
  return l.schedTimeRange(session.time, _hhmm(start + session.durationMinutes));
}

/// 자정부터의 분을 `HH:mm` 으로.
String _hhmm(int minutes) {
  final wrapped = minutes % (24 * 60);
  final hour = (wrapped ~/ 60).toString().padLeft(2, '0');
  final minute = (wrapped % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
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
    // 배경이 그대로 회색이면 보냈는지 아닌지가 글씨에만 남는다. 보내기 전에는
    // 연한 남색, 보낸 뒤에는 연한 초록 — 상태 칩과 같은 색 규칙이다(#1012).
    return Material(
      color: sent
          ? AppColors.success.withValues(alpha: 0.12)
          : (sending
                ? AppColors.inputBackground
                : AppColors.primary.withValues(alpha: 0.10)),
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
