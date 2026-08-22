import 'package:flutter/material.dart';

import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 펼쳐 보는 하루치 기록 한 줄. (#1025)
///
/// 그래프는 "얼마나" 를 말하지만 "그날 무엇을" 은 말하지 않는다. 그렇다고
/// 날마다 카드를 펼쳐 두면 전체(12주)에서 스크롤이 끝없이 길어진다. 접힌
/// 상태에서는 날짜와 한 줄 요약만 두고, 누른 날만 펼친다.
///
/// 식단과 운동이 같은 줄을 쓴다 — 같은 자리에서 같은 동작을 하는데 생김새가
/// 다르면 트레이너가 매번 다시 배운다.
class ClientDayRecordTile extends StatelessWidget {
  /// Creates one day's row.
  const ClientDayRecordTile({
    super.key,
    required this.date,
    required this.logged,
    required this.summary,
    required this.details,
    required this.expanded,
    required this.onToggle,
    this.emptyLabel,
  });

  /// 이 줄이 말하는 날.
  final DateTime date;

  /// 기록이 있는 날인가. 없으면 펼칠 것이 없어 접힌 채로 둔다 — 0 으로 채운
  /// 상세를 펼쳐 보이면 "쉰 날" 이 "0을 기록한 날" 로 읽힌다.
  final bool logged;

  /// 접힌 줄에 적는 한 줄 요약.
  final String summary;

  /// 펼쳤을 때 보여 줄 항목들.
  final List<({String label, String value})> details;

  /// 지금 펼쳐져 있는가.
  final bool expanded;

  /// 줄을 눌렀을 때. 기록이 없는 날은 [logged] 가 false 라 눌리지 않는다.
  final VoidCallback onToggle;

  /// 기록이 없을 때 요약 자리에 적을 말.
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: ValueKey<String>('client-day-tile-${ymd(date)}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            button: logged,
            expanded: logged ? expanded : null,
            child: InkWell(
              onTap: logged ? onToggle : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 88,
                      child: Text(
                        dateLabel(l, date),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: logged
                              ? AppColors.foreground
                              : AppColors.disabledForeground,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        logged ? summary : (emptyLabel ?? ''),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: logged
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: logged
                              ? AppColors.mutedForeground
                              : AppColors.disabledForeground,
                        ),
                      ),
                    ),
                    // 펼칠 것이 없는 날에는 화살표도 없다 — 눌러도 아무 일이
                    // 없는 표시를 두지 않는다.
                    if (logged)
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: const Icon(
                          Icons.expand_more,
                          size: 20,
                          color: AppColors.subtleForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (logged && expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Divider(height: 1, color: AppColors.borderStrong),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ({String label, String value}) row in details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 88,
                            child: Text(
                              row.label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.subtleForeground,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              row.value,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
