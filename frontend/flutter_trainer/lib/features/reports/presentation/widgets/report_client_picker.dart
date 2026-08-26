import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 주간 리포트를 볼 고객을 고르는 왼쪽 목록.
class ReportClientPicker extends StatefulWidget {
  const ReportClientPicker({
    super.key,
    required this.clients,
    required this.selectedId,
    required this.onSelect,
  });

  final List<TrainerClient> clients;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<ReportClientPicker> createState() => _ReportClientPickerState();
}

class _ReportClientPickerState extends State<ReportClientPicker> {
  /// 목록과 스크롤바가 같은 위치를 가리키도록 컨트롤러를 공유한다.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final clients = widget.clients;
    final selectedId = widget.selectedId;
    final onSelect = widget.onSelect;
    final double rowHeight = clientListRowHeight(context);
    return SectionCard(
      title: l.navClients,
      icon: Icons.people_outline,
      dense: true,
      child: SizedBox(
        height: rowHeight * clientListVisibleRows,
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: clients.length > clientListVisibleRows,
          child: ListView.builder(
            key: const ValueKey<String>('report-client-list-scroll'),
            controller: _scroll,
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            itemCount: clients.length,
            itemExtent: rowHeight,
            itemBuilder: (context, index) {
              final client = clients[index];
              final selected = client.id == selectedId;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Material(
                  key: ValueKey<String>('report-client-${client.id}'),
                  color: selected
                      ? AppColors.accentSurface
                      : Colors.transparent,
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  child: InkWell(
                    onTap: () => onSelect(client.id),
                    borderRadius: const BorderRadius.all(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          // 아바타 크기는 프로그램 탭 고객 목록과 같은
                          // 기준을 쓴다(#1423).
                          ClientAvatar(
                            label: client.avatar,
                            size: clientListAvatarSize,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // 프로그램 탭 고객 목록과 같은 기준이다(#1423).
                                ClientIdentity(
                                  client: client,
                                  nameStyle: clientListNameStyle(
                                    selected: selected,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // 어느 고객의 리포트를 열지 고르는 자리다 —
                                // 이름만으로는 고를 근거가 되지 않는다(#898).
                                ClientGoalLabel(
                                  client: client,
                                  fontSize: clientListGoalFontSize,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
