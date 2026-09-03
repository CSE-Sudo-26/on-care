import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';

/// 회원이 불러 주는 6자리 동기화 코드를 한 자리씩 상자에 받는 입력. (#1634)
///
/// 회원 앱이 같은 모양(자리마다 상자)으로 코드를 띄운다 — 트레이너가 보는 것과
/// 회원이 보는 것이 같은 형태여야 "세 번째 자리가 뭐라고요?" 가 통한다.
///
/// 칸을 여섯 개 두는 대신 **보이지 않는 입력 하나**를 상자들 위에 겹친다.
/// 칸마다 컨트롤러를 두면 백스페이스·붙여넣기·자동완성이 칸 경계에서 어긋나고,
/// 포커스를 옮기는 코드가 화면 로직에 섞인다.
class PairingCodeInput extends StatefulWidget {
  const PairingCodeInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.enabled = true,
  });

  /// 지금까지 입력된 숫자. 여섯 자리가 차면 [onChanged] 가 그 값으로 불린다.
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// 코드 길이. 서버(`member_pairing_service.CODE_LENGTH`)와 같은 값이다.
  static const int length = 6;

  @override
  State<PairingCodeInput> createState() => _PairingCodeInputState();
}

class _PairingCodeInputState extends State<PairingCodeInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // 상자에 그려진 값이 컨트롤러를 따라가야 한다.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final String value = widget.controller.text;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < PairingCodeInput.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _DigitBox(
                  key: ValueKey<String>('pairing-digit-$i'),
                  digit: i < value.length ? value[i] : '',
                  // 다음에 칠 자리를 테두리로 알린다 — 커서가 보이지 않으므로
                  // 이것이 없으면 어디까지 쳤는지 화면이 말하지 않는다.
                  active: widget.focusNode.hasFocus && i == value.length,
                ),
              ),
          ],
        ),
        // 실제 입력. 투명하게 겹쳐 두고 탭을 받는다.
        Positioned.fill(
          child: TextField(
            key: const ValueKey<String>('client-connect-code'),
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: PairingCodeInput.length,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            // 값은 상자가 그린다 — 여기 글자가 보이면 두 벌로 겹친다.
            style: const TextStyle(color: Colors.transparent),
            cursorColor: Colors.transparent,
            showCursor: false,
            // 테마(`AppTheme.inputDecorationTheme`)가 모든 입력에 회색 채움과
            // 둥근 테두리를 주므로 [InputDecoration.border] 하나만 지워서는
            // 지워지지 않는다 — `enabledBorder`·`focusedBorder` 가 그대로
            // 남아 상자들 위에 가로로 긴 입력창이 겹쳐 그려진다(#1636).
            // 여기서 보여야 하는 것은 자리 상자뿐이므로 채움·테두리를 모두
            // 끄고, 높이도 상자 줄에 맡긴다.
            decoration: const InputDecoration(
              counterText: '',
              filled: false,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
            onChanged: widget.onChanged,
            onTap: () => setState(() {}),
          ),
        ),
      ],
    );
  }
}

/// 코드 한 자리. 아직 안 친 자리는 비어 있다.
class _DigitBox extends StatelessWidget {
  const _DigitBox({super.key, required this.digit, required this.active});

  final String digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          // 자리마다 폭이 달라 보이면 상자 안에서 숫자가 흔들린다.
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          color: AppColors.foreground,
        ),
      ),
    );
  }
}
