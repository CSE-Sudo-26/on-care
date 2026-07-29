import 'package:flutter/painting.dart';

/// Shared soft card shadow, matching the user app's `kCardShadow`
/// (brand-blue tinted, ~12.5% alpha, blur 10, y+3) so cards across both
/// apps read with the same elevation. The tint `0x203EAFDF` uses
/// `AppColors.primary` (#3EAFDF), identical to the user app.
const List<BoxShadow> kCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x203EAFDF),
    blurRadius: 10,
    offset: Offset(0, 3),
  ),
];
