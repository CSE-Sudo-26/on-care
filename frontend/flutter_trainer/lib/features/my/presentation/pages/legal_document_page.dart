import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 이용약관 · 개인정보 처리방침 본문. (#968)
///
/// 트레이너 계정은 담당 회원의 식단·운동·건강 기록을 열어 보고 리포트를
/// 만들어 보내는 쪽이다. 그 조건이 회원 앱에만 적혀 있으면, 데이터를 다루는
/// 사람은 자기가 무엇에 동의했는지 앱 안에서 볼 방법이 없다.
///
/// 셸(사이드바) 밖의 최상위 라우트라 자기 Scaffold 를 갖는다 — 가입 화면에서
/// 열릴 때는 세션이 없어 셸이 존재하지 않는다.
class LegalDocumentPage extends StatelessWidget {
  /// Creates the document view. [document] is a segment from
  /// [AppRoutes.legalDocuments]; anything else falls back to 이용약관.
  const LegalDocumentPage({super.key, this.document});

  /// Which document to render, from the `:document` path parameter.
  final String? document;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool isPrivacy = document == AppRoutes.legalPrivacy;
    final String title = isPrivacy
        ? l.myLegalPrivacyTitle
        : l.myLegalTermsTitle;
    final String body = isPrivacy ? l.myLegalPrivacyBody : l.myLegalTermsBody;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PageScaffold(
          title: title,
          subtitle: l.myLegalEffectiveDate,
          maxWidth: AppLayout.contentMaxWidth,
          actions: <Widget>[
            ActionButton(
              label: l.actionBack,
              icon: Icons.arrow_back,
              onPressed: () => _leave(context),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionCard(
                title: title,
                icon: isPrivacy
                    ? Icons.privacy_tip_outlined
                    : Icons.description_outlined,
                child: SelectableText(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text(
                  l.myLegalEffectiveDate,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 돌아갈 곳. 앱 안에서 열렸으면 그 화면으로 되돌아가고, 주소창으로 바로
  /// 들어왔으면 대시보드로 보낸다 — 세션이 없으면 인증 게이트가 거기서
  /// 로그인 화면으로 돌려보내므로 여기서 로그인 여부를 따로 보지 않는다.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.dashboard);
  }
}
