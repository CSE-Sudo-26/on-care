import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/consultation_request_card.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 내 상담 요청 전체 내역(#948). 운동 탭은 대기 중이거나 가장 최근 요청 1건만
/// 요약해 보여준다 — 요청이 누적될수록 과거 이력을 확인할 곳이 없었다. 이
/// 화면은 그 전체 이력을 진행 중/지난 요청으로 나눠 보여준다.
///
/// `consultationRequestControllerProvider` 가 이미 `GET /consultations/me`
/// 전체를 들고 있어 별도 API 호출이 필요 없다.
class ConsultationHistoryPage extends ConsumerWidget {
  const ConsultationHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<ConsultationRequest> requests = ref.watch(
      consultationRequestControllerProvider,
    );
    final List<ConsultationRequest> inProgress = requests
        .where(
          (ConsultationRequest r) => r.status == ConsultationStatus.pending,
        )
        .toList(growable: false);
    // 서버가 이미 최신순으로 준다(#948) — 다시 정렬하지 않는다.
    final List<ConsultationRequest> past = requests
        .where(
          (ConsultationRequest r) => r.status != ConsultationStatus.pending,
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          l.exConsultHistoryTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: requests.isEmpty
            ? _EmptyState(message: l.exConsultHistoryEmpty)
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: <Widget>[
                      if (inProgress.isNotEmpty) ...<Widget>[
                        _SectionLabel(text: l.exConsultHistoryInProgress),
                        const SizedBox(height: 10),
                        for (final ConsultationRequest r
                            in inProgress) ...<Widget>[
                          ConsultationRequestCard(
                            key: ValueKey<String>('consult-history-${r.id}'),
                            request: r,
                            onCancel: () async {
                              final bool? confirmed = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext dialogContext) => AlertDialog(
                                  title: const Text('상담 요청을 취소할까요?'),
                                  content: const Text('취소한 요청은 다시 되돌릴 수 없어요.'),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext, false),
                                      child: const Text('유지'),
                                    ),
                                    // 되돌릴 수 없는 쪽이다 — 카드의 취소
                                    // 버튼과 같은 파괴적 색 토큰을 쓴다.
                                    // 유지와 취소가 같은 색이면 두 동작의
                                    // 위험도 차이가 보이지 않는다(#1429).
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.destructive,
                                      ),
                                      child: Text(l.actionCancel),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await ref
                                    .read(consultationRequestControllerProvider.notifier)
                                    .cancel(r.id);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                      // `지난 요청` 소제목은 두지 않는다(#1429). 완료·취소는
                      // 카드가 상태로 말하고 있어, 소제목은 같은 목록을 한 겹
                      // 더 나누기만 했다. 진행 중 묶음과 같은 간격으로 이어
                      // 붙어 카드 흐름이 끊기지 않는다.
                      if (past.isNotEmpty) ...<Widget>[
                        for (final ConsultationRequest r in past) ...<Widget>[
                          ConsultationRequestCard(
                            key: ValueKey<String>('consult-history-${r.id}'),
                            request: r,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.mutedForeground,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.inbox_outlined,
              size: 34,
              color: FigmaColors.textFaint,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.foreground),
            ),
          ],
        ),
      ),
    );
  }
}
