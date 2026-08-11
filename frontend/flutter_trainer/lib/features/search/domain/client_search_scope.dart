import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// Which tab the 고객 검색 bar is sitting on.
///
/// The bar is the same control everywhere, but "고객" means something
/// different on each tab: 스케줄 is asking when they're next in, AI 코칭
/// is asking what they were last given, 리포트 is asking how their week
/// went. So the scope decides **both** halves of a result row — the fact
/// shown under the name, and where picking it goes.
///
/// Only the five nav destinations have one. 내 정보 is settings, and
/// 상담 요청 is about people who are not clients yet, so a client picker
/// there would be a dead end.
enum ClientSearchScope {
  /// 대시보드 — no per-client surface of its own, so it reports what
  /// needs doing and hands off to the 고객 detail.
  dashboard,

  /// 고객 — the roster; picking keeps whichever sub-tab is open.
  clients,

  /// 스케줄 — when is this person next in?
  schedule,

  /// AI 코칭 — what have they been given?
  coaching,

  /// 리포트 — how is their week going?
  reports,
}

/// The tab-specific data a result row needs beyond the client itself.
///
/// Gathered once per keystroke by the search bar and passed down, so a
/// six-row dropdown doesn't open six subscriptions. Empty by default:
/// with no query typed there is nothing to describe, and the streams
/// stay unwatched.
class ClientSearchFacts {
  /// Creates the fact set for one render.
  const ClientSearchFacts({
    this.unread = const <String, int>{},
    this.nextSession = const <String, ScheduleSession>{},
  });

  /// Unread message count per client id (대시보드 / 고객).
  final Map<String, int> unread;

  /// Each client's next booked session, by client id (스케줄).
  final Map<String, ScheduleSession> nextSession;

  /// Nothing gathered — the state before a query is typed.
  static const ClientSearchFacts none = ClientSearchFacts();
}

/// How far ahead [nextSessionsByClient] looks for a 다음 예약.
///
/// A bounded window keeps this to one range query. Nothing booked
/// within it reads as "예정된 예약 없음", which is why the message says
/// 4주 rather than claiming the client has no bookings at all.
const int clientSearchUpcomingDays = 28;

/// Each client's next booked session, keyed by client id.
///
/// Sessions are matched by id, falling back to the normalised display
/// name for rows stored before sessions carried one (#386) — the same
/// rule the schedule repository's `watchClientSessions` uses, so the
/// search bar and the client's own 운동 tab can't disagree about who a
/// booking belongs to.
Map<String, ScheduleSession> nextSessionsByClient(
  List<TrainerClient> clients,
  List<ScheduleSession> sessions,
) {
  final booked = sessions.where((s) => !s.isGap && s.isUpcoming).toList()
    // `YYYY-MM-DD` and `HH:MM` both sort lexicographically, so the
    // earliest booking is simply the first one after this sort.
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

  final out = <String, ScheduleSession>{};
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
        out[client.id] = session;
        break;
      }
    }
  }
  return out;
}

/// The line under a result's name: the one fact this tab is about.
String clientSearchDetail(
  AppLocalizations l,
  ClientSearchScope scope,
  TrainerClient client,
  ClientSearchFacts facts,
) {
  final unread = facts.unread[client.id] ?? 0;
  switch (scope) {
    case ClientSearchScope.dashboard:
      // The dashboard's whole question is "who needs me today", so the
      // row answers it with the same alerts the 오늘 챙길 고객 list uses.
      final alerts = alertsFor(client, unread: unread);
      if (alerts.isEmpty) return l.searchDetailNoIssues;
      return alerts.map((a) => a.label(l)).join(' · ');
    case ClientSearchScope.clients:
      if (unread > 0) return l.searchDetailUnread(unread);
      return l.searchDetailMessage(client.lastMessage, client.lastTime);
    case ClientSearchScope.schedule:
      final next = facts.nextSession[client.id];
      if (next == null) return l.searchDetailNoUpcoming;
      final day = DateTime.tryParse(next.date);
      return l.searchDetailNextSession(
        day == null ? next.date : dateLabel(l, day),
        next.time,
      );
    case ClientSearchScope.coaching:
      final last = client.lastRoutine.trim();
      if (last.isEmpty || last == '-') return l.searchDetailNoRoutine;
      return l.searchDetailLastRoutine(last);
    case ClientSearchScope.reports:
      final mean = recordedCompletionMean(client);
      if (mean == null) return l.searchDetailNoRecord;
      return l.searchDetailCompletion(mean.round());
  }
}

/// The dropdown's footer — what picking a result will do. It changes
/// with the tab, so the trainer shouldn't have to try it to find out.
String clientSearchFooter(AppLocalizations l, ClientSearchScope scope) =>
    switch (scope) {
      ClientSearchScope.dashboard ||
      ClientSearchScope.clients => l.searchGoClientDetail,
      ClientSearchScope.schedule => l.searchGoSchedule,
      ClientSearchScope.coaching => l.searchGoCoaching,
      ClientSearchScope.reports => l.searchGoReport,
    };

/// The route picking [client] should open from this tab.
///
/// A schedule result without an upcoming booking falls back to the client
/// detail. Global client search should always lead somewhere useful; the
/// schedule quick action itself remains unavailable when there is no date.
///
/// [clientSection] is the 고객 sub-tab currently open; searching from
/// 운동 lands on the next client's 운동 rather than resetting to 식단.
/// 채팅만은 이어받지 않는다 — 스레드를 여는 순간 읽음 처리되므로, 검색으로
/// 지나가기만 해도 그 회원의 답장 대기 배지가 지워진다
/// ([AppRoutes.defaultClientSection] 주석과 같은 이유).
String clientSearchDestination(
  ClientSearchScope scope,
  TrainerClient client,
  ClientSearchFacts facts, {
  String? clientSection,
}) {
  switch (scope) {
    case ClientSearchScope.dashboard:
      return AppRoutes.clientDetail(client.id);
    case ClientSearchScope.clients:
      final section = clientSection == AppRoutes.clientChatSection
          ? null
          : clientSection;
      return AppRoutes.clientDetail(client.id, section: section);
    case ClientSearchScope.schedule:
      final next = facts.nextSession[client.id];
      if (next == null) return AppRoutes.clientDetail(client.id);
      return AppRoutes.scheduleView('day', date: next.date);
    case ClientSearchScope.coaching:
      return AppRoutes.coachingFor(client.id);
    case ClientSearchScope.reports:
      return AppRoutes.reportFor(client.id);
  }
}
