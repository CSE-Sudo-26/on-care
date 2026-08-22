import 'package:flutter/material.dart';

import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 날짜별 기록을 담는 판. (#1025)
///
/// 옆에 놓이는 그래프 카드(`client-exercise-status-card` 등)와 **같은 규격**
/// 이다 — 흰 판 하나에 `AppSpacing.md` 안쪽 여백, 머리카락 테두리, 같은 그림자.
///
/// 날마다 카드를 세우지 않는다. 12주면 판이 여든 개 겹쳐 서서, 그래프 카드
/// 하나와 나란히 놓으면 이 목록만 화면을 다 먹는다. 판은 하나고 그 안에서
/// 날짜를 줄로 나눈다.
class ClientDayRecordCard extends StatelessWidget {
  /// Creates the card holding [children] day rows.
  const ClientDayRecordCard({super.key, required this.children});

  /// [ClientDayRecordTile] 들.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
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
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              // 줄 사이의 실선. 날짜 칸 아래는 비워 두어 왼쪽 열이 하나로
              // 이어져 보이게 한다.
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.md),
                child: Divider(height: 1, color: AppColors.border),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 펼쳐 보는 하루치 기록 한 줄. (#1025)
///
/// 그래프는 "얼마나" 를 말하지만 "그날 무엇을" 은 말하지 않는다. 그렇다고
/// 날마다 펼쳐 두면 전체(12주)에서 스크롤이 끝없이 길어진다. 접힌 줄에는
/// 날짜와 한 줄 요약만 두고, 누른 날만 펼친다.
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
    this.extra,
  });

  /// 이 줄이 말하는 날.
  final DateTime date;

  /// 기록이 있는 날인가. 없으면 펼칠 것이 없어 접힌 채로 둔다 — 0 으로 채운
  /// 상세를 펼쳐 보이면 "쉰 날" 이 "0을 기록한 날" 로 읽힌다.
  final bool logged;

  /// 접힌 줄 오른쪽에 적는 한 줄 요약.
  final String summary;

  /// 펼쳤을 때 보여 줄 항목들. 이름표를 단 알약으로 늘어놓는다.
  final List<({String label, String value})> details;

  /// 지금 펼쳐져 있는가.
  final bool expanded;

  /// 줄을 눌렀을 때. 기록이 없는 날은 [logged] 가 false 라 눌리지 않는다.
  final VoidCallback onToggle;

  /// 기록이 없을 때 요약 자리에 적을 말.
  final String? emptyLabel;

  /// 펼쳤을 때 [details] 아래에 덧붙일 것. 식단은 여기에 끼니를 늘어놓는다.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      key: ValueKey<String>('client-day-tile-${ymd(date)}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: logged,
          expanded: logged ? expanded : null,
          child: InkWell(
            onTap: logged ? onToggle : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: <Widget>[
                  // 날짜 칸의 폭을 고정해 줄들이 왼쪽에서 가지런히 선다.
                  // 글씨를 키우면 줄임표 대신 줄어든다 — 카드 제목이 쓰는
                  // 방식과 같다(#1004).
                  //
                  // `오늘`·`어제` 는 붙이지 않는다. 접두어가 붙은 줄만 글자가
                  // 길어져 칸 안에서 더 줄어들고, 그 두 줄만 날짜가 작게
                  // 보였다. 어차피 목록이 최근 날부터 내려가므로 맨 위가
                  // 오늘이라는 것은 순서가 말한다.
                  SizedBox(
                    width: 104,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l.dateMonthDayWeekday(
                          date.month,
                          date.day,
                          weekdayNames(l)[date.weekday - 1],
                        ),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: logged
                              ? AppColors.foreground
                              : AppColors.disabledForeground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // 요약은 오른쪽 끝에 붙는다 — 숫자끼리 한 줄에 서야 날짜를
                  // 훑으며 견줄 수 있다.
                  Expanded(
                    child: Text(
                      logged ? summary : (emptyLabel ?? ''),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: logged ? FontWeight.w600 : FontWeight.w500,
                        color: logged
                            ? AppColors.mutedForeground
                            : AppColors.disabledForeground,
                      ),
                    ),
                  ),
                  // 펼칠 것이 없는 날에도 자리는 남긴다 — 화살표만 빠지면
                  // 그 줄의 요약이 오른쪽으로 밀려 열이 어긋난다.
                  SizedBox(
                    width: 24,
                    child: logged
                        ? AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 160),
                            child: const Icon(
                              Icons.expand_more,
                              size: 20,
                              color: AppColors.subtleForeground,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (logged && expanded)
          Container(
            width: double.infinity,
            // 펼친 속은 옅은 남색 판 위에 둔다. 접힌 줄들과 바탕이 갈려야
            // 어디까지가 펼친 하루인지 눈으로 잡힌다.
            color: AppColors.accentSurface.withValues(alpha: 0.45),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (details.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final ({String label, String value}) row in details)
                        _DetailPill(label: row.label, value: row.value),
                    ],
                  ),
                ?extra,
              ],
            ),
          ),
      ],
    );
  }
}

/// 펼친 하루의 항목 하나 — `칼로리 1,820 kcal` 처럼 이름표와 값을 한 알약에.
///
/// 두 열짜리 표를 쓰지 않는다. 항목 수가 날마다 다른데(탄단지가 없는 날,
/// 유형이 하나뿐인 날) 표로 두면 빈 칸이 남아 화면이 성글어 보인다.
class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.pill),
      border: Border.all(color: AppColors.borderStrong),
    ),
    child: Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.subtleForeground,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    ),
  );
}
