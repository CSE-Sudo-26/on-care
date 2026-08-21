import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 헬스장·트레이너 연결을 끊는 하나의 흐름 — 확인 창을 띄우고, 승인되면
/// 끊은 뒤 연결 상태를 새로 읽는다.
///
/// MY 탭 카드와 상세 화면이 같은 것을 지운다. 두 화면이 각자 확인 창을 만들면
/// 한쪽만 "트레이너도 함께 사라진다" 를 알리는 식으로 갈린다. (#1057)
///
/// 승인 없이 닫혔으면 `false` 를 돌려준다 — 호출부가 화면을 닫을지 정한다.
Future<bool> confirmDisconnect(
  BuildContext context,
  WidgetRef ref, {
  required String message,
  required Future<void> Function(GymRepository repo) disconnect,
}) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final bool ok =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l.myConnectionDeleteTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.foreground,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
              ),
              child: Text(l.myCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF3B30),
              ),
              child: Text(l.myDelete),
            ),
          ],
        ),
      ) ??
      false;
  if (!ok) return false;
  await disconnect(ref.read(gymRepositoryProvider));
  // 해제를 기다리는 동안 화면을 벗어났다면 ref 가 이미 폐기됐을 수 있다.
  if (!context.mounted) return true;
  // 헬스장 해제는 트레이너까지 끊으므로 두 provider 를 함께 새로 읽는다.
  ref.invalidate(myGymProvider);
  ref.invalidate(myTrainerProvider);
  return true;
}

/// 상세 화면 하단의 연결 삭제 버튼.
///
/// 목록 카드에서 삭제를 상세로 옮겼으므로(#1057), 상세에도 지울 자리가 있어야
/// 한다. 그러지 않으면 연결을 끊을 방법이 화면에서 사라진다.
class DisconnectButton extends StatelessWidget {
  const DisconnectButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('connection-disconnect-button'),
        onPressed: onTap,
        icon: const Icon(Icons.link_off_rounded, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF3B30),
          side: const BorderSide(color: Color(0x33FF3B30)),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
