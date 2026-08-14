import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';

/// Bytes of a client's meal photo, keyed by its API path.
///
/// Fetched through [dioProvider] rather than as a plain image URL: the photo
/// route is authenticated and scoped to the trainer's own clients, so the
/// request needs the auth header the interceptor attaches. (#699)
final clientMealPhotoProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  path,
) async {
  final Dio dio = ref.watch(dioProvider);
  try {
    final Response<List<int>> res = await dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    final List<int>? data = res.data;
    if (data == null || data.isEmpty) return null;
    return Uint8List.fromList(data);
  } on DioException {
    // 사진을 못 가져와도 끼니 카드는 그대로 읽혀야 한다.
    return null;
  }
});

/// Square thumbnail of a client's meal photo. Renders nothing at all when
/// there is no photo (or it can't be loaded) — a placeholder box would only
/// add noise to a card that already reads fine without the image.
class ClientMealPhoto extends ConsumerWidget {
  /// Creates a thumbnail for the photo at [path] (API-base-relative).
  const ClientMealPhoto({super.key, required this.path, this.size = 56});

  /// API path relative to the API base
  /// (`/trainer/clients/<id>/diet/photos/<photo>`).
  final String path;

  /// Edge length of the square thumbnail.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Uint8List?> photo = ref.watch(
      clientMealPhotoProvider(path),
    );
    return photo.maybeWhen(
      data: (Uint8List? bytes) => bytes == null
          ? const SizedBox.shrink()
          : ClipRRect(
              borderRadius: const BorderRadius.all(AppRadius.card),
              child: Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                    const SizedBox.shrink(),
              ),
            ),
      // 로딩 중에는 자리를 잡아 둔다 — 사진이 늦게 들어오며 카드가 튀지 않도록.
      loading: () => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.all(AppRadius.card),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
