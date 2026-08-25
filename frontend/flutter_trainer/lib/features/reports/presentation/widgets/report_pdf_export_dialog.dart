import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/services/report_pdf_actions.dart';
import 'package:oncare_trainer/features/reports/services/report_pdf_file_name.dart';
import 'package:oncare_trainer/features/reports/services/report_pdf_sender.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// A generated report's explicit delivery actions.
///
/// Kept public so the save and print boundaries can be exercised without
/// generating a PDF in a widget test.
class ReportPdfExportDialog extends ConsumerStatefulWidget {
  const ReportPdfExportDialog({
    required this.report,
    required this.bytes,
    super.key,
  });

  final WeeklyReport report;
  final Uint8List bytes;

  @override
  ConsumerState<ReportPdfExportDialog> createState() =>
      _ReportPdfExportDialogState();
}

class _ReportPdfExportDialogState extends ConsumerState<ReportPdfExportDialog> {
  bool _sending = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.reportsPdfActionFailed)),
        );
      }
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final l = AppLocalizations.of(context);
    await _run(
      () => ref
          .read(reportPdfSenderProvider)
          .send(
            clientId: widget.report.client.id,
            weekStart: widget.report.weekStart,
            bytes: widget.bytes,
            fileName: reportPdfFileName(l, widget.report),
            message: l.reportsPdfMessage,
          ),
      l.reportsPdfSent(widget.report.client.name),
    );
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final actions = ref.read(reportPdfActionsProvider);
    return AlertDialog(
      title: Text(l.reportsPdfLabel),
      content: Text(l.reportsPdfReady(widget.report.client.name)),
      actions: <Widget>[
        TextButton.icon(
          key: const ValueKey<String>('report-pdf-send'),
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send_outlined),
          label: Text(
            _sending ? l.reportsPdfSending : l.reportsPdfSendToClient,
          ),
        ),
        TextButton.icon(
          key: const ValueKey<String>('report-pdf-save'),
          onPressed: () => _run(
            () => actions.save(widget.bytes, reportPdfFileName(l, widget.report)),
            l.reportsPdfSaveStarted,
          ),
          icon: const Icon(Icons.download_outlined),
          label: Text(l.reportsPdfSave),
        ),
        TextButton.icon(
          key: const ValueKey<String>('report-pdf-print'),
          onPressed: () => _run(
            () => actions.print(widget.bytes, reportPdfFileName(l, widget.report)),
            l.reportsPdfPrintOpened,
          ),
          icon: const Icon(Icons.print_outlined),
          label: Text(l.reportsPdfPrint),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.reportsPdfClose),
        ),
      ],
    );
  }
}
