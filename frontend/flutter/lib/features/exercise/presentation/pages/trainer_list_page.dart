import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

enum _TrainerSort { recommended, name }

class TrainerListPage extends ConsumerStatefulWidget {
  const TrainerListPage({super.key});

  @override
  ConsumerState<TrainerListPage> createState() => _TrainerListPageState();
}

class _TrainerListPageState extends ConsumerState<TrainerListPage> {
  String _query = '';
  _TrainerSort _sort = _TrainerSort.recommended;

  List<_TrainerListItem> _visibleTrainers(
    List<Trainer> trainers,
    List<Gym> gyms,
  ) {
    final String query = _query.trim().toLowerCase();
    final Map<String, String> gymNames = <String, String>{
      for (final Gym gym in gyms) gym.id: gym.name,
    };
    final List<_TrainerListItem> visible = trainers
        .map(
          (Trainer trainer) => _TrainerListItem(
            trainerId: trainer.id,
            name: trainer.name,
            role: trainer.role,
            gymName: gymNames[trainer.gymId] ?? '',
            reason: trainer.reason,
          ),
        )
        .where((_TrainerListItem trainer) {
          if (query.isEmpty) return true;
          return trainer.name.toLowerCase().contains(query) ||
              (trainer.role?.toLowerCase().contains(query) ?? false) ||
              trainer.gymName.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return switch (_sort) {
      _TrainerSort.recommended => visible,
      _TrainerSort.name =>
        visible.toList()..sort(
          (_TrainerListItem a, _TrainerListItem b) => a.name.compareTo(b.name),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<List<Trainer>> trainersAsync = ref.watch(
      allTrainersProvider,
    );
    // 헬스장 이름만 붙이면 되므로, 목록을 못 읽어도 트레이너는 그대로 보인다.
    final List<Gym> gyms =
        ref.watch(nearbyGymsProvider).valueOrNull ?? const <Gym>[];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          l.exFindTrainer,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: <Widget>[
                  _SearchField(
                    hintText: l.exTrainerSearchPlaceholder,
                    onChanged: (String value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: trainersAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      error: (Object _, StackTrace _) => _LoadError(
                        message: l.exTrainersLoadError,
                        onRetry: () => ref.invalidate(allTrainersProvider),
                      ),
                      data: (List<Trainer> trainers) {
                        final List<_TrainerListItem> visible = _visibleTrainers(
                          trainers,
                          gyms,
                        );
                        return Column(
                          children: <Widget>[
                            _ResultControls(
                              countLabel: l.exResultCount(visible.length),
                              sort: _sort,
                              onSort: (_TrainerSort value) =>
                                  setState(() => _sort = value),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: visible.isEmpty
                                  ? _EmptyResults(message: l.exNoSearchResults)
                                  : ListView.separated(
                                      itemCount: visible.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 10),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            return _TrainerListCard(
                                              trainer: visible[index],
                                              onTap: () => context.push(
                                                AppRoutes.trainerDetailPath(
                                                  visible[index].trainerId,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                            ),
                          ],
                        );
                      },
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

class _TrainerListItem {
  const _TrainerListItem({
    required this.trainerId,
    required this.name,
    required this.role,
    required this.gymName,
    required this.reason,
  });

  final String trainerId;
  final String name;
  final String? role;
  final String gymName;
  final String? reason;
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hintText, required this.onChanged});

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: FigmaColors.textMuted, fontSize: 13),
        prefixIcon: const Icon(
          Icons.search,
          color: FigmaColors.textMuted,
          size: 20,
        ),
        filled: true,
        fillColor: FigmaColors.softBlue,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FigmaColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FigmaColors.primary),
        ),
      ),
    );
  }
}

class _ResultControls extends StatelessWidget {
  const _ResultControls({
    required this.countLabel,
    required this.sort,
    required this.onSort,
  });

  final String countLabel;
  final _TrainerSort sort;
  final ValueChanged<_TrainerSort> onSort;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            countLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: 12, right: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FigmaColors.hairline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_TrainerSort>(
              value: sort,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.expand_more, size: 18),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FigmaColors.ink,
              ),
              items: <DropdownMenuItem<_TrainerSort>>[
                DropdownMenuItem<_TrainerSort>(
                  value: _TrainerSort.recommended,
                  child: Text(l.exSortRecommended),
                ),
                DropdownMenuItem<_TrainerSort>(
                  value: _TrainerSort.name,
                  child: Text(l.exSortName),
                ),
              ],
              onChanged: (_TrainerSort? value) {
                if (value != null) onSort(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainerListCard extends StatelessWidget {
  const _TrainerListCard({required this.trainer, required this.onTap});

  final _TrainerListItem trainer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final BorderRadius radius = BorderRadius.circular(16);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: FigmaColors.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: FigmaColors.iconTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_outline,
                  size: 23,
                  color: FigmaColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      trainer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: FigmaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // '전담 트레이너'가 있던 자리·스타일에 소속 헬스장을 표기.
                    Text(
                      trainer.gymName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trainer.reason ?? l.exTrainerRecommendationReason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: FigmaColors.primary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...<Widget>[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: FigmaColors.textFaint,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FigmaColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(l.actionRetry)),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: FigmaColors.textMuted, fontSize: 13),
      ),
    );
  }
}
