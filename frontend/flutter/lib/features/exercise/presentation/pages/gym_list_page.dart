import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/kakao_map/kakao_map_view.dart';
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
    // 제휴 헬스장 + 카카오 Local 주변 헬스장(#329). 카카오 쪽만 좌표가 있어도
    // 지도는 뜨고, 카카오가 실패하면 제휴 목록만 남는다.
    final AsyncValue<List<Gym>> gymsAsync = ref.watch(gymFinderResultsProvider);

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
                  _GymMap(
                    gyms: _visibleGyms(gymsAsync.valueOrNull ?? const <Gym>[]),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: gymsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      error: (Object _, StackTrace _) => _LoadError(
                        message: l.exGymsLoadError,
                        onRetry: () => ref.invalidate(gymFinderResultsProvider),
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
                                              onTap: () => context.push(
                                                AppRoutes.gymDetailPath(
                                                  visible[index].id,
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
        hintStyle: const TextStyle(
          color: AppColors.mutedForeground,
          fontSize: 13,
        ),
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
              fontSize: 14,
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
                fontSize: 13.5,
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
                        fontSize: 15,
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
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
                            fontSize: 12.5,
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
                        fontSize: 12.5,
                        color: AppColors.mutedForeground,
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
          fontSize: 12,
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
            style: const TextStyle(color: AppColors.foreground, fontSize: 13),
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
        style: const TextStyle(color: AppColors.foreground, fontSize: 13),
      ),
    );
  }
}

/// 목록에 보이는 헬스장을 카카오맵 핀으로 찍는다. `KAKAO_JS_KEY` 가 없거나
/// SDK 로드가 실패하면 [_GymMiniMap] 그래픽으로 폴백한다(#329).
class _GymMap extends StatelessWidget {
  const _GymMap({required this.gyms});

  final List<Gym> gyms;

  @override
  Widget build(BuildContext context) {
    final List<Gym> located = gyms
        .where((Gym g) => g.hasCoordinates)
        .toList(growable: false);

    return SizedBox(
      // 핀이 여러 개 들어가야 해서 폴백 그래픽(150)보다 1.5배 높게 잡는다.
      height: 225,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: KakaoMapView(
          // 지도 중심은 언제나 검색 중심([kGymFinderArea])이다. 첫 결과 좌표를
          // 쓰면 검색어·정렬·응답 순서에 따라 중심이 흔들려, 지도 중심과 장소
          // 검색 중심이 같아야 한다는 요건이 깨진다.
          centerLat: kGymFinderArea.lat,
          centerLng: kGymFinderArea.lng,
          markers: <KakaoMapMarker>[
            for (final Gym g in located)
              KakaoMapMarker(lat: g.lat!, lng: g.lng!, title: g.name),
          ],
          fallback: _GymMiniMap(pinCount: located.isEmpty ? 3 : located.length),
        ),
      ),
    );
  }
}

/// Lightweight illustrative map for the 헬스장 찾기 페이지 — a soft map backdrop
/// with [pinCount] location pins (헬스장 하나당 핀 하나) and a center "내 위치"
/// dot. Purely decorative (no real map/tiles/network) for the demo.
class _GymMiniMap extends StatelessWidget {
  const _GymMiniMap({required this.pinCount});

  final int pinCount;

  static const List<Alignment> _pinSpots = <Alignment>[
    Alignment(-0.55, -0.4),
    Alignment(0.5, -0.55),
    Alignment(0.42, 0.42),
    Alignment(-0.35, 0.55),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F0F4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FigmaColors.hairline),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: CustomPaint(painter: _MapRoadsPainter())),
            const Align(child: _MyLocationDot()),
            for (int i = 0; i < pinCount && i < _pinSpots.length; i++)
              Align(alignment: _pinSpots[i], child: const _MapPin()),
            Positioned(
              right: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l.exNearbyGymsMapLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
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

class _MapPin extends StatelessWidget {
  const _MapPin();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_on,
      size: 30,
      color: FigmaColors.primary,
      shadows: <Shadow>[
        Shadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
      ],
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: FigmaColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _MapRoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint road = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.62),
      Offset(size.width, size.height * 0.5),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.32, 0),
      Offset(size.width * 0.46, size.height),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.1),
      Offset(size.width * 0.86, size.height),
      road,
    );
    final Paint grid = Paint()
      ..color = const Color(0x0F1A1A1A)
      ..strokeWidth = 1;
    for (double x = size.width * 0.16; x < size.width; x += size.width * 0.22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (
      double y = size.height * 0.28;
      y < size.height;
      y += size.height * 0.32
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _MapRoadsPainter oldDelegate) => false;
}
