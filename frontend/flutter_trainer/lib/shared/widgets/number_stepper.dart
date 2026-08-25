import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// 숫자 한 칸 — 직접 입력하는 텍스트 필드와 양옆의 −/+ 버튼.
///
/// 회원 앱의 같은 위젯(`AppNumberStepper`)과 같은 모양이다(#1276). 두 앱이
/// 별개 패키지라 코드를 공유하지 못해 각자 갖는다 — 값·단위·증감 폭이 어긋나면
/// 트레이너가 짠 프로그램과 회원이 적은 기록이 서로 다른 눈금을 쓰게 된다.
///
/// 예전에는 시간을 슬라이더로 받았다. 슬라이더는 "대충 이쯤" 을 고르기엔 좋지만
/// 트레이너가 아는 값(45분·12세트·62.5kg)을 그대로 넣기에는 나쁘다.
class NumberStepper extends StatefulWidget {
  /// Creates a number stepper.
  const NumberStepper({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.step = 1,
    this.decimals = 0,
    this.suffix,
    this.keyPrefix,
    super.key,
  });

  /// Current value.
  final double value;

  /// Called with the new value on every accepted edit.
  final ValueChanged<double> onChanged;

  /// Inclusive bounds.
  final double min;

  /// Inclusive bounds.
  final double max;

  /// −/+ 한 번이 옮기는 폭.
  final double step;

  /// 소수점 자릿수. 0 이면 정수로 읽고 쓴다.
  final int decimals;

  /// 필드 오른쪽에 붙는 단위 문구("분", "세트", "kg").
  final String? suffix;

  /// 테스트가 이 스테퍼를 짚을 때 쓰는 키 접두사.
  final String? keyPrefix;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit(_controller.text);
    });
  }

  @override
  void didUpdateWidget(NumberStepper old) {
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

  String _format(double v) => widget.decimals == 0
      ? v.round().toString()
      : v.toStringAsFixed(widget.decimals);

  double _round(double v) => widget.decimals == 0
      ? v.roundToDouble()
      : double.parse(v.toStringAsFixed(widget.decimals));

  double _clamp(double v) => v.clamp(widget.min, widget.max);

  /// 적히는 대로 값을 올린다. **필드의 글자는 건드리지 않는다** — 타이핑 중에
  /// 고쳐 쓰면 "4" 를 지나 "47" 로 가는 길이 막히고 커서가 튄다.
  void _typed(String raw) {
    final double? parsed = double.tryParse(raw.trim());
    if (parsed != null) widget.onChanged(_round(_clamp(parsed)));
  }

  /// 비워 둔 칸이나 범위 밖 값을 되돌리고 글자를 다시 그린다.
  void _commit(String raw) {
    final double next = _round(
      _clamp(double.tryParse(raw.trim()) ?? widget.value),
    );
    _controller.text = _format(next);
    widget.onChanged(next);
  }

  void _bump(double delta) {
    _focus.unfocus();
    _commit(
      ((double.tryParse(_controller.text.trim()) ?? widget.value) + delta)
          .toString(),
    );
  }

  Key? _key(String suffix) =>
      widget.keyPrefix == null ? null : ValueKey<String>('${widget.keyPrefix}-$suffix');

  @override
  Widget build(BuildContext context) {
    // 하나의 테두리 상자 안에 −/필드/+ 를 담는다 — 옆의 다른 필드(테두리
    // 있는 사각 박스)와 같은 모양 언어를 쓰기 위해서다. 예전에는 −/+ 가 각자
    // 원형 버튼이라 같은 줄의 다른 필드보다 눈에 튀고 폭도 더 썼다.
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: <Widget>[
          _StepButton(
            key: _key('minus'),
            icon: Icons.remove,
            onTap: widget.value > widget.min
                ? () => _bump(-widget.step)
                : null,
          ),
          const _VerticalDivider(),
          Expanded(
            child: TextField(
              key: _key('field'),
              controller: _controller,
              focusNode: _focus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(
                decimal: widget.decimals > 0,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  widget.decimals > 0 ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                ),
              ],
              onChanged: _typed,
              onSubmitted: _commit,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                suffixText: widget.suffix,
                suffixStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtleForeground,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const _VerticalDivider(),
          _StepButton(
            key: _key('plus'),
            icon: Icons.add,
            onTap: widget.value < widget.max ? () => _bump(widget.step) : null,
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 24,
      child: VerticalDivider(width: 1, thickness: 1, color: AppColors.borderStrong),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool on = onTap != null;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: double.infinity,
        child: Icon(
          icon,
          size: 18,
          color: on ? AppColors.accent : AppColors.disabledForeground,
        ),
      ),
    );
  }
}
