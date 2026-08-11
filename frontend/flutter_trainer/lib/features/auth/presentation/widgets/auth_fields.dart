import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

// 로그인 화면을 사용자 앱과 픽셀 단위로 동일하게 맞추기 위해, 사용자 앱
// AppColors 값을 그대로 사용한다(트레이너 로그인 전용).
const Color _authText = Color(0xFF262626); // 사용자 앱 foreground
const Color _authMutedText = Color(0xFF64748B); // 연한 남색 로딩 배경Foreground / hint
const Color _authInputBg = Color(0xFFF3F3F5); // 사용자 앱 inputBackground
const Color _authLoadingBg = Color(0xFFE6EFF7); // 연한 남색 로딩 배경
const BorderRadius _authRadius = BorderRadius.all(
  Radius.circular(14),
); // 사용자 앱 AppRadius.lg

/// Brand gradient for the auth screens — for the trainer auth screens
/// (primary #2E7DAB → 진한 남색 #17435F).
const LinearGradient authBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[Color(0xFF2E7DAB), Color(0xFF17435F)],
);

/// Filled, icon-prefixed text field used on the trainer login screen.
class AuthField extends StatelessWidget {
  /// Creates an auth text field.
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.onSubmitted,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  /// Field controller.
  final TextEditingController controller;

  /// Placeholder text.
  final String hint;

  /// Leading icon.
  final IconData icon;

  /// Whether to obscure input (passwords).
  final bool obscure;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Optional trailing widget (e.g. obscure toggle).
  final Widget? trailing;

  /// Submit callback (keyboard action).
  final ValueChanged<String>? onSubmitted;

  /// Overrides the keyboard action button.
  final TextInputAction? textInputAction;

  /// Auto-capitalisation. 초대 코드처럼 대문자로 적는 값에 쓴다 — 서버가
  /// 대소문자를 구분하지 않지만, 화면이 코드 모양대로 보이는 편이 옮겨 적기
  /// 쉽다. (#475)
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: _authText),
      textInputAction:
          textInputAction ??
          (onSubmitted != null ? TextInputAction.done : TextInputAction.next),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _authMutedText),
        prefixIcon: Icon(icon, color: _authMutedText, size: 20),
        suffixIcon: trailing,
        filled: true,
        fillColor: _authInputBg,
        border: const OutlineInputBorder(
          borderRadius: _authRadius,
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

/// Full-width gradient CTA with an inline loading spinner, used by the
/// trainer login screen.
class AuthGradientButton extends StatelessWidget {
  /// Creates the gradient button.
  const AuthGradientButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.loading,
  });

  /// Button label.
  final String label;

  /// Tap callback (ignored while [loading]).
  final VoidCallback onTap;

  /// Whether to show the spinner instead of the label.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: _authRadius,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: _authRadius,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: loading ? null : authBrandGradient,
            color: loading ? _authLoadingBg : null,
            borderRadius: _authRadius,
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.primaryForeground,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
