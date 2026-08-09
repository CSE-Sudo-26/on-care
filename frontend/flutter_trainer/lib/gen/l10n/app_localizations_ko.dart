// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'On-Care 트레이너';

  @override
  String get scheduleStatusUpcoming => '예정';

  @override
  String get scheduleStatusDone => '완료';

  @override
  String get scheduleStatusGap => '공백';

  @override
  String get sessionTypePersonalTraining => '1:1 PT';

  @override
  String get sessionTypeConsultation => '상담';

  @override
  String get navDashboard => '대시보드';

  @override
  String get navClients => '고객';

  @override
  String get navSchedule => '일정';

  @override
  String get navCoaching => '코칭';

  @override
  String get navReports => '리포트';

  @override
  String get navConsultations => '상담 요청';

  @override
  String get navMy => '내 정보';

  @override
  String get actionSave => '저장';

  @override
  String get actionCancel => '취소';

  @override
  String get actionEdit => '수정';

  @override
  String get actionDelete => '삭제';

  @override
  String get actionClose => '닫기';

  @override
  String get actionConfirm => '확인';

  @override
  String get actionSend => '보내기';

  @override
  String get actionRetry => '다시 시도';

  @override
  String get actionChange => '변경';

  @override
  String get appWordmarkTrainer => '트레이너';

  @override
  String get appAvatarFallback => '트';

  @override
  String sidebarMyTooltip(String name) {
    return '$name · 내 정보';
  }
}
