import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/request_id.dart';

class ReportPdfSender {
  ReportPdfSender(this._dio);

  final Dio _dio;
  final Map<String, String> _requestIds = <String, String>{};

  Future<void> send({
    required String clientId,
    required DateTime weekStart,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final key = '$clientId/${ymd(weekStart)}';
    final requestId = _requestIds.putIfAbsent(key, newClientRequestId);
    await _dio.post<Map<String, Object?>>(
      '/trainer/clients/${Uri.encodeComponent(clientId)}/report/send-pdf',
      data: FormData.fromMap(<String, Object?>{
        'week_start': ymd(weekStart),
        'message': '이번 주 리포트입니다.',
        'client_request_id': requestId,
        'pdf': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType('application', 'pdf'),
        ),
      }),
    );
    if (_requestIds[key] == requestId) _requestIds.remove(key);
  }
}

final reportPdfSenderProvider = Provider<ReportPdfSender>(
  (ref) => ReportPdfSender(ref.watch(dioProvider)),
);
