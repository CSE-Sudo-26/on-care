import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare/features/auth/presentation/widgets/auth_fields.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/app_toast.dart';

/// 회원가입 화면 — 이름/이메일/전화번호/비밀번호로 계정을 만들고, 성공 시 자동
/// 로그인해 대시보드로 진입한다(라우터 가드가 인증 상태를 감지).
///
/// 전화번호를 여기서 받는 이유는 가입 직후부터 연락처가 있어야 하기
/// 때문이다 (#1634). 예전처럼 MY 탭 프로필 편집에서만 받으면, 트레이너와
/// 연결된 뒤에도 회원의 연락처가 비어 있는 기간이 생긴다.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  /// 표기(하이픈·국번·공백)는 사람마다 달라 숫자만 세고, 그 이상은 여기서
  /// 따지지 않는다 — 가입을 막을 만큼 확실한 규칙이 아니고 회원은 MY 탭에서
  /// 언제든 고칠 수 있다.
  static bool _hasEnoughDigits(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '').length >= 4;

  void _backToSignIn() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.signIn);
    }
  }

  Future<void> _register() async {
    if (_loading) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final AppToastHost toast = AppToastHost.of(context);
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;
    final confirm = _passwordConfirm.text;
    if (email.isEmpty || password.isEmpty) {
      toast.show(l.authMissingCredentials,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!_hasEnoughDigits(phone)) {
      toast.show(l.signUpPhoneInvalid,
        kind: AppToastKind.error,
      );
      return;
    }
    if (password.length < 8) {
      toast.show(l.signUpPasswordTooShort,
        kind: AppToastKind.error,
      );
      return;
    }
    if (password != confirm) {
      toast.show(l.signUpPasswordMismatch,
        kind: AppToastKind.error,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(email: email, password: password, name: name, phone: phone);
      if (!mounted) return;
      // New accounts land in first-run onboarding; the guard keeps the
      // (now authenticated) user on this protected route.
      context.go(AppRoutes.onboarding);
    } on DioException catch (e) {
      if (mounted) setState(() => _loading = false);
      final msg = e.response?.statusCode == 409
          ? l.signUpEmailTaken
          : l.signUpFailed;
      toast.show(msg, kind: AppToastKind.error);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      toast.show(l.signUpFailed, kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: IconButton(
                  // 뒤로 가기는 플랫폼이 이미 제 언어로 부르는 이름이 있다.
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: _backToSignIn,
                  icon: const Icon(Icons.arrow_back),
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        l.signUpTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.signUpSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      AuthField(
                        controller: _name,
                        hint: l.signUpNameHint,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthField(
                        controller: _email,
                        hint: l.authEmailHint,
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthField(
                        controller: _phone,
                        hint: l.signUpPhoneHint,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 6),
                      // 왜 전화번호를 받는지 그 자리에서 말해 준다. 건강 앱이
                      // 이유 없이 번호를 물으면 가입을 그만두는 쪽이 자연스럽다.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Text(
                          l.signUpPhoneHelper,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthField(
                        controller: _password,
                        hint: l.signUpPasswordHint,
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        trailing: IconButton(
                          // 아이콘만 있는 버튼이라 무엇을 켜고 끄는지 말할
                          // 데가 툴팁뿐이다(#972).
                          tooltip: _obscure
                              ? l.a11yShowPassword
                              : l.a11yHidePassword,
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                            color: AppColors.mutedForeground,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthField(
                        controller: _passwordConfirm,
                        hint: l.signUpPasswordConfirmHint,
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        onSubmitted: (_) => _register(),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      AuthGradientButton(
                        loading: _loading,
                        label: l.signUpAction,
                        onTap: _register,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Wrap 인 이유: 로케일에 따라 이 줄의 길이가 크게 달라진다.
                      // Row 로 두면 영어에서 화면 밖으로 넘친다(폭 400 기준 실측).
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            l.signUpHaveAccountQuestion,
                            style: const TextStyle(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          TextButton(
                            onPressed: _backToSignIn,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                            child: Text(l.authSignInAction),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
