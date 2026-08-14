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

/// 통합 검색 결과를 현재 탭의 고객 화면으로 연결합니다.
///
/// 검색 대상과 결과 데이터는 모든 탭에서 동일하지만, 선택한 고객을 여는
/// 위치는 현재 작업 흐름을 유지합니다. 고객 탭에서는 읽던 상세 섹션을
/// 보존하고, 일정 탭에서는 고객의 다음 예약 날짜를 엽니다. 고객 단위
/// 화면이 없는 대시보드와 다음 예약이 없는 일정만 고객 상세로 보냅니다.
String clientSearchDestination(
  Uri location,
  TrainerClient client,
  ClientSearchFacts facts,
) {
  final tab = location.pathSegments.firstOrNull;
  switch (tab) {
    case 'clients':
      final currentSection = location.pathSegments.length >= 3
          ? location.pathSegments[2]
          : null;
      final section = currentSection == AppRoutes.clientChatSection
          ? null
          : currentSection;
      return AppRoutes.clientDetail(client.id, section: section);
    case 'schedule':
      final next = facts.nextSession[client.id];
      return next == null
          ? AppRoutes.clientDetail(client.id)
          : AppRoutes.scheduleView('day', date: next.date);
    case 'messages':
      return AppRoutes.messagesFor(
        client.id,
        filter: location.queryParameters['f'],
      );
    case 'coaching':
      return AppRoutes.coachingFor(client.id);
    case 'reports':
      return AppRoutes.reportFor(client.id);
    default:
      return AppRoutes.clientDetail(client.id);
  }
}

/// Enter 또는 결과 행 선택이 어느 화면을 여는지 안내하는 문구입니다.
String clientSearchFooter(AppLocalizations l, Uri location) {
  return switch (location.pathSegments.firstOrNull) {
    'schedule' => l.searchGoSchedule,
    'messages' => l.navMessages,
    'coaching' => l.searchGoCoaching,
    'reports' => l.searchGoReport,
    _ => l.searchGoClientDetail,
  };
}
