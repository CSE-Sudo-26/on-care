import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'report_pdf_actions_base.dart';
import 'report_pdf_actions_stub.dart'
    if (dart.library.html) 'report_pdf_actions_web.dart'
    as platform;

export 'report_pdf_actions_base.dart';

final reportPdfActionsProvider = Provider<ReportPdfActions>(
  (_) => platform.createReportPdfActions(),
);
