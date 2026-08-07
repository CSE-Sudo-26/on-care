import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/errors/app_error.dart';
import 'package:oncare/design_system/atoms/app_badge.dart';
import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/molecules/section_header.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/exercise/presentation/widgets/kakao_map/kakao_map_view.dart';
import 'package:oncare/features/place/domain/entities/place.dart';
import 'package:oncare/features/place/presentation/controllers/place_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/error_view.dart';

({String label, AppBadgeTone tone}) _categoryDisplay(PlaceCategory c) =>
    switch (c) {
      PlaceCategory.medical => (label: '의료', tone: AppBadgeTone.info),
      PlaceCategory.fitness => (label: '운동', tone: AppBadgeTone.success),
      PlaceCategory.healthyFood => (label: '식단', tone: AppBadgeTone.warning),
      PlaceCategory.pharmacy => (label: '약국', tone: AppBadgeTone.neutral),
    };

class PlacePage extends ConsumerWidget {
  const PlacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(nearbyPlacesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.pagePlaceTitle)),
      body: async.when(
        data: (places) => _Body(places: places),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => ErrorView(
          error: e is AppError ? e : UnknownError(message: e.toString()),
          onRetry: () => ref.invalidate(nearbyPlacesProvider),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.places});
  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        _PlaceMap(places: places),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader('가까운 추천 장소'),
        for (final p in places) ...<Widget>[
          _PlaceTile(place: p),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// 실지도와 폴백이 같은 높이를 차지해야 폴백으로 떨어질 때 목록이 밀리지 않는다.
const double _kPlaceMapHeight = 160;

/// 주변 장소를 카카오맵 핀으로 찍는다. `KAKAO_JS_KEY` 가 없거나 web 이 아니거나
/// SDK 로드가 실패하면 [_MapPlaceholder] 로 폴백한다(#329).
class _PlaceMap extends ConsumerWidget {
  const _PlaceMap({required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 지도 중심은 목록을 가져온 검색 중심([placeQueryProvider])과 같아야 한다.
    final query = ref.watch(placeQueryProvider);
    return ClipRRect(
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: SizedBox(
        height: _kPlaceMapHeight,
        child: KakaoMapView(
          centerLat: query.lat,
          centerLng: query.lng,
          markers: <KakaoMapMarker>[
            for (final Place p in places)
              KakaoMapMarker(lat: p.lat, lng: p.lng, title: p.name),
          ],
          fallback: const _MapPlaceholder(),
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: _kPlaceMapHeight,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.map_outlined, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '지도를 표시할 수 없어요',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            '아래 목록은 그대로 볼 수 있어요',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = _categoryDisplay(place.category);
    return AppCard(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${place.name} → ${place.lat}, ${place.lng}')),
        );
      },
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(AppRadius.md),
            ),
            child: const Icon(Icons.place_outlined),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AppBadge(label: display.label, tone: display.tone),
                    const Spacer(),
                    Text(
                      '${place.distanceMeters}m',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(place.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(place.address, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
