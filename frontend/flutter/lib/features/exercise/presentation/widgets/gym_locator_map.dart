import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/kakao_map/kakao_map_view.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 헬스장 찾기 지도의 높이. 실지도와 폴백 그래픽이 같은 자리를 차지해야
/// 폴백으로 떨어질 때 시트 레이아웃이 흔들리지 않는다.
const double kGymLocatorMapHeight = 190;

/// [gyms] 를 카카오맵 핀으로 찍는다. `KAKAO_JS_KEY` 가
/// 없거나 web 이 아니거나 SDK 로드가 실패하면 [_MapPlaceholder] 그래픽으로
/// 폴백한다(#329) — 데모가 비지 않게 하기 위한 요건이다.
class GymLocatorMap extends StatelessWidget {
  const GymLocatorMap({required this.gyms, super.key});

  final List<Gym> gyms;

  @override
  Widget build(BuildContext context) {
    final List<Gym> located = gyms
        .where((Gym g) => g.hasCoordinates)
        .toList(growable: false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: kGymLocatorMapHeight,
        width: double.infinity,
        child: KakaoMapView(
          // 지도 중심은 언제나 검색 중심([kGymFinderArea])이다. 첫 결과 좌표를
          // 쓰면 검색어에 따라 중심이 흔들려, 지도 중심과 장소 검색 중심이
          // 같아야 한다는 요건이 깨진다.
          centerLat: kGymFinderArea.lat,
          centerLng: kGymFinderArea.lng,
          markers: <KakaoMapMarker>[
            for (final Gym g in located)
              KakaoMapMarker(lat: g.lat!, lng: g.lng!, title: g.name),
          ],
          fallback: const _MapPlaceholder(),
        ),
      ),
    );
  }
}

/// A lightweight stylised map (roads, blocks, pins) so the locator reads as a
/// map area when the live Kakao Map is unavailable.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: kGymLocatorMapHeight,
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: CustomPaint(painter: _MapPainter())),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l.exKakaoMapArea,
                  style: const TextStyle(
                    fontSize: 11.5,
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

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEDEEE9),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.8, w, h * 0.2),
      Paint()..color = const Color(0xFFCFE4EF),
    );
    final Paint green = Paint()..color = const Color(0xFFCFE0C4);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.08, w * 0.17, h * 0.22),
      green,
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.63, h * 0.5, w * 0.2, h * 0.22), green);
    final Paint beige = Paint()..color = const Color(0xFFE3D9C7);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.31, h * 0.1, w * 0.22, h * 0.26),
      beige,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.44, w * 0.2, h * 0.28),
      beige,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.61, h * 0.08, w * 0.33, h * 0.28),
      beige,
    );
    final Paint road = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h * 0.4), Offset(w, h * 0.4), road);
    canvas.drawLine(Offset(0, h * 0.74), Offset(w, h * 0.74), road);
    canvas.drawLine(Offset(w * 0.28, 0), Offset(w * 0.28, h), road);
    canvas.drawLine(Offset(w * 0.58, 0), Offset(w * 0.58, h), road);
    canvas.drawLine(Offset(w * 0.85, 0), Offset(w * 0.85, h), road);
    _pin(canvas, Offset(w * 0.28, h * 0.4), selected: true);
    _pin(canvas, Offset(w * 0.58, h * 0.26), selected: false);
    _pin(canvas, Offset(w * 0.72, h * 0.6), selected: false);
  }

  void _pin(Canvas c, Offset p, {required bool selected}) {
    const double r = 7;
    if (selected) {
      c.drawCircle(
        p,
        r * 2,
        Paint()..color = FigmaColors.primary.withValues(alpha: 0.18),
      );
    }
    final Path path = Path()
      ..moveTo(p.dx, p.dy + r * 1.9)
      ..cubicTo(
        p.dx - r * 1.2,
        p.dy + r * 0.2,
        p.dx - r,
        p.dy - r,
        p.dx,
        p.dy - r,
      )
      ..cubicTo(
        p.dx + r,
        p.dy - r,
        p.dx + r * 1.2,
        p.dy + r * 0.2,
        p.dx,
        p.dy + r * 1.9,
      )
      ..close();
    c.drawPath(path, Paint()..color = FigmaColors.primary);
    c.drawCircle(
      Offset(p.dx, p.dy - r * 0.15),
      r * 0.4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
