import 'package:flutter/painting.dart';

/// Shared soft card shadow, matching the user app's `kCardShadow`
/// (brand-navy tinted, ~12.5% alpha, blur 10, y+3) so cards across both
/// apps read with the same elevation. The tint `0x202E7DAB` uses
/// `AppColors.primary` (#2E7DAB, 남색).
const List<BoxShadow> kCardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x202E7DAB), blurRadius: 10, offset: Offset(0, 3)),
];
