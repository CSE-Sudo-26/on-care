import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/ai_coach/domain/entities/ai_coach_state.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/ai_coach_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// "AI 건강 도우미" bottom sheet — the daily coaching digest opened from the
/// floating Oni button and the Home coaching banner. Its CTA hands off to the
/// AI chat. Mirrors the Figma `CoachingSheet`.
Future<void> showCoachingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // 탭 페이지마다 Navigator 가 따로 있어 기본값으로 열면 시트가 그 안에 뜬다.
    // MainShell 의 하단 바와 + 버튼은 그 바깥이라 시트 **위에** 그려지고, 스크림도
    // 걸리지 않은 채 눌린다 — 시트를 열어 둔 채 탭이 바뀐다(#791).
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => const _CoachingSheet(),
  );
}

class _CoachCard {
  const _CoachCard({
    required this.tag,
    required this.tagColor,
    required this.title,
    required this.body,
    required this.done,
  });
  final String tag;
  final Color tagColor;
  final String title;
  final String body;
  final bool done;
}

List<_CoachCard> _cardsOf(AppLocalizations l) => <_CoachCard>[
  _CoachCard(
    tag: l.coachCardDietTag,
    tagColor: FigmaColors.orange,
    title: l.coachCardDietTitle,
    body: l.coachCardDietBody,
    done: true,
  ),
  _CoachCard(
    tag: l.coachCardExerciseTag,
    tagColor: FigmaColors.greenTag,
    title: l.coachCardExerciseTitle,
    body: l.coachCardExerciseBody,
    done: true,
  ),
];

String _suggestionTagLabel(AiSuggestionTag tag) => switch (tag) {
  AiSuggestionTag.diet => '식단',
  AiSuggestionTag.exercise => '운동',
  AiSuggestionTag.sleep => '수면',
  AiSuggestionTag.hydration => '수분',
};

Color _suggestionTagColor(AiSuggestionTag tag) => switch (tag) {
  AiSuggestionTag.diet => FigmaColors.orange,
  AiSuggestionTag.exercise => FigmaColors.greenTag,
  AiSuggestionTag.sleep => FigmaColors.sugarPurple,
  AiSuggestionTag.hydration => FigmaColors.primary,
};

_CoachCard _cardFromSuggestion(AiSuggestion s) => _CoachCard(
  tag: _suggestionTagLabel(s.tag),
  tagColor: _suggestionTagColor(s.tag),
  title: s.title,
  body: s.body,
  done: false,
);

class _CoachingSheet extends ConsumerWidget {
  const _CoachingSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 데모/목 모드는 기존 하드코딩 카드를 유지(둘러보기 화면 동일). 실모드에서만
    // /ai-coach/feedback 의 실제 제안을 렌더하고, 로딩/에러/빈 응답은 기존 카드로 폴백.
    final List<_CoachCard> cards;
    if (ref.watch(appConfigProvider).useMockApi) {
      cards = _cardsOf(l);
    } else {
      final List<AiSuggestion>? live = ref
          .watch(aiCoachStateProvider)
          .asData
          ?.value
          .suggestions;
      cards = (live == null || live.isEmpty)
          ? _cardsOf(l)
          : live.map(_cardFromSuggestion).toList();
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 480,
      ),
      child: Container(
        key: const Key('coachingSheet'),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE3EA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: <Widget>[
                    const OniAvatar(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l.coachHeaderPill,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: FigmaColors.primary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            l.coachHeaderSubtitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, int i) => _CoachCardTile(card: cards[i]),
                ),
              ),
              Padding(
                key: const Key('coachingSheetCta'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(AppRoutes.aiCoach);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: FigmaColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 19,
                    ),
                    label: Text(
                      l.coachCtaChat,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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

class _CoachCardTile extends StatelessWidget {
  const _CoachCardTile({required this.card});
  final _CoachCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: card.tagColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              card.tag,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: card.tagColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  card.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  card.body,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.foreground,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (card.done) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: FigmaColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 13, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F6F8),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.close, size: 16, color: FigmaColors.textSub),
        ),
      ),
    );
  }
}
