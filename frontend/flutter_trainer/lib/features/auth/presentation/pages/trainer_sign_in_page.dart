import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare_trainer/features/auth/presentation/widgets/auth_fields.dart';

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

  void _enterDemo() {
    ref.read(sessionControllerProvider.notifier).enterDemo();
    context.go(AppRoutes.clients);
  }

  void _onSignUp() => context.push(AppRoutes.signUp);

  Future<void> _social(String provider) async {
    if (_loading) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .socialLogin(provider: provider);
      if (!mounted) return;
      context.go(AppRoutes.clients);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('소셜 로그인에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
    }
  }

  Future<void> _login() async {
    if (_loading) return;
    final messenger = ScaffoldMessenger.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해 주세요')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(email: email, password: password);
      if (!mounted) return;
      context.go(AppRoutes.clients);
    } on AuthException catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('로그인에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Self sign-up only makes sense in demo/mock mode (see below).
    final signUpEnabled = ref.watch(appConfigProvider).useMockApi;
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
                    'On - Care 트레이너',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF262626),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '고객 관리를 위한 트레이너 전용 앱',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  AuthField(
                    controller: _email,
                    hint: '이메일',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthField(
                    controller: _password,
                    hint: '비밀번호',
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
                    loading: _loading,
                    label: '로그인',
                    onTap: _login,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _OrDivider(),
                  const SizedBox(height: AppSpacing.lg),
                  _SocialButton.kakao(
                    onTap: _loading ? null : () => _social('kakao'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SocialButton.google(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text(
                          '계정이 없으신가요?',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _onSignUp,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text('회원가입'),
                        ),
                      ],
                    ),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _enterDemo,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('로그인 없이 데모 둘러보기'),
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
    return const Row(
      children: <Widget>[
        Expanded(child: Divider(color: Color(0x1A000000))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            '또는',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: Color(0x1A000000))),
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

  factory _SocialButton.kakao({required VoidCallback? onTap}) => _SocialButton(
    label: '카카오로 시작하기',
    icon: Icons.chat_bubble_rounded,
    background: const Color(0xFFFEE500),
    foreground: const Color(0xFF191600),
    onTap: onTap,
  );

  factory _SocialButton.google({required VoidCallback? onTap}) => _SocialButton(
    label: '구글로 시작하기',
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
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
