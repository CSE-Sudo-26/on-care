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
  /// 한 줄 높이. 이름·나이와 목표 두 줄이다.
  ///
  /// 주간 이행률 막대가 한 줄 더 붙어 있던 때에는 92 였다(#1097). 그 막대는
  /// 오른쪽 리포트가 같은 값을 훨씬 자세히 말하고 있어 목록에서는 뺐다(#1177).
  static const double _rowHeight = 64;

  /// 한 번에 보여 줄 줄 수. 나머지는 스크롤한다.
  ///
  /// 줄이 낮아진 만큼 더 보여 준다 — 열 높이는 그대로 두고 한눈에 담기는
  /// 고객만 다섯에서 일곱으로 늘어난다(#1177).
  static const int _visibleRows = 7;

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
      // 일곱 명까지만 보여 주고 나머지는 스크롤한다. 로스터가 열다섯 명이면
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
                          // 아바타 크기는 프로그램 탭 고객 목록과 같은
                          // 기준을 쓴다(#1423).
                          ClientAvatar(
                            label: client.avatar,
                            size: clientListAvatarSize,
                          ),
                          const SizedBox(width: AppSpacing.md),
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
