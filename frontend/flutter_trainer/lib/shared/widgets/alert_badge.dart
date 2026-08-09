import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// The colour that carries [alert]'s meaning.
///
/// 하나의 색은 하나의 뜻만: 남색 = 처리 필요, 빨강 = 목표 초과 (사용자 앱과
/// 동일), 주황 = 완만한 주의. 답장 대기의 시급함은 색이 아니라 목록 맨 위에
/// 오는 순서가 말한다.
Color alertColor(ClientAlert alert) => switch (alert) {
  ClientAlert.unanswered => AppColors.primary,
  ClientAlert.sodiumOver => AppColors.overTarget,
  ClientAlert.lowCompletion => AppColors.warning,
};

/// A pill naming why a client is flagged.
///
/// Shared so the 대시보드 row and the client detail header can never
/// disagree about an alert's colour — the switch above used to be copied
/// into both, comment and all.
class AlertBadge extends StatelessWidget {
  /// Creates a badge for [alert].
  const AlertBadge({super.key, required this.alert, this.showIcon = true});

  /// The reason being shown.
  final ClientAlert alert;

  /// Whether to lead with the warning glyph. The dashboard row sits in a
  /// card already titled 확인 필요 고객, so it drops the icon; the detail
  /// header has no such framing and keeps it.
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final color = alertColor(alert);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showIcon ? 9 : 7,
        vertical: showIcon ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIcon) ...<Widget>[
            Icon(Icons.error_outline, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            alert.label(AppLocalizations.of(context)),
            style: TextStyle(
              fontSize: showIcon ? 11 : 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
