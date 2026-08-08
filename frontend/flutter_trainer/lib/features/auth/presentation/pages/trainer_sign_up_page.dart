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

/// 트레이너 회원가입 화면 — 사용자 앱 회원가입과 동일한 디자인. 이름/이메일/
/// 비밀번호와 **헬스장 초대 코드**로 계정을 만들고, 성공 시 자동 로그인해 고객
/// 탭으로 진입한다 (라우터 가드가 인증 상태를 감지).
///
/// 초대 코드가 소속 헬스장을 결정한다(#475). 소속 없는 트레이너는 상담 대상이
/// 될 수 없어(#443·#451) 가입 직후 아무것도 못 하는 계정이 된다.
///
/// **데모에서는 코드 입력을 아예 그리지 않는다.** 검증할 백엔드가 없어 무엇을
/// 넣든 통과하는 죽은 입력이 되고, 무엇보다 데모 화면이 지금과 달라진다.
class TrainerSignUpPage extends ConsumerStatefulWidget {
  /// Creates the trainer sign-up screen.
  const TrainerSignUpPage({super.key});

  @override
  ConsumerState<TrainerSignUpPage> createState() => _TrainerSignUpPageState();
}

class _TrainerSignUpPageState extends ConsumerState<TrainerSignUpPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();
  final TextEditingController _inviteCode = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  void _backToSignIn() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.signIn);
    }
  }

  Future<void> _register() async {
    if (_loading) return;
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _passwordConfirm.text;
    // 데모에는 코드를 검증할 백엔드가 없어 입력 자체를 그리지 않는다.
    final requiresInviteCode = !ref.read(appConfigProvider).useMockApi;
    final inviteCode = _inviteCode.text.trim();
    if (email.isEmpty || password.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해 주세요')),
      );
      return;
    }
    if (password.length < 8) {
      messenger.showSnackBar(
        const SnackBar(content: Text('비밀번호는 8자 이상이어야 해요')),
      );
      return;
    }
    if (password != confirm) {
      messenger.showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않아요')));
      return;
    }
    if (requiresInviteCode && inviteCode.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('헬스장에서 받은 초대 코드를 입력해 주세요')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            email: email,
            password: password,
            name: name,
            inviteCode: inviteCode,
          );
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } on AuthException catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('회원가입에 실패했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 데모 가입 화면은 지금과 동일해야 한다 — 코드 입력을 그리지 않는다.
    final showInviteCode = !ref.watch(appConfigProvider).useMockApi;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: IconButton(
                  onPressed: _backToSignIn,
                  icon: const Icon(Icons.arrow_back),
                  color: const Color(0xFF64748B),
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
                        '회원가입',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF262626),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'On-Care 계정을 만들어 고객 관리를 시작하세요',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      AuthField(
                        controller: _name,
                        hint: '이름',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthField(
                        controller: _email,
                        hint: '이메일',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthField(
                        controller: _password,
                        hint: '비밀번호 (8자 이상)',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        trailing: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthField(
                        controller: _passwordConfirm,
                        hint: '비밀번호 확인',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        // 데모에서는 이 필드가 마지막이라 제출 액션이 여기 붙는다.
                        onSubmitted: showInviteCode ? null : (_) => _register(),
                      ),
                      if (showInviteCode) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        AuthField(
                          controller: _inviteCode,
                          hint: '헬스장 초대 코드',
                          icon: Icons.confirmation_number_outlined,
                          textCapitalization: TextCapitalization.characters,
                          onSubmitted: (_) => _register(),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          '소속 헬스장에서 발급받은 코드를 입력해 주세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),

                      AuthGradientButton(
                        loading: _loading,
                        label: '가입하고 시작하기',
                        onTap: _register,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Text(
                            '이미 계정이 있으신가요?',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          TextButton(
                            onPressed: _backToSignIn,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                            child: const Text('로그인'),
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
