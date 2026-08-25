import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
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
/// 지도는 자리에 고정하고 그 위로 **목록 시트를 끌어 올리고 내린다**(#1274).
/// 시트는 세 자리에 붙는다 — 목록만 / 지도·목록 반반 / 지도만. 예전에는 머리줄
/// 화살표 하나로 두 상태를 오갈 뿐이라 폰에서 손으로 원하는 만큼 조절할 수
/// 없었고, 운동 탭처럼 바깥이 스크롤 뷰인 자리에서는 목록을 밀면 지도까지 함께
/// 밀려 올라갔다(#1135 가 막으려던 것이 이 배치에서는 지켜지지 않았다).
///
/// 그래서 이 위젯은 **높이를 스스로 정한다**. 바깥이 높이를 주면 그대로 쓰고,
/// 열린 높이(스크롤 뷰 안)에 놓이면 화면에서 한 몫을 떼어 쓴다 — 시트가 구를
/// 자리를 스스로 갖지 못하면 바깥 페이지가 대신 굴러 지도가 따라 움직인다.
///
/// 가로는 지도·시트가 **화면을 그대로 쓴다** (#1362). 여백은 검색줄과 시트 안
/// 내용이 각자 갖는다 — 창을 지도 폭에 맞춰 들여쓰면 폰에서 목록 카드가 그만큼
/// 좁아진다.
class GymFinderView extends ConsumerStatefulWidget {
  const GymFinderView({super.key});

  @override
  ConsumerState<GymFinderView> createState() => _GymFinderViewState();
}

class _GymFinderViewState extends ConsumerState<GymFinderView> {
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
    final List<Gym> visible = _visibleGyms(
      gymsAsync.valueOrNull ?? const <Gym>[],
    );
    // 상담 요청 확인 아이콘의 배지 — 대기 중인 요청이 있으면 점을 켠다(#1257).
    final bool hasPendingConsultation = ref
        .watch(consultationRequestControllerProvider)
        .any((ConsultationRequest r) => r.status == ConsultationStatus.pending);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints outer) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SizedBox(
            // 바깥이 높이를 주면 그대로 쓴다. 운동 탭처럼 **높이가 열린
            // 자리**(바깥이 스크롤 뷰)에 놓이면 화면에서 한 몫을 떼어 쓴다 —
            // 시트가 구를 자리를 스스로 갖지 못하면 바깥 페이지가 대신 굴러
            // 지도가 따라 움직인다 (#1274).
            height: outer.hasBoundedHeight
                ? outer.maxHeight
                : math.max(MediaQuery.sizeOf(context).height * 0.72, 460),
            // 좌우 여백은 **검색줄에만** 준다 (#1362). 지도·시트 묶음은
            // 화면 가로를 그대로 쓴다 — `주변 헬스장` 은 화면 아래에 붙는
            // 창이라 지도 폭에 맞춰 안으로 들여쓸 이유가 없고, 폰에서는 그
            // 여백만큼 목록 카드가 좁아진다. 시트 안 내용은 제 여백을 따로
            // 가진다.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _SearchField(
                          hintText: l.exGymSearchPlaceholder,
                          onChanged: (String value) =>
                              setState(() => _query = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 헤더의 채팅 버튼과 같은 자리·배지 모양이다 — 대기 중인
                      // 상담 요청이 있으면 점이 켜진다(#1257).
                      Semantics(
                        button: true,
                        label: l.exViewConsultationRequest,
                        child: FigmaCircleButton(
                          key: const Key('consult-history-shortcut'),
                          icon: Icons.assignment_outlined,
                          showDot: hasPendingConsultation,
                          onTap: () =>
                              context.push(AppRoutes.consultationHistory),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 지도는 자리에 고정되고 그 위로 목록 시트가 오르내린다
                // (#1274). 시트가 화면 몫을 다 쓰므로 남는 높이를 그대로
                // 넘긴다.
                Expanded(
                  child: _GymMapAndSheet(
                    gyms: visible,
                    header: l.exNearbyGyms,
                    controls: gymsAsync.hasValue
                        ? _ResultControls(
                            countLabel: l.exResultCount(visible.length),
                            sort: _sort,
                            onSort: (_GymSort value) =>
                                setState(() => _sort = value),
                          )
                        : null,
                    resultSliver: _resultSliver(context, gymsAsync, visible),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 결과 목록 — 시트 하나가 통째로 구르는 스크롤 뷰의 조각이다 (#1274).
  ///
  /// 목록을 제 스크롤 뷰로 두면 시트를 끌 때와 목록을 밀 때가 서로 다른 손짓이
  /// 된다. 머리줄·정렬 줄과 같은 스크롤 뷰에 얹어야, 목록이 맨 위에 닿은 채로
  /// 계속 내리면 시트가 그대로 이어서 내려간다. 상자로 감싸지 않고 배경 위에
  /// 카드를 바로 쌓는 것은 그대로다 (#1135).
  Widget _resultSliver(
    BuildContext context,
    AsyncValue<List<Gym>> gymsAsync,
    List<Gym> visible,
  ) {
    final AppLocalizations l = AppLocalizations.of(context);
    return gymsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
        ),
      ),
      error: (Object _, StackTrace _) => SliverToBoxAdapter(
        child: _LoadError(
          message: l.exGymsLoadError,
          onRetry: () => ref.invalidate(gymFinderResultsProvider),
        ),
      ),
      data: (List<Gym> _) {
        if (visible.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: _EmptyResults(message: l.exNoSearchResults),
            ),
          );
        }
        return SliverList.separated(
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

/// 지도 위에 얹혀 세 자리를 오가는 결과 목록 시트 (#1274).
///
/// **위 = 목록만 · 중간 = 반반 · 아래 = 지도만.** 손을 뗀 자리에서 가장 가까운
/// 단계에 붙고, 뗄 때의 속도도 반영돼 짧게 튕겨도 다음 단계로 넘어간다 —
/// [DraggableScrollableSheet] 의 스냅이 그 둘을 함께 해 준다.
///
/// 지도는 **윗변이 자리에 못 박힌 채** 시트가 남긴 만큼만 차지한다. 시트가
/// 오르내려도 지도가 따라 움직이지 않고, 둘이 겹치는 자리가 없다 — 겹쳐 두면
/// 웹에서 시트 위의 터치가 아래 지도(플랫폼 뷰, DOM 요소)로 새어 나가 폰에서
/// 시트를 끌 수도 목록을 밀 수도 없었다 (#1362).
///
/// 머리줄·정렬 줄·카드가 **한 스크롤 뷰**에 얹혀 있다. 그래야 목록이 맨 위에
/// 닿은 채로 계속 내리면 시트가 이어서 내려가고, 머리줄을 잡고 끌어도 시트가
/// 움직인다.
class _GymMapAndSheet extends StatefulWidget {
  const _GymMapAndSheet({
    required this.gyms,
    required this.header,
    required this.controls,
    required this.resultSliver,
  });

  final List<Gym> gyms;
  final String header;

  /// 결과 수와 정렬 드롭다운. 아직 못 읽었으면 null 이라 자리도 없다.
  final Widget? controls;
  final Widget resultSliver;

  /// 시트가 가장 낮을 때 남는 높이 — 손잡이와 머리줄만큼이다. 여기가 0 이 되면
  /// 목록을 다시 올릴 자리가 사라진다.
  static const double kCollapsedExtent = 76;

  /// 반반 자리. 지도를 절반 남긴 채 여러 곳을 견주는 자리다.
  static const double kMidSize = 0.5;

  @override
  State<_GymMapAndSheet> createState() => _GymMapAndSheetState();
}

class _GymMapAndSheetState extends State<_GymMapAndSheet> {
  final DraggableScrollableController _sheet = DraggableScrollableController();

  /// 지금 시트가 차지한 비율. 머리줄 화살표가 이 값을 보고 방향을 정한다 —
  /// 드래그와 화살표가 같은 상태를 가리켜야 둘이 어긋나지 않는다.
  double _size = _GymMapAndSheet.kMidSize;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSheetMoved);
  }

  void _onSheetMoved() {
    if (!_sheet.isAttached) return;
    final double next = _sheet.size;
    if ((next - _size).abs() < 0.001) return;
    setState(() => _size = next);
  }

  @override
  void dispose() {
    _sheet.removeListener(_onSheetMoved);
    _sheet.dispose();
    super.dispose();
  }

  /// 화살표를 눌렀을 때 갈 자리. 맨 아래에서는 위로, 그 밖에서는 한 단계
  /// 아래로 간다 — 계속 누르면 지도만 남을 때까지 내려가고, 거기서 방향이
  /// 뒤집힌다.
  double _nextStop(double min) {
    if (_size <= min + 0.01) return _GymMapAndSheet.kMidSize;
    if (_size > _GymMapAndSheet.kMidSize + 0.01) {
      return _GymMapAndSheet.kMidSize;
    }
    return min;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double height = box.maxHeight;
        // 낮은 화면에서도 손잡이와 머리줄은 남아야 하고, 높은 화면에서 그
        // 비율이 반반을 넘어서도 안 된다.
        final double minSize = height <= 0
            ? 0.2
            : (_GymMapAndSheet.kCollapsedExtent / height).clamp(0.12, 0.45);
        final bool collapsed = _size <= minSize + 0.01;
        // 지도는 **시트가 덮지 않는 자리에만** 놓는다 (#1362). 웹에서 카카오
        // 지도는 플랫폼 뷰(DOM 요소)라, 그 위를 덮은 Flutter 시트에서 시작한
        // 터치가 아래 지도로 새어 나간다 — 폰에서 시트를 끌면 시트 대신 지도가
        // 끌리고, 목록을 밀면 목록 대신 지도가 움직였다. 겹치는 자리를 아예
        // 없애면 그 새는 길이 사라진다. 지도의 **윗변은 그대로** 있으므로 시트가
        // 오르내려도 지도는 제자리다 (#1135).
        final double mapHeight = (height * (1 - _size)).clamp(0.0, height);
        return Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: mapHeight,
              child: _GymMap(gyms: widget.gyms),
            ),
            DraggableScrollableSheet(
              controller: _sheet,
              initialChildSize: _GymMapAndSheet.kMidSize.clamp(minSize, 1),
              minChildSize: minSize,
              snap: true,
              snapSizes: <double>[_GymMapAndSheet.kMidSize.clamp(minSize, 1)],
              builder:
                  (
                    BuildContext context,
                    ScrollController scrollController,
                  ) => _SheetSurface(
                    // 시트의 **겉면**이 이 키를 갖는다. 시트 위젯 자체는
                    // 스택 전체를 덮고 있어, 그 자리를 재면 시트가 어디에
                    // 붙어 있는지가 아니라 스택의 윗변이 나온다.
                    key: const Key('gym-result-sheet'),
                    child: CustomScrollView(
                      // 시트 안에서 실제로 구르는 목록. 이 키로 가리킨다 —
                      // `Scrollable` 이 시트에 둘(시트 자신과 이 목록)이라
                      // "찾기 화면 안의 유일한 스크롤" 로는 집을 수 없다.
                      key: const Key('gym-result-list'),
                      controller: scrollController,
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: _SheetHead(
                            title: widget.header,
                            collapsed: collapsed,
                            onToggle: () => _sheet.animateTo(
                              _nextStop(minSize),
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                        ),
                        if (widget.controls != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                              child: widget.controls,
                            ),
                          ),
                        // 시트는 화면 가로를 다 쓰고, 여백은 그 안에서
                        // 준다 (#1362).
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: widget.resultSliver,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      ],
                    ),
                  ),
            ),
          ],
        );
      },
    );
  }
}

/// 시트의 바탕 — 지도 위에 얹히므로 제 배경과 위쪽 둥근 모서리를 가진다.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FigmaColors.statBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: child,
      ),
    );
  }
}

/// 시트 머리 — 잡아 끄는 자리를 알리는 손잡이와, 제목·화살표 한 줄 (#1186).
///
/// 화살표는 시트가 맨 아래에 있으면 위를(올릴 수 있다), 그 밖에서는 아래를
/// (내릴 수 있다) 가리킨다. 드래그와 같은 상태([_GymMapAndSheetState._size])를
/// 읽으므로 손으로 끌어 놓은 자리와 화살표 방향이 어긋나지 않는다.
class _SheetHead extends StatelessWidget {
  const _SheetHead({
    required this.title,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FigmaColors.hairline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _NearbyHeader(
            title: title,
            collapsed: collapsed,
            onToggle: onToggle,
          ),
        ),
      ],
    );
  }
}

/// `주변 헬스장` 머리줄 — 제목과 시트를 오르내리는 화살표 (#1186, #1274).
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
  const _GymMap({required this.gyms});

  final List<Gym> gyms;

  @override
  Widget build(BuildContext context) {
    final List<Gym> located = gyms
        .where((Gym g) => g.hasCoordinates)
        .toList(growable: false);

    // 높이를 스스로 정하지 않는다 — 시트가 어디에 있느냐가 지도의 높이를
    // 정한다 (#1274, #1362). 화면 가로를 그대로 쓰므로 모서리는 둥글리지
    // 않는다 — 아래로 이어지는 시트만 제 위쪽 모서리를 갖는다.
    return SizedBox.expand(
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
    // 실지도와 **같은 자리**를 차지한다 (#1362) — 화면 가로를 채우고 높이는
    // 부모(시트가 남긴 자리)를 따른다. 둘의 생김새가 다르면 폴백으로 떨어질
    // 때 화면 구조가 바뀐다.
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFE9F0F4)),
      child: SizedBox.expand(
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
