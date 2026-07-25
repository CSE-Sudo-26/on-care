import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

enum _GymSort { recommended, distance, rating }

class GymListPage extends ConsumerStatefulWidget {
  const GymListPage({super.key});

  @override
  ConsumerState<GymListPage> createState() => _GymListPageState();
}

class _GymListPageState extends ConsumerState<GymListPage> {
  String _query = '';
  _GymSort _sort = _GymSort.recommended;

  List<Gym> _visibleGyms(List<Gym> gyms) {
    final String query = _query.trim().toLowerCase();
    final List<Gym> visible = gyms
        .where((Gym gym) {
          if (query.isEmpty) return true;
          return gym.name.toLowerCase().contains(query) ||
              gym.address.toLowerCase().contains(query) ||
              gym.tags.any((String tag) => tag.toLowerCase().contains(query));
        })
        .toList(growable: false);

    return switch (_sort) {
      _GymSort.recommended => visible,
      _GymSort.distance =>
        visible.toList()
          ..sort((Gym a, Gym b) => a.distanceKm.compareTo(b.distanceKm)),
      _GymSort.rating =>
        visible.toList()..sort((Gym a, Gym b) => b.rating.compareTo(a.rating)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<List<Gym>> gymsAsync = ref.watch(nearbyGymsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          l.exFindGym,
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
                    hintText: l.exGymSearchPlaceholder,
                    onChanged: (String value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: gymsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      error: (Object _, StackTrace _) => _LoadError(
                        message: l.exGymsLoadError,
                        onRetry: () => ref.invalidate(nearbyGymsProvider),
                      ),
                      data: (List<Gym> gyms) {
                        final List<Gym> visible = _visibleGyms(gyms);
                        return Column(
                          children: <Widget>[
                            _ResultControls(
                              countLabel: l.exResultCount(visible.length),
                              sort: _sort,
                              onSort: (_GymSort value) =>
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
                                            return _GymListCard(
                                              gym: visible[index],
                                              onTap: null,
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
  final _GymSort sort;
  final ValueChanged<_GymSort> onSort;

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
            child: DropdownButton<_GymSort>(
              value: sort,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.expand_more, size: 18),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FigmaColors.ink,
              ),
              items: <DropdownMenuItem<_GymSort>>[
                DropdownMenuItem<_GymSort>(
                  value: _GymSort.recommended,
                  child: Text(l.exSortRecommended),
                ),
                DropdownMenuItem<_GymSort>(
                  value: _GymSort.distance,
                  child: Text(l.exSortDistance),
                ),
                DropdownMenuItem<_GymSort>(
                  value: _GymSort.rating,
                  child: Text(l.exSortRating),
                ),
              ],
              onChanged: (_GymSort? value) {
                if (value != null) onSort(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _GymListCard extends StatelessWidget {
  const _GymListCard({required this.gym, required this.onTap});

  final Gym gym;
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FigmaColors.primaryA(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.fitness_center,
                  size: 21,
                  color: FigmaColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      gym.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: FigmaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        Text(
                          '${gym.distanceKm.toStringAsFixed(1)}km',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: FigmaColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: FigmaColors.orange,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          gym.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FigmaColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      gym.weekdayHours == null
                          ? gym.address
                          : '${gym.address} · ${l.exGymWeekdayHours(gym.weekdayHours!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                    if (gym.tags.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final String tag in gym.tags.take(2))
                            _TagChip(label: tag),
                        ],
                      ),
                    ],
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

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: FigmaColors.primaryA(0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: FigmaColors.primary,
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
