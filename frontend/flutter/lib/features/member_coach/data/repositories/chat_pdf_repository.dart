import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/network/dio_client.dart';

class ChatPdfRepository {
  const ChatPdfRepository(this._dio);

  final Dio _dio;

  Future<Uint8List> download(String path) async {
    final response = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }
}

final chatPdfRepositoryProvider = Provider<ChatPdfRepository>(
  (ref) => ChatPdfRepository(ref.watch(dioProvider)),
);
