import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';
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
  /// 한 줄 높이. 신원·목표 아래에 주간 이행률 막대가 한 줄 더 붙는다(#1097).
  static const double _rowHeight = 92;

  /// 한 번에 보여 줄 줄 수. 나머지는 스크롤한다.
  static const int _visibleRows = 5;

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
    return SectionCard(
      title: l.navClients,
      icon: Icons.people_outline,
      dense: true,
      // 다섯 명까지만 보여 주고 나머지는 스크롤한다. 로스터가 열다섯 명이면
      // 카드가 화면 높이를 다 먹어 오른쪽 리포트와 나란히 읽기 어려웠다.
      child: SizedBox(
        height: _rowHeight * _visibleRows,
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            itemCount: clients.length,
            itemExtent: _rowHeight,
            itemBuilder: (context, index) {
              final client = clients[index];
              final selected = client.id == selectedId;
              return Padding(
                key: ValueKey<String>('report-client-${client.id}'),
                padding: const EdgeInsets.only(bottom: 3),
                child: Material(
                  color: selected
                      ? AppColors.accentSurface
                      : Colors.transparent,
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  child: InkWell(
                    onTap: () => onSelect(client.id),
                    borderRadius: const BorderRadius.all(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Row(
                        children: <Widget>[
                          ClientAvatar(label: client.avatar, size: 38),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                ClientIdentity(
                                  client: client,
                                  nameStyle: TextStyle(
                                    fontSize: 15,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: AppColors.foreground,
                                  ),
                                ),
                                // 어느 고객의 리포트를 열지 고르는 자리다 —
                                // 이름만으로는 고를 근거가 되지 않는다(#898).
                                ClientGoalLabel(client: client, fontSize: 11),
                                const SizedBox(height: AppSpacing.xs),
                                Builder(
                                  builder: (context) {
                                    final mean = recordedCompletionMean(client);
                                    // API 경계에서 잘못된 값이 와도 막대와
                                    // 숫자는 이행률의 범위(0~100%)를 벗어나지
                                    // 않게 한다. 기록이 없으면 0%로 바꾸지 않는다.
                                    final value = mean?.clamp(0.0, 100.0);
                                    return InlineBarValue(
                                      key: ValueKey<String>(
                                        'report-client-completion-${client.id}',
                                      ),
                                      label: l.reportsWeeklyCompletion,
                                      labelWidth: 58,
                                      fraction: value == null
                                          ? null
                                          : value / 100,
                                      text: value == null
                                          ? l.reportsDataInsufficient
                                          : '${value.round()}%',
                                      valueWidth: value == null ? 60 : 40,
                                    );
                                  },
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
