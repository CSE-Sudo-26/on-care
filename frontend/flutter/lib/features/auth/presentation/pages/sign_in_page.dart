import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare/features/auth/presentation/widgets/auth_fields.dart';

/// 로그인 화면 — 이메일/비밀번호 로그인 + 우측 상단 "데모로 시작" 바로가기.
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
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
    context.go(AppRoutes.dashboard);
  }

  Future<void> _login() async {
    if (_loading) return;
    final messenger = ScaffoldMessenger.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력해 주세요')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(sessionControllerProvider.notifier).login(
        email: email,
        password: password,
      );
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('로그인에 실패했어요. 이메일·비밀번호를 확인해 주세요')),
      );
    }
  }

  Future<void> _social(String provider) async {
    if (_loading) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      // 실기기 SDK(kakao/google) 연동 전까지는 데모 토큰을 보낸다. 실서버
      // (USE_MOCK_API=false)에서는 FastAPI가 provider 토큰을 실제 검증한다.
      await ref
          .read(sessionControllerProvider.notifier)
          .socialLogin(provider: provider, token: 'demo-$provider-token');
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('소셜 로그인에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // 브랜드 — On-Care 로고 (테두리 없이 크게)
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
                        'On - care',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '고혈압·당뇨 관리를 위한 AI 헬스케어',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
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
                            color: AppColors.mutedForeground,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // 로그인 버튼(그라데이션)
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Text(
                            '계정이 없으신가요?',
                            style: TextStyle(color: AppColors.mutedForeground),
                          ),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.signUp),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                            child: const Text('회원가입'),
                          ),
                        ],
                      ),
                      Center(
                        child: TextButton(
                          onPressed: _enterDemo,
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
          ],
        ),
      ),
    );
  }
}

/// "— 또는 —" separator between the email login and social buttons.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            '또는',
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

/// Provider-branded social sign-in button. Real SDK token acquisition is
/// deferred; the [onTap] currently drives a demo-token exchange.
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
    background: AppColors.card,
    foreground: AppColors.foreground,
    border: AppColors.border,
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
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.lg),
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

