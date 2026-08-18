import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare_trainer/features/auth/presentation/widgets/auth_fields.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// Trainer login screen — email/password login plus a "로그인 없이 데모
/// 둘러보기" bypass. Layout follows the user app's sign-in page; the
/// trainer app has no social login or self sign-up (accounts are 1:1),
/// so those are intentionally omitted. Wired to [SessionController].
class TrainerSignInPage extends ConsumerStatefulWidget {
  /// Creates the trainer login screen.
  const TrainerSignInPage({super.key});

  @override
  ConsumerState<TrainerSignInPage> createState() => _TrainerSignInPageState();
}

class _TrainerSignInPageState extends ConsumerState<TrainerSignInPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 로그인 뒤에 갈 자리. 딥링크로 들어와 로그인 화면을 거친 경우 인증 게이트가
  /// 목적지를 `?from=` 에 실어 두었으므로, 대시보드가 아니라 그 자리로 잇는다.
  /// 그냥 로그인하러 온 경우에는 없으니 대시보드다. (#701)
  String get _destination =>
      AppRoutes.resumeTarget(GoRouterState.of(context).uri.toString()) ??
      AppRoutes.dashboard;

  void _enterDemo() {
    final destination = _destination;
    ref.read(sessionControllerProvider.notifier).enterDemo();
    context.go(destination);
  }

  void _onSignUp() => context.push(AppRoutes.signUp);

  Future<void> _social(String provider) async {
    if (_loading) return;
    final messenger = ScaffoldMessenger.of(context);
    final destination = _destination;
    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .socialLogin(provider: provider);
      if (!mounted) return;
      context.go(destination);
    } catch (_) {
      // 요청 중 화면을 떠났으면 여기서 끝낸다 — 아래 `AppLocalizations.of` 가
      // 이미 해제된 context 를 조회하게 된다.
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).authErrSocialFailed),
        ),
      );
    }
  }

  Future<void> _login() async {
    if (_loading) return;
    final messenger = ScaffoldMessenger.of(context);
    final destination = _destination;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).authErrEmptyCredentials),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(email: email, password: password);
      if (!mounted) return;
      context.go(destination);
    } on AuthException catch (e) {
      if (!mounted) return;
      final AppLocalizations l = AppLocalizations.of(context);
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(authFailureText(l, e))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).authErrSignInFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // 가입 경로는 이제 실 API 모드에서도 열린다 — `/auth/trainer/register` 가
    // 헬스장 초대 코드로 트레이너 계정을 만든다(#475). 전에는 회원용
    // `/auth/register` 로 나가 role='member' 계정이 생겼고, 그 계정은
    // `/trainer/me` 에서 403 이라 가입해도 아무것도 할 수 없었다.
    const signUpEnabled = true;
    return Scaffold(
      // 사용자 앱 로그인 화면과 동일한 흰색 배경.
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 브랜드 — On-Care 로고(테두리 없이 크게), 사용자 앱과 동일.
                  Center(
                    child: Image.asset(
                      'assets/images/oncare-logo.png',
                      width: 132,
                      height: 132,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l.appTitleSpaced,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF262626),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.authTagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  AuthField(
                    key: const ValueKey<String>('trainer-login-email'),
                    controller: _email,
                    hint: l.authEmail,
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthField(
                    key: const ValueKey<String>('trainer-login-password'),
                    controller: _password,
                    hint: l.authPassword,
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    onSubmitted: (_) => _login(),
                    trailing: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AuthGradientButton(
                    key: const ValueKey<String>('trainer-login-submit'),
                    loading: _loading,
                    label: l.authSignIn,
                    onTap: _login,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _OrDivider(),
                  const SizedBox(height: AppSpacing.lg),
                  _SocialButton.kakao(
                    label: l.authContinueKakao,
                    onTap: _loading ? null : () => _social('kakao'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SocialButton.google(
                    label: l.authContinueGoogle,
                    onTap: _loading ? null : () => _social('google'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Self sign-up is demo-only: POST /auth/register creates a
                  // MEMBER account (no role param), so against the real
                  // backend a registered account gets a permanent 403 from
                  // /trainer/me — trainer accounts are provisioned server-side
                  // (seed/admin). Hide the entry when hitting the real API so
                  // it isn't a dead end. (Follow-up: trainer provisioning.)
                  if (signUpEnabled)
                    // Wrap, not Row: 영어 문구("Don't have an account?" +
                    // "Sign up")는 한국어보다 길어 좁은 폭에서 Row 가 넘쳤다.
                    // 줄바꿈으로 흘려보내면 어느 언어에서도 잘리지 않는다. (#501)
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          l.authNoAccount,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _onSignUp,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          child: Text(l.authSignUp),
                        ),
                      ],
                    ),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _enterDemo,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(l.authBrowseDemo),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "— 또는 —" separator between the email login and social buttons.
/// Mirrors the user app's sign-in divider.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: Color(0x1A000000))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            AppLocalizations.of(context).authOr,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
        ),
        const Expanded(child: Divider(color: Color(0x1A000000))),
      ],
    );
  }
}

/// Provider-branded social sign-in button (kakao / google), matching the
/// user app. [onTap] drives the demo-token social exchange.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border,
    this.iconSize = 20,
  });

  factory _SocialButton.kakao({
    required String label,
    required VoidCallback? onTap,
  }) => _SocialButton(
    label: label,
    icon: Icons.chat_bubble_rounded,
    background: const Color(0xFFFEE500),
    foreground: const Color(0xFF191600),
    onTap: onTap,
  );

  factory _SocialButton.google({
    required String label,
    required VoidCallback? onTap,
  }) => _SocialButton(
    label: label,
    icon: Icons.g_mobiledata,
    background: const Color(0xFFFFFFFF),
    foreground: const Color(0xFF262626),
    border: const Color(0x1A000000),
    iconSize: 28,
    onTap: onTap,
  );

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: border != null ? Border.all(color: border!) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: foreground, size: iconSize),
              const SizedBox(width: AppSpacing.sm),
              // 버튼 폭은 400 으로 고정인데 라벨은 로케일·글자 배율을 따라
              // 길어진다. `Continue with Google` 은 배율 1.3 에서 그대로 넘쳤다
              // (#849). 잘라내지 않고 줄여서 그린다 — `Continue with Goo…` 가
              // 되면 어느 계정으로 들어가는지가 사라진다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
