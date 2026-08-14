import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// A compact labelled bar series (주간 이행률, 세션 수 …).
///
/// Deliberately hand-built rather than pulled from a charting package:
/// the console needs exactly one chart shape here, trivial, and a chart
/// library would add build weight and its own theming surface for no
/// gain. If a real analytics screen ever needs
/// axes, tooltips and zoom, that's the moment to add one.
class BarSeriesChart extends StatelessWidget {
  /// Creates a bar series.
  const BarSeriesChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 96,
    this.maxValue,
    this.highlightIndex,
    this.overThreshold,
    this.valueSuffix = '',
    this.showValues = false,
    this.pendingFromIndex,
    this.missingIndices = const <int>{},
  }) : assert(values.length == labels.length, 'values/labels 길이가 달라요');

  /// Bar values (non-negative).
  final List<int> values;

  /// X-axis labels, one per value.
  final List<String> labels;

  /// Plot height (excluding labels).
  final double height;

  /// Scale ceiling. Defaults to the largest value (min 1).
  final int? maxValue;

  /// Bar rendered in the strong primary fill (e.g. 오늘).
  final int? highlightIndex;

  /// Values strictly above this render in the warning colour.
  final int? overThreshold;

  /// Appended to the value label when [showValues] is on.
  final String valueSuffix;

  /// Whether to print the value above each bar.
  final bool showValues;

  /// First index that hasn't happened yet (e.g. tomorrow, in a Mon–Sun
  /// chart shown on Thursday). Those bars render as an empty track with
  /// no value, so a day with no data yet can't be misread as a zero.
  final int? pendingFromIndex;

  /// Indices whose value is unavailable rather than zero.
  ///
  /// The empty track and a `-` value keep missing comparison data from being
  /// misread as a measured zero.
  final Set<int> missingIndices;

  @override
  Widget build(BuildContext context) {
    final pendingFrom = pendingFromIndex ?? values.length;
    final ceiling = <int>[
      maxValue ?? 0,
      if (values.isNotEmpty) values.reduce((a, b) => a > b ? a : b),
      1,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: _Bar(
                      value: values[i],
                      ceiling: ceiling,
                      color: _colorFor(i),
                      label: showValues
                          ? missingIndices.contains(i)
                                ? '-'
                                : '${values[i]}$valueSuffix'
                          : null,
                      pending: i >= pendingFrom,
                      missing: missingIndices.contains(i),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: highlightIndex == i
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: highlightIndex == i
                        ? AppColors.primary
                        : i >= pendingFrom
                        ? AppColors.disabledForeground
                        : AppColors.subtleForeground,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _colorFor(int index) {
    if (overThreshold != null && values[index] > overThreshold!) {
      return AppColors.overTarget;
    }
    if (highlightIndex == index) return AppColors.primary;
    return AppColors.aiCardGradientEnd;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.ceiling,
    required this.color,
    required this.label,
    this.pending = false,
    this.missing = false,
  });

  final int value;
  final int ceiling;
  final Color color;
  final String? label;

  /// The day hasn't happened yet: draw the empty track only.
  ///
  /// Distinct from `value == 0`, which is a real "recorded, nothing done"
  /// and keeps its 2px stub — and from the value's own colour, which for
  /// a future day would otherwise paint the track red on a series with an
  /// `overThreshold`.
  final bool pending;

  /// No measurement exists for this bar.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    // A zero value still draws a 2px stub so the day reads as "recorded,
    // nothing done" rather than "no data".
    final ratio = pending || missing ? 0.0 : (value / ceiling).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelHeight = label == null || pending ? 0.0 : 14.0;
        final plot = (constraints.maxHeight - labelHeight).clamp(
          0.0,
          constraints.maxHeight,
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (label != null && !pending)
              SizedBox(
                height: labelHeight,
                child: FittedBox(
                  child: Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            Container(
              height: (plot * ratio).clamp(2.0, plot),
              decoration: BoxDecoration(
                color: pending || missing ? AppColors.border : color,
                borderRadius: const BorderRadius.vertical(top: AppRadius.xs),
              ),
            ),
          ],
        );
      },
    );
  }
}
