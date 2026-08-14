import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// 통합 검색 결과에 함께 노출할 교차 영역 데이터입니다.
class ClientSearchFacts {
  const ClientSearchFacts({
    this.unread = const <String, int>{},
    this.nextSession = const <String, ScheduleSession>{},
  });

  final Map<String, int> unread;
  final Map<String, ScheduleSession> nextSession;

  static const ClientSearchFacts none = ClientSearchFacts();
}

/// 통합 검색에서 예정 예약으로 간주하는 범위입니다.
const int clientSearchUpcomingDays = 28;

/// 고객별 가장 가까운 예정 예약을 반환합니다.
///
/// `clientId`가 없는 과거 예약은 이름이 유일할 때만 연결하여 동명이인의
/// 기록이 잘못 노출되지 않도록 합니다.
Map<String, ScheduleSession> nextSessionsByClient(
  List<TrainerClient> clients,
  List<ScheduleSession> sessions,
) {
  final booked =
      sessions.where((session) => !session.isGap && session.isUpcoming).toList()
        ..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.time.compareTo(b.time);
        });

  final nameCounts = <String, int>{};
  for (final client in clients) {
    final name = client.name.trim().toLowerCase();
    if (name.isNotEmpty) {
      nameCounts.update(name, (count) => count + 1, ifAbsent: () => 1);
    }
  }

  final result = <String, ScheduleSession>{};
  for (final client in clients) {
    final name = client.name.trim().toLowerCase();
    final canMatchLegacyName = name.isNotEmpty && nameCounts[name] == 1;
    for (final session in booked) {
      final matches =
          session.clientId == client.id ||
          (session.clientId == null &&
              canMatchLegacyName &&
              session.clientName.trim().toLowerCase() == name);
      if (matches) {
        result[client.id] = session;
        break;
      }
    }
  }
  return result;
}

/// 현재 탭과 무관하게 동일하게 표시되는 고객·기록 통합 요약입니다.
String clientSearchDetail(
  AppLocalizations l,
  TrainerClient client,
  ClientSearchFacts facts,
) {
  final details = <String>[];
  final unread = facts.unread[client.id] ?? 0;
  if (unread > 0) {
    details.add(l.searchDetailUnread(unread));
  } else if (client.lastMessage.trim().isNotEmpty &&
      client.lastMessage != '-') {
    details.add(l.searchDetailMessage(client.lastMessage, client.lastTime));
  }

  final next = facts.nextSession[client.id];
  if (next != null) {
    final day = DateTime.tryParse(next.date);
    details.add(
      l.searchDetailNextSession(
        day == null ? next.date : dateLabel(l, day),
        next.time,
      ),
    );
  }

  final lastRoutine = client.lastRoutine.trim();
  if (lastRoutine.isNotEmpty && lastRoutine != '-') {
    details.add(l.searchDetailLastRoutine(lastRoutine));
  }

  final completion = recordedCompletionMean(client);
  if (completion != null) {
    details.add(l.searchDetailCompletion(completion.round()));
  }

  if (details.isEmpty) return client.goal;
  return details.join(' · ');
}

/// 결과 행을 직접 선택했을 때의 일관된 기본 이동 경로입니다.
String clientSearchDestination(TrainerClient client) =>
    AppRoutes.clientDetail(client.id);
