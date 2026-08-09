// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'On-Care Trainer';

  @override
  String get scheduleStatusUpcoming => 'Upcoming';

  @override
  String get scheduleStatusDone => 'Done';

  @override
  String get scheduleStatusGap => 'Open';

  @override
  String get sessionTypePersonalTraining => '1:1 PT';

  @override
  String get sessionTypeConsultation => 'Consultation';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navClients => 'Clients';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navCoaching => 'Coaching';

  @override
  String get navReports => 'Reports';

  @override
  String get navConsultations => 'Requests';

  @override
  String get navMy => 'My page';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionClose => 'Close';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionSend => 'Send';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionChange => 'Change';

  @override
  String get appWordmarkTrainer => 'Trainer';

  @override
  String get appAvatarFallback => 'T';

  @override
  String sidebarMyTooltip(String name) {
    return '$name · My page';
  }
}
