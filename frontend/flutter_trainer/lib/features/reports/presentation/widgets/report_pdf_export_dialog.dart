import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/services/report_pdf_actions.dart';
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

  /// 파일명은 로컬 저장뿐 아니라 multipart 헤더의 `filename` 으로도 그대로
  /// 나간다. 경로 구분자 외에 제어문자까지 지우는 이유다 — 고객 이름에 개행이
  /// 섞이면 헤더가 깨진다. 지운 결과가 비면 날짜만 남은 이름이 되므로 대체어를
  /// 쓴다.
  String _fileNameFor(AppLocalizations l) {
    final safeName = widget.report.client.name
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f\x7f]'), '_')
        .trim();
    final name = safeName.replaceAll('_', '').trim().isEmpty
        ? l.reportsPdfFallbackClient
        : safeName;
    return '${name}_${ymd(widget.report.weekStart)}_주간리포트.pdf';
  }

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
            fileName: _fileNameFor(l),
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
            () => actions.save(widget.bytes, _fileNameFor(l)),
            l.reportsPdfSaveStarted,
          ),
          icon: const Icon(Icons.download_outlined),
          label: Text(l.reportsPdfSave),
        ),
        TextButton.icon(
          key: const ValueKey<String>('report-pdf-print'),
          onPressed: () => _run(
            () => actions.print(widget.bytes, _fileNameFor(l)),
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
