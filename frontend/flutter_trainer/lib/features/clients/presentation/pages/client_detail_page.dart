import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_detail_view.dart';
import 'package:oncare_trainer/shared/widgets/brand_header.dart';
import 'package:oncare_trainer/shared/widgets/content_frame.dart';

/// Full-screen client detail route (`/client/:id`) — used on narrow
/// viewports and for deep links. Wide viewports usually see the same
/// [ClientDetailView] embedded next to the client list instead.
class ClientDetailPage extends StatelessWidget {
  /// Creates the detail screen for the client with [clientId].
  const ClientDetailPage({super.key, required this.clientId});

  /// Id of the client being viewed (from the route path).
  final String clientId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BrandHeader(),
      body: SafeArea(
        child: ContentFrame(child: ClientDetailView(clientId: clientId)),
      ),
    );
  }
}
