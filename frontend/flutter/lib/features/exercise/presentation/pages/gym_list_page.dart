import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/gym_trainer_line.dart';
import 'package:oncare/features/exercise/presentation/widgets/kakao_map/kakao_map_view.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

enum _GymSort { recommended, distance, rating }

/// 검색 결과 패널이 차지하는 화면 비율. (#865)
///
/// 최소값은 **완전히 접히지 않는 높이**다 — 결과가 있다는 사실과 첫 카드가 언제나
/// 보여야 한다. 최대값은 검색창과 시스템 영역을 침범하지 않는 선이고, 중간값은
/// 지도를 조금 남긴 채 여러 곳을 견주는 자리다.
class GymListPage extends ConsumerWidget {
  const GymListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: FigmaColors.statBg,
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
      body: const SafeArea(top: false, child: GymFinderView()),
    );
  }
}

/// 헬스장 찾기 화면의 본체 — 검색 + 지도 + 결과 목록.
///
/// 페이지(`/gyms`)와 운동 탭의 헬스장 화면이 **같은 위젯**을 쓴다. 연결된
/// 헬스장이 없는 회원에게 이 탭에서 할 일은 헬스장을 찾는 것뿐이라, 지도만 띄운
/// 빈 카드와 `헬스장 찾기` 버튼 대신 찾기 화면을 그대로 보여 준다(#1133).
///
/// 지도는 **자리에 고정**하고 그 아래 목록만 스크롤한다(#1135). 예전에는 지도
/// 위에 결과 시트를 얹어 두어, 목록을 밀면 시트가 먼저 커지며 지도까지 함께
/// 밀려 올라갔다. 목록을 상자로 한 번 더 감싸지도 않는다 — 좁은 화면에서 상자
/// 안의 상자가 되어 카드가 더 좁아졌다.
class GymFinderView extends ConsumerStatefulWidget {
  const GymFinderView({super.key});

  @override
  ConsumerState<GymFinderView> createState() => _GymFinderViewState();
}

class _GymFinderViewState extends ConsumerState<GymFinderView> {
  String _query = '';
  _GymSort _sort = _GymSort.recommended;

  /// 목록을 접었는지 (#1186). 처음 들어오면 지도와 목록이 함께 보이고, 접으면
  /// 목록이 사라지며 그 자리를 지도가 받는다.
  bool _listCollapsed = false;

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
    final List<Gym> visible = _visibleGyms(
      gymsAsync.valueOrNull ?? const <Gym>[],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints outer) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SearchField(
                  hintText: l.exGymSearchPlaceholder,
                  onChanged: (String value) => setState(() => _query = value),
                ),
                const SizedBox(height: 14),
                // 지도는 자리에 고정된다 — 아래 목록을 아무리 밀어도 따라오지
                // 않는다 (#1135). 목록을 접으면 그 자리를 지도가 받는다 (#1186).
                _GymMap(gyms: visible, expanded: _listCollapsed),
                const SizedBox(height: 16),
                // 지도와 목록 사이의 구분 선 — 여기가 두 영역의 경계이고,
                // 화살표가 그 경계에서 목록을 여닫는다 (#1186).
                const Divider(height: 1, color: FigmaColors.hairline),
                _NearbyHeader(
                  title: l.exNearbyGyms,
                  collapsed: _listCollapsed,
                  onToggle: () =>
                      setState(() => _listCollapsed = !_listCollapsed),
                ),
                if (!_listCollapsed) ...<Widget>[
                  if (gymsAsync.hasValue)
                    _ResultControls(
                      countLabel: l.exResultCount(visible.length),
                      sort: _sort,
                      onSort: (_GymSort value) => setState(() => _sort = value),
                    ),
                  const SizedBox(height: 10),
                  // 남는 높이를 목록이 쓴다. 운동 탭처럼 **높이가 열린
                  // 자리**(바깥이 스크롤 뷰)에 놓이면 남는 높이가 없으므로,
                  // 화면의 절반쯤을 목록 몫으로 떼어 준다 — 그래야 지도가 자리에
                  // 남고 목록만 구른다.
                  if (outer.hasBoundedHeight)
                    Expanded(child: _results(context, gymsAsync, visible))
                  else
                    SizedBox(
                      height: math.max(
                        MediaQuery.sizeOf(context).height * 0.45,
                        280,
                      ),
                      child: _results(context, gymsAsync, visible),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 결과 목록. 상자로 감싸지 않고 배경 위에 카드를 바로 쌓는다 (#1135).
  Widget _results(
    BuildContext context,
    AsyncValue<List<Gym>> gymsAsync,
    List<Gym> visible,
  ) {
    final AppLocalizations l = AppLocalizations.of(context);
    return gymsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      ),
      error: (Object _, StackTrace _) => _LoadError(
        message: l.exGymsLoadError,
        onRetry: () => ref.invalidate(gymFinderResultsProvider),
      ),
      data: (List<Gym> _) {
        if (visible.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _EmptyResults(message: l.exNoSearchResults),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int index) => _GymListCard(
            key: Key('gym-card-${visible[index].id}'),
            gym: visible[index],
            onTap: () =>
                context.push(AppRoutes.gymDetailPath(visible[index].id)),
          ),
        );
      },
    );
  }
}

/// `주변 헬스장` 머리줄 — 제목과 목록을 여닫는 화살표 (#1186).
///
/// 화살표는 목록이 열려 있으면 아래를(내릴 수 있다), 접혀 있으면 위를(다시
/// 올릴 수 있다) 가리킨다.
class _NearbyHeader extends StatelessWidget {
  const _NearbyHeader({
    required this.title,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String label = collapsed ? l.exGymListExpand : l.exGymListCollapse;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
        ),
        // 접힘 상태와 무엇을 할 수 있는지를 음성 안내에도 남긴다.
        Semantics(
          button: true,
          expanded: !collapsed,
          label: label,
          child: IconButton(
            key: const ValueKey<String>('gym-list-toggle'),
            onPressed: onToggle,
            tooltip: label,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              collapsed
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: FigmaColors.textMuted,
            ),
          ),
        ),
      ],
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

/// 결과 목록의 헬스장 카드 하나.
///
/// 이름·거리·평점·영업시간과 태그 아래에 **그 헬스장 소속 트레이너 전원**을
/// 적는다 (#1185) — 여기가 헬스장을 견주는 자리인데, 정작 누가 있는지는 상세로
/// 들어가야 알 수 있었다.
class _GymListCard extends ConsumerWidget {
  const _GymListCard({required this.gym, required this.onTap, super.key});

  final Gym gym;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final BorderRadius radius = BorderRadius.circular(16);
    // 트레이너를 아직 못 읽었거나 한 명도 없으면 이 부분은 통째로 없다 —
    // 카드가 예전과 같은 모습으로 남는다.
    final List<Trainer> trainers =
        ref.watch(gymTrainersProvider(gym.id)).valueOrNull ?? const <Trainer>[];
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
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
              // 소속 트레이너는 카드 **폭 전체**를 쓴다 — 이름·직함과 추천
              // 이유가 좁은 칸에서 두 번 접히지 않게.
              for (final Trainer trainer in trainers) ...<Widget>[
                const SizedBox(height: 9),
                GymTrainerLine(
                  key: Key('gym-trainer-${trainer.id}'),
                  trainer: trainer,
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
  const _GymMap({required this.gyms, this.expanded = false});

  final List<Gym> gyms;

  /// 목록을 접어 지도만 남은 상태인지 (#1186). 목록이 쓰던 높이를 지도가 받는다.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final List<Gym> located = gyms
        .where((Gym g) => g.hasCoordinates)
        .toList(growable: false);

    return SizedBox(
      // 핀이 여러 개 들어가야 해서 폴백 그래픽(150)보다 1.5배 높게 잡되, 화면이
      // 낮으면 그만큼 낮춘다 — 지도가 고정된 자리를 차지하므로(#1135) 여기서
      // 높이를 양보하지 않으면 작은 화면에서 목록이 설 자리가 없다.
      height: expanded
          // 목록이 접혔으면 지도가 화면을 넉넉히 쓴다 — 목록을 내린 이유가
          // 지도를 크게 보기 위해서다.
          ? math.min(520, MediaQuery.sizeOf(context).height * 0.55)
          : math.min(225, MediaQuery.sizeOf(context).height * 0.28),
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
