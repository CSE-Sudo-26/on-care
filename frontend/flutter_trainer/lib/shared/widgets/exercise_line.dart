import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// 기록된 운동 한 줄 — 이름과 수행 여부.
///
/// 저장된 문자열은 끝에 '✓' / '✗' 로 결과를 표시한다. 그 글자는 **저장 규칙**
/// 이지 화면에 찍을 것이 아니다: Flutter web 의 폰트 스택에 글리프가 없어
/// 두부 상자로 그려진다. 표시를 읽어 아이콘과 취소선으로 바꿔 그린다.
///
/// 운동 기록 탭과 리포트의 요일별 내역이 **같은 규칙**을 써야 하므로 여기
/// 하나만 둔다 — 복사하면 한쪽만 고쳐져 갈라진다.
class ExerciseLine extends StatelessWidget {
  /// Creates a line.
  const ExerciseLine({
    super.key,
    required this.line,
    this.fontSize = 12.5,
    this.maxLines,
  });

  /// 저장된 문자열. 끝의 '✓'/'✗' 가 수행 여부를 나타낸다.
  final String line;

  /// 이름 글자 크기. 리포트의 요일별 내역은 조금 작게 쓴다.
  final double fontSize;

  /// 이름을 몇 줄까지 접을지. 좁은 요일 칸에서는 두 줄로 제한한다.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final skipped = line.contains('✗');
    final text = line.replaceAll(RegExp(r'\s*[✓✗]\s*'), ' ').trim();
    final color = skipped
        ? AppColors.disabledForeground
        : AppColors.mutedForeground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 아이콘을 **첫 줄 높이에 맞춰** 가운데 둔다. 위쪽에 고정하면
          // 한글 글자의 시각적 중심보다 높이 떠 보인다.
          SizedBox(
            height: fontSize * 1.45,
            child: Center(
              child: Icon(
                skipped ? Icons.close : Icons.check,
                size: fontSize - 0.5,
                color: skipped
                    ? AppColors.disabledForeground
                    : AppColors.success,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: color,
                decoration: skipped ? TextDecoration.lineThrough : null,
                decorationColor: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
