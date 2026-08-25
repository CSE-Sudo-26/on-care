import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';

/// 숫자 한 칸 — 직접 입력하는 텍스트 필드와 양옆의 −/+ 버튼.
///
/// 예전에는 시간·세트를 슬라이더로 받았다. 슬라이더는 "대충 이쯤" 을 고르기엔
/// 좋지만 회원이 아는 값(45분·12세트·62.5kg)을 그대로 넣기에는 나쁘다 — 손가락
/// 하나로 한 칸을 맞추려 몇 번을 문지르게 된다. 여기서는 값을 직접 적고, 한 칸씩
/// 고칠 때만 버튼을 쓴다. (#1276)
///
/// [step] 이 정수가 아니면(중량 0.1) 소수 입력을 허용하고 [decimals] 자리까지
/// 반올림한다.
class AppNumberStepper extends StatefulWidget {
  const AppNumberStepper({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.step = 1,
    this.decimals = 0,
    this.suffix,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;

  /// 소수점 자릿수. 0 이면 정수로 읽고 쓴다.
  final int decimals;

  /// 필드 오른쪽에 붙는 단위 문구("분", "세트", "kg").
  final String? suffix;

  @override
  State<AppNumberStepper> createState() => _AppNumberStepperState();
}

class _AppNumberStepperState extends State<AppNumberStepper> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // 포커스를 잃을 때 비워 둔 칸이나 범위 밖 값을 되돌린다. 타이핑 도중에
    // 고치면 "1" 을 지나 "12" 로 가는 길이 막힌다.
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit(_controller.text);
    });
  }

  @override
  void didUpdateWidget(AppNumberStepper old) {
    super.didUpdateWidget(old);
    // 밖에서 값이 바뀐 경우(유형 전환 등)만 필드를 다시 그린다 — 편집 중인
    // 문자열을 덮어쓰면 커서가 튄다.
    if (widget.value != old.value && !_focus.hasFocus) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _format(double v) =>
      widget.decimals == 0 ? v.round().toString() : v.toStringAsFixed(widget.decimals);

  double _clamp(double v) => v.clamp(widget.min, widget.max);

  /// 적히는 대로 값을 올린다. **필드의 글자는 건드리지 않는다** — 타이핑 중에
  /// 고쳐 쓰면 "4" 를 지나 "47" 로 가는 길이 막히고 커서가 튄다. 정리는 포커스를
  /// 잃을 때 [_commit] 이 한다.
  void _typed(String raw) {
    final double? parsed = double.tryParse(raw.trim());
    if (parsed != null) widget.onChanged(_round(_clamp(parsed)));
  }

  /// 비워 둔 칸이나 범위 밖 값을 되돌리고 글자를 다시 그린다.
  void _commit(String raw) {
    final double next = _round(_clamp(double.tryParse(raw.trim()) ?? widget.value));
    _controller.text = _format(next);
    widget.onChanged(next);
  }

  double _round(double v) => widget.decimals == 0
      ? v.roundToDouble()
      : double.parse(v.toStringAsFixed(widget.decimals));

  void _bump(double delta) {
    _focus.unfocus();
    _commit(
      ((double.tryParse(_controller.text.trim()) ?? widget.value) + delta)
          .toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canDecrease = widget.value > widget.min;
    final bool canIncrease = widget.value < widget.max;
    return Row(
      children: <Widget>[
        _StepButton(
          key: const Key('numberStepperDecrement'),
          icon: Icons.remove,
          onTap: canDecrease ? () => _bump(-widget.step) : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              key: const Key('numberStepperField'),
              controller: _controller,
              focusNode: _focus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(
                decimal: widget.decimals > 0,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  widget.decimals > 0
                      ? RegExp(r'[0-9.]')
                      : RegExp(r'[0-9]'),
                ),
              ],
              onChanged: _typed,
              onSubmitted: _commit,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: FigmaColors.ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                suffixText: widget.suffix,
                suffixStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: FigmaColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: FigmaColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: FigmaColors.primary),
                ),
              ),
            ),
          ),
        ),
        _StepButton(
          key: const Key('numberStepperIncrement'),
          icon: Icons.add,
          onTap: canIncrease ? () => _bump(widget.step) : null,
        ),
      ],
    );
  }
}

/// −/+ 기호만 있는 버튼. 원형 배경도 테두리도 두르지 않는다 — 입력 칸 하나에
/// 테두리가 셋(칸 + 원 둘)이면 어느 쪽이 값인지 눈이 헷갈린다. 대신 누르는
/// 자리는 44 x 44 로 남겨 손가락이 닿는 넓이는 그대로다. (#1404)
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          icon,
          size: 24,
          color: onTap != null ? FigmaColors.primary : AppColors.mutedForeground,
        ),
      ),
    );
  }
}
