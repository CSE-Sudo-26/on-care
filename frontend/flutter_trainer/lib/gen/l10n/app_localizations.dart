import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// Trainer app title shown in the OS task switcher and browser tab.
  ///
  /// In en, this message translates to:
  /// **'On-Care Trainer'**
  String get appTitle;

  /// Display label for a scheduled session. The stored value stays Korean — see ScheduleStatus.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get scheduleStatusUpcoming;

  /// Display label for a completed session.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get scheduleStatusDone;

  /// Display label for an empty slot in the trainer's day.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get scheduleStatusGap;

  /// Display label for a personal training session.
  ///
  /// In en, this message translates to:
  /// **'1:1 PT'**
  String get sessionTypePersonalTraining;

  /// Display label for a consultation session.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get sessionTypeConsultation;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get navClients;

  /// No description provided for @navSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navSchedule;

  /// No description provided for @navCoaching.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get navCoaching;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navConsultations.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get navConsultations;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// Second word of the sidebar wordmark, rendered in the navy primary next to 'On-Care'.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get appWordmarkTrainer;

  /// Single-character avatar shown when the trainer has no name yet. Keep it one character.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get appAvatarFallback;

  /// Tooltip on the collapsed sidebar's profile avatar.
  ///
  /// In en, this message translates to:
  /// **'{name} · My page'**
  String sidebarMyTooltip(String name);

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'The trainer-only app for managing your clients'**
  String get authTagline;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUp;

  /// No description provided for @authBrowseDemo.
  ///
  /// In en, this message translates to:
  /// **'Explore the demo without signing in'**
  String get authBrowseDemo;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authContinueKakao.
  ///
  /// In en, this message translates to:
  /// **'Continue with Kakao'**
  String get authContinueKakao;

  /// No description provided for @authContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueGoogle;

  /// No description provided for @authSignUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an On-Care account and start managing clients'**
  String get authSignUpSubtitle;

  /// No description provided for @authName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get authName;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password (8+ characters)'**
  String get authPasswordHint;

  /// No description provided for @authPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authPasswordConfirm;

  /// No description provided for @authInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Gym invite code'**
  String get authInviteCode;

  /// No description provided for @authInviteCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the code issued by the gym you work at.'**
  String get authInviteCodeHelp;

  /// No description provided for @authSignUpAndStart.
  ///
  /// In en, this message translates to:
  /// **'Sign up and start'**
  String get authSignUpAndStart;

  /// No description provided for @authHasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHasAccount;

  /// No description provided for @authErrEmptyCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password'**
  String get authErrEmptyCredentials;

  /// No description provided for @authErrSocialFailed.
  ///
  /// In en, this message translates to:
  /// **'Social sign-in failed. Please try again in a moment.'**
  String get authErrSocialFailed;

  /// No description provided for @authErrSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again in a moment.'**
  String get authErrSignInFailed;

  /// No description provided for @authErrPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authErrPasswordTooShort;

  /// No description provided for @authErrPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get authErrPasswordMismatch;

  /// No description provided for @authErrInviteCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code you received from your gym'**
  String get authErrInviteCodeRequired;

  /// No description provided for @authErrSignUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-up failed. Please try again in a moment.'**
  String get authErrSignUpFailed;

  /// No description provided for @dashTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashTitle;

  /// No description provided for @dashAddSchedule.
  ///
  /// In en, this message translates to:
  /// **'Add session'**
  String get dashAddSchedule;

  /// No description provided for @dashCreateAiRoutine.
  ///
  /// In en, this message translates to:
  /// **'Create AI routine'**
  String get dashCreateAiRoutine;

  /// No description provided for @dashLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the dashboard'**
  String get dashLoadFailed;

  /// No description provided for @dashTodayReservations.
  ///
  /// In en, this message translates to:
  /// **'Today\'s bookings'**
  String get dashTodayReservations;

  /// Unit after a booking count. Korean uses the counter 건; English omits it because the tile label already says what is being counted. Intentionally empty.
  ///
  /// In en, this message translates to:
  /// **''**
  String get dashUnitCount;

  /// Unit after a person count. Korean uses the counter 명; English omits it. Intentionally empty.
  ///
  /// In en, this message translates to:
  /// **''**
  String get dashUnitPeople;

  /// No description provided for @dashSeeInSchedule.
  ///
  /// In en, this message translates to:
  /// **'View in schedule'**
  String get dashSeeInSchedule;

  /// No description provided for @dashMyClients.
  ///
  /// In en, this message translates to:
  /// **'My clients'**
  String get dashMyClients;

  /// No description provided for @dashDormantClients.
  ///
  /// In en, this message translates to:
  /// **'{count} dormant'**
  String dashDormantClients(int count);

  /// No description provided for @dashAllActive.
  ///
  /// In en, this message translates to:
  /// **'All active'**
  String get dashAllActive;

  /// No description provided for @dashNeedsReply.
  ///
  /// In en, this message translates to:
  /// **'Awaiting reply'**
  String get dashNeedsReply;

  /// No description provided for @dashWaitingClients.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String dashWaitingClients(int count);

  /// No description provided for @dashAllReplied.
  ///
  /// In en, this message translates to:
  /// **'All replied'**
  String get dashAllReplied;

  /// No description provided for @dashAttentionClients.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get dashAttentionClients;

  /// No description provided for @dashNoIssues.
  ///
  /// In en, this message translates to:
  /// **'No issues'**
  String get dashNoIssues;

  /// No description provided for @dashCheckSodiumCompletion.
  ///
  /// In en, this message translates to:
  /// **'Check sodium & completion'**
  String get dashCheckSodiumCompletion;

  /// No description provided for @dashWeeklyCompletion.
  ///
  /// In en, this message translates to:
  /// **'Weekly session completion'**
  String get dashWeeklyCompletion;

  /// No description provided for @dashAveragePercent.
  ///
  /// In en, this message translates to:
  /// **'Avg {percent}%'**
  String dashAveragePercent(int percent);

  /// No description provided for @dashNoRecordsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No records this week yet'**
  String get dashNoRecordsThisWeek;

  /// No description provided for @dashAiSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'AI coaching summary'**
  String get dashAiSummaryTitle;

  /// No description provided for @dashToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashToday;

  /// No description provided for @dashAiNoClients.
  ///
  /// In en, this message translates to:
  /// **'No clients yet. Once you add one, I\'ll gather their diet and workout data and point out what to coach.'**
  String get dashAiNoClients;

  /// No description provided for @dashAiUnread.
  ///
  /// In en, this message translates to:
  /// **'{count} clients are waiting for a reply. Check their chats first, then adjust today\'s routines.'**
  String dashAiUnread(int count);

  /// No description provided for @dashAiSodium.
  ///
  /// In en, this message translates to:
  /// **'{over} of your {total} clients went over their sodium target this week. Suggest a low-sodium diet and cardio-led routines.'**
  String dashAiSodium(int total, int over);

  /// No description provided for @dashAiLowCompletion.
  ///
  /// In en, this message translates to:
  /// **'{count} clients are below {threshold}% weekly completion. Ease the intensity and rebuild the habit.'**
  String dashAiLowCompletion(int count, int threshold);

  /// No description provided for @dashAiAllOnTrack.
  ///
  /// In en, this message translates to:
  /// **'All {total} clients are within target. Hold this intensity and raise next week\'s goal.'**
  String dashAiAllOnTrack(int total);

  /// No description provided for @dashAttentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Clients to check'**
  String get dashAttentionTitle;

  /// No description provided for @dashMoreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String dashMoreCount(int count);

  /// No description provided for @dashNoAttention.
  ///
  /// In en, this message translates to:
  /// **'No one needs attention right now'**
  String get dashNoAttention;

  /// No description provided for @dashTodaySchedule.
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule'**
  String get dashTodaySchedule;

  /// No description provided for @dashSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get dashSeeAll;

  /// No description provided for @dashScheduleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the schedule'**
  String get dashScheduleLoadFailed;

  /// No description provided for @dashNoScheduleToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled today'**
  String get dashNoScheduleToday;

  /// No description provided for @dashEmptySlot.
  ///
  /// In en, this message translates to:
  /// **'Open slot'**
  String get dashEmptySlot;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @clientsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load client data'**
  String get clientsLoadFailed;

  /// No description provided for @clientsCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{total} clients · {active} active'**
  String clientsCountSummary(int total, int active);

  /// No description provided for @clientsNew.
  ///
  /// In en, this message translates to:
  /// **'New client'**
  String get clientsNew;

  /// No description provided for @clientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Member management'**
  String get clientsTitle;

  /// No description provided for @clientsManagementAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get clientsManagementAttention;

  /// No description provided for @clientsSortPriority.
  ///
  /// In en, this message translates to:
  /// **'Sort: priority'**
  String get clientsSortPriority;

  /// No description provided for @clientsSortName.
  ///
  /// In en, this message translates to:
  /// **'Sort: name'**
  String get clientsSortName;

  /// No description provided for @clientsToolbarCount.
  ///
  /// In en, this message translates to:
  /// **'{shown} members · {active} active'**
  String clientsToolbarCount(int shown, int active);

  /// No description provided for @clientsPickHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a client on the left to open\ntheir chat, meals and workouts here'**
  String get clientsPickHint;

  /// No description provided for @clientsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No clients yet'**
  String get clientsEmpty;

  /// No description provided for @clientsEmptyForFilter.
  ///
  /// In en, this message translates to:
  /// **'No clients match {filter}'**
  String clientsEmptyForFilter(String filter);

  /// No description provided for @clientsFilterSummary.
  ///
  /// In en, this message translates to:
  /// **'{filter} · {shown}/{total}'**
  String clientsFilterSummary(String filter, int shown, int total);

  /// No description provided for @clientsSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get clientsSeeAll;

  /// No description provided for @clientsNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get clientsNameRequired;

  /// No description provided for @clientsAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the client. Please try again'**
  String get clientsAddFailed;

  /// No description provided for @memberHealthLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the member profile. Please try again'**
  String get memberHealthLoadFailed;

  /// No description provided for @memberHealthSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the member profile. Please try again'**
  String get memberHealthSaveFailed;

  /// No description provided for @clientsDuplicateName.
  ///
  /// In en, this message translates to:
  /// **'A client with that name already exists'**
  String get clientsDuplicateName;

  /// No description provided for @clientsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a client'**
  String get clientsAddTitle;

  /// No description provided for @clientsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Client name'**
  String get clientsNameLabel;

  /// No description provided for @clientsGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal (e.g. weight loss · strength)'**
  String get clientsGoalLabel;

  /// No description provided for @clientsAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get clientsAddAction;

  /// No description provided for @clientTabDiet.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get clientTabDiet;

  /// No description provided for @clientTabWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get clientTabWorkout;

  /// No description provided for @clientNotFound.
  ///
  /// In en, this message translates to:
  /// **'Client not found'**
  String get clientNotFound;

  /// No description provided for @clientBackToList.
  ///
  /// In en, this message translates to:
  /// **'Back to clients'**
  String get clientBackToList;

  /// No description provided for @clientList.
  ///
  /// In en, this message translates to:
  /// **'Client list'**
  String get clientList;

  /// No description provided for @metricCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get metricCalories;

  /// No description provided for @metricSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium'**
  String get metricSodium;

  /// No description provided for @metricSugar.
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get metricSugar;

  /// No description provided for @metricCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get metricCarbs;

  /// No description provided for @metricProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get metricProtein;

  /// No description provided for @metricFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get metricFat;

  /// No description provided for @clientWeeklyReport.
  ///
  /// In en, this message translates to:
  /// **'Weekly report'**
  String get clientWeeklyReport;

  /// No description provided for @clientAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get clientAskAi;

  /// No description provided for @clientActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get clientActive;

  /// No description provided for @clientDormant.
  ///
  /// In en, this message translates to:
  /// **'Dormant'**
  String get clientDormant;

  /// No description provided for @clientClosePanel.
  ///
  /// In en, this message translates to:
  /// **'Close panel'**
  String get clientClosePanel;

  /// No description provided for @clientChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get clientChat;

  /// No description provided for @clientChatWithUnread.
  ///
  /// In en, this message translates to:
  /// **'Chat with {name}, {count} unread'**
  String clientChatWithUnread(String name, int count);

  /// No description provided for @clientChatWith.
  ///
  /// In en, this message translates to:
  /// **'Chat with {name}'**
  String clientChatWith(String name);

  /// No description provided for @chatTooLong.
  ///
  /// In en, this message translates to:
  /// **'Message is too long (2000 characters max)'**
  String get chatTooLong;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the message. Please try again'**
  String get chatSendFailed;

  /// No description provided for @chatLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the conversation'**
  String get chatLoadFailed;

  /// No description provided for @chatDemoAnalyzed.
  ///
  /// In en, this message translates to:
  /// **'AI analysed {name}\'s meals and workouts'**
  String chatDemoAnalyzed(String name);

  /// No description provided for @chatDemoReportSent.
  ///
  /// In en, this message translates to:
  /// **'A summary report was sent to you'**
  String get chatDemoReportSent;

  /// No description provided for @chatDemoRoutineSent.
  ///
  /// In en, this message translates to:
  /// **'An AI-built routine was sent to {name}'**
  String chatDemoRoutineSent(String name);

  /// No description provided for @chatDemoNotified.
  ///
  /// In en, this message translates to:
  /// **'The client app was notified'**
  String get chatDemoNotified;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatInputHint;

  /// No description provided for @chatInsightDiscomfortTitle.
  ///
  /// In en, this message translates to:
  /// **'{part} discomfort detected'**
  String chatInsightDiscomfortTitle(String part);

  /// No description provided for @chatInsightBodyPartGeneral.
  ///
  /// In en, this message translates to:
  /// **'Physical'**
  String get chatInsightBodyPartGeneral;

  /// No description provided for @chatInsightNegativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Negative feedback detected'**
  String get chatInsightNegativeTitle;

  /// No description provided for @chatInsightDiscomfortDescription.
  ///
  /// In en, this message translates to:
  /// **'AI detected a report of discomfort. Check the symptoms and consider adjusting the next workout\'s intensity.'**
  String get chatInsightDiscomfortDescription;

  /// No description provided for @chatInsightNegativeDescription.
  ///
  /// In en, this message translates to:
  /// **'AI detected workout strain or difficulty completing the plan. Check the cause and consider adjusting the routine.'**
  String get chatInsightNegativeDescription;

  /// No description provided for @chatInsightAddMemo.
  ///
  /// In en, this message translates to:
  /// **'Add to memo'**
  String get chatInsightAddMemo;

  /// No description provided for @chatInsightMemoAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to memo'**
  String get chatInsightMemoAdded;

  /// No description provided for @chatInsightMemoSaved.
  ///
  /// In en, this message translates to:
  /// **'The AI insight was added to the trainer memo.'**
  String get chatInsightMemoSaved;

  /// No description provided for @coachSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Coaching for {name}'**
  String coachSheetTitle(String name);

  /// No description provided for @coachSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Answers are grounded in this client\'s meals and workouts.'**
  String get coachSheetSubtitle;

  /// No description provided for @coachSheetHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sodium keeps running high — what meals should I suggest?'**
  String get coachSheetHint;

  /// No description provided for @coachSheetSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get coachSheetSources;

  /// No description provided for @coachSheetAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get coachSheetAsk;

  /// No description provided for @coachSheetAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Ask again'**
  String get coachSheetAskAgain;

  /// No description provided for @consultTitle.
  ///
  /// In en, this message translates to:
  /// **'Consultation requests'**
  String get consultTitle;

  /// No description provided for @consultPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String consultPendingCount(int count);

  /// No description provided for @consultNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get consultNoPending;

  /// No description provided for @consultShowAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get consultShowAll;

  /// No description provided for @consultShowPending.
  ///
  /// In en, this message translates to:
  /// **'Pending only'**
  String get consultShowPending;

  /// No description provided for @consultLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load consultation requests'**
  String get consultLoadFailed;

  /// No description provided for @consultRetryLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment'**
  String get consultRetryLater;

  /// No description provided for @consultEmptyPending.
  ///
  /// In en, this message translates to:
  /// **'No pending consultation requests'**
  String get consultEmptyPending;

  /// No description provided for @consultEmptyHistory.
  ///
  /// In en, this message translates to:
  /// **'No consultation history'**
  String get consultEmptyHistory;

  /// No description provided for @consultEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Requests appear here when a member asks for a consultation with your gym or with you'**
  String get consultEmptyHint;

  /// No description provided for @consultActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t process the request'**
  String get consultActionFailed;

  /// No description provided for @consultApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} is now one of your clients'**
  String consultApproved(String name);

  /// No description provided for @consultRejected.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get consultRejected;

  /// No description provided for @consultTargetGym.
  ///
  /// In en, this message translates to:
  /// **'Gym enquiry'**
  String get consultTargetGym;

  /// No description provided for @consultTargetTrainer.
  ///
  /// In en, this message translates to:
  /// **'Direct request'**
  String get consultTargetTrainer;

  /// No description provided for @consultExerciseGoal.
  ///
  /// In en, this message translates to:
  /// **'Training goal'**
  String get consultExerciseGoal;

  /// No description provided for @consultHealthPurpose.
  ///
  /// In en, this message translates to:
  /// **'Health purpose'**
  String get consultHealthPurpose;

  /// No description provided for @consultPreferredTime.
  ///
  /// In en, this message translates to:
  /// **'Preferred time'**
  String get consultPreferredTime;

  /// No description provided for @consultGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get consultGym;

  /// No description provided for @consultReject.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get consultReject;

  /// No description provided for @consultApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get consultApprove;

  /// No description provided for @consultRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline request'**
  String get consultRejectTitle;

  /// No description provided for @consultRejectNotice.
  ///
  /// In en, this message translates to:
  /// **'The reason you write is sent to the member as a notification.'**
  String get consultRejectNotice;

  /// No description provided for @consultRejectHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. We\'re fully booked this month'**
  String get consultRejectHint;

  /// No description provided for @consultRejectAction.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get consultRejectAction;

  /// No description provided for @consultStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Added as a client'**
  String get consultStatusApproved;

  /// No description provided for @workoutRecords.
  ///
  /// In en, this message translates to:
  /// **'Workout log'**
  String get workoutRecords;

  /// No description provided for @workoutLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the workout log'**
  String get workoutLoadFailed;

  /// No description provided for @workoutEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workouts logged yet'**
  String get workoutEmpty;

  /// No description provided for @routinesAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned routines'**
  String get routinesAssigned;

  /// No description provided for @routineNew.
  ///
  /// In en, this message translates to:
  /// **'New routine'**
  String get routineNew;

  /// No description provided for @routinesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load routines'**
  String get routinesLoadFailed;

  /// No description provided for @routinesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No routines assigned to this client yet'**
  String get routinesEmpty;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @ptProgramHistory.
  ///
  /// In en, this message translates to:
  /// **'PT program history'**
  String get ptProgramHistory;

  /// No description provided for @scheduleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the schedule'**
  String get scheduleLoadFailed;

  /// No description provided for @ptSessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No PT sessions yet'**
  String get ptSessionsEmpty;

  /// No description provided for @labelToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get labelToday;

  /// No description provided for @sessionTypeAndDuration.
  ///
  /// In en, this message translates to:
  /// **'{type} · {minutes} min'**
  String sessionTypeAndDuration(String type, int minutes);

  /// No description provided for @programNone.
  ///
  /// In en, this message translates to:
  /// **'No program recorded'**
  String get programNone;

  /// No description provided for @weekCompletionRate.
  ///
  /// In en, this message translates to:
  /// **'This week\'s completion'**
  String get weekCompletionRate;

  /// No description provided for @legendDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get legendDone;

  /// No description provided for @legendPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get legendPartial;

  /// No description provided for @legendMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get legendMissed;

  /// No description provided for @clientFeedback.
  ///
  /// In en, this message translates to:
  /// **'Client feedback'**
  String get clientFeedback;

  /// No description provided for @trainerNote.
  ///
  /// In en, this message translates to:
  /// **'Trainer\'s note'**
  String get trainerNote;

  /// No description provided for @dietLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load meals'**
  String get dietLoadFailed;

  /// No description provided for @dietEmpty.
  ///
  /// In en, this message translates to:
  /// **'No meals logged yet'**
  String get dietEmpty;

  /// No description provided for @dietTodaySummary.
  ///
  /// In en, this message translates to:
  /// **'Today\'s nutrition'**
  String get dietTodaySummary;

  /// No description provided for @dietAchieveRate.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get dietAchieveRate;

  /// No description provided for @dietAmountOver.
  ///
  /// In en, this message translates to:
  /// **'{amount} over the goal'**
  String dietAmountOver(String amount);

  /// No description provided for @dietAmountRemaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} remaining to the goal'**
  String dietAmountRemaining(String amount);

  /// No description provided for @dietSodiumTrend.
  ///
  /// In en, this message translates to:
  /// **'Sodium over the last 7 days'**
  String get dietSodiumTrend;

  /// No description provided for @dietAverageMg.
  ///
  /// In en, this message translates to:
  /// **'Avg {value}mg'**
  String dietAverageMg(int value);

  /// No description provided for @dietSodiumOverDays.
  ///
  /// In en, this message translates to:
  /// **'Over the {target}mg target on {days} of the last 7 days.'**
  String dietSodiumOverDays(int days, int target);

  /// No description provided for @dietSodiumAllWithin.
  ///
  /// In en, this message translates to:
  /// **'Under the {target}mg target every day this week. Nice!'**
  String dietSodiumAllWithin(int target);

  /// No description provided for @dietSodiumValue.
  ///
  /// In en, this message translates to:
  /// **'Sodium {value}mg'**
  String dietSodiumValue(int value);

  /// No description provided for @dietAiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'AI analysis'**
  String get dietAiAnalysis;

  /// No description provided for @dietAiOverSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium is {over}mg over target. Adding cardio to today\'s routine would help.'**
  String dietAiOverSodium(int over);

  /// No description provided for @dietAiBalanced.
  ///
  /// In en, this message translates to:
  /// **'Today\'s meals are well balanced. Keep the current routine.'**
  String get dietAiBalanced;

  /// No description provided for @consultStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get consultStatusRejected;

  /// No description provided for @consultStatusRejectedWithNote.
  ///
  /// In en, this message translates to:
  /// **'Declined · {note}'**
  String consultStatusRejectedWithNote(String note);

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// No description provided for @dateTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dateTomorrow;

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// No description provided for @dateMonthDayWeekday.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day} ({weekday})'**
  String dateMonthDayWeekday(int month, int day, String weekday);

  /// No description provided for @datePrefixed.
  ///
  /// In en, this message translates to:
  /// **'{prefix} · {date}'**
  String datePrefixed(String prefix, String date);

  /// No description provided for @dateMonthDay.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}'**
  String dateMonthDay(int month, int day);

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String dateRange(String start, String end);

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Summarize this week\'s changes and prepare a report to share'**
  String get reportsSubtitle;

  /// No description provided for @reportsPrevWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get reportsPrevWeek;

  /// No description provided for @reportsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load reports'**
  String get reportsLoadFailed;

  /// No description provided for @reportsNoClients.
  ///
  /// In en, this message translates to:
  /// **'No clients yet, so there\'s nothing to report on'**
  String get reportsNoClients;

  /// No description provided for @reportsWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly report'**
  String get reportsWeekly;

  /// No description provided for @reportsSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the report. Please try again'**
  String get reportsSendFailed;

  /// No description provided for @reportsSent.
  ///
  /// In en, this message translates to:
  /// **'Report sent to {name}'**
  String reportsSent(String name);

  /// No description provided for @reportsScheduleWarning.
  ///
  /// In en, this message translates to:
  /// **'This week\'s schedule didn\'t load, so session counts may be missing'**
  String get reportsScheduleWarning;

  /// No description provided for @reportsSessionsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Sessions this week'**
  String get reportsSessionsThisWeek;

  /// No description provided for @unitTimes.
  ///
  /// In en, this message translates to:
  /// **''**
  String get unitTimes;

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get unitDays;

  /// No description provided for @reportsCompletionRate.
  ///
  /// In en, this message translates to:
  /// **'{rate}% completed'**
  String reportsCompletionRate(int rate);

  /// No description provided for @reportsProgramReady.
  ///
  /// In en, this message translates to:
  /// **'Programs ready'**
  String get reportsProgramReady;

  /// No description provided for @reportsSessionsWithRoutine.
  ///
  /// In en, this message translates to:
  /// **'Sessions with a routine'**
  String get reportsSessionsWithRoutine;

  /// No description provided for @reportsActiveClients.
  ///
  /// In en, this message translates to:
  /// **'Active clients'**
  String get reportsActiveClients;

  /// No description provided for @reportsPickClient.
  ///
  /// In en, this message translates to:
  /// **'Pick a client'**
  String get reportsPickClient;

  /// No description provided for @reportsClientWeekly.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s weekly report'**
  String reportsClientWeekly(String name);

  /// No description provided for @reportsPtSessions.
  ///
  /// In en, this message translates to:
  /// **'PT sessions'**
  String get reportsPtSessions;

  /// No description provided for @reportsCompletionAvg.
  ///
  /// In en, this message translates to:
  /// **'Workout completion'**
  String get reportsCompletionAvg;

  /// No description provided for @reportsSodiumOver.
  ///
  /// In en, this message translates to:
  /// **'Sodium over target'**
  String get reportsSodiumOver;

  /// No description provided for @reportsCompletionByDay.
  ///
  /// In en, this message translates to:
  /// **'Completion by day'**
  String get reportsCompletionByDay;

  /// No description provided for @reportsNoLastWeekDaily.
  ///
  /// In en, this message translates to:
  /// **'No daily records for last week yet'**
  String get reportsNoLastWeekDaily;

  /// No description provided for @reportsNoWorkoutsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No workouts logged this week'**
  String get reportsNoWorkoutsThisWeek;

  /// No description provided for @reportsSodiumTrend.
  ///
  /// In en, this message translates to:
  /// **'Sodium trend'**
  String get reportsSodiumTrend;

  /// No description provided for @reportsNoLastWeekSodium.
  ///
  /// In en, this message translates to:
  /// **'No sodium trend for last week yet'**
  String get reportsNoLastWeekSodium;

  /// No description provided for @reportsSendStateSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get reportsSendStateSent;

  /// No description provided for @reportsSendStateSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get reportsSendStateSending;

  /// No description provided for @reportsSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send to client'**
  String get reportsSendAction;

  /// No description provided for @reportBodyTitle.
  ///
  /// In en, this message translates to:
  /// **'📊 Weekly report · {range}'**
  String reportBodyTitle(String range);

  /// No description provided for @reportBodySessions.
  ///
  /// In en, this message translates to:
  /// **'PT sessions: {done}/{booked} completed'**
  String reportBodySessions(int done, int booked);

  /// No description provided for @reportBodyCompletion.
  ///
  /// In en, this message translates to:
  /// **'Average workout completion: {avg}%'**
  String reportBodyCompletion(int avg);

  /// No description provided for @reportBodySodium.
  ///
  /// In en, this message translates to:
  /// **'Average sodium: {avg}mg · over target on {days} days'**
  String reportBodySodium(int avg, int days);

  /// No description provided for @reportBodyPraise.
  ///
  /// In en, this message translates to:
  /// **'Great week — let\'s keep this pace next week!'**
  String get reportBodyPraise;

  /// No description provided for @reportBodyEncourage.
  ///
  /// In en, this message translates to:
  /// **'Let\'s tighten things up next week. I\'ll adjust your routine.'**
  String get reportBodyEncourage;

  /// No description provided for @schedTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedTitle;

  /// No description provided for @schedSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get schedSent;

  /// No description provided for @schedDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get schedDeleteTitle;

  /// No description provided for @schedDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the {time} session with {name}?'**
  String schedDeleteConfirm(String time, String name);

  /// No description provided for @schedDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the session. Please try again'**
  String get schedDeleteFailed;

  /// No description provided for @schedCompleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark it complete. Please try again'**
  String get schedCompleteFailed;

  /// No description provided for @schedViewDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get schedViewDay;

  /// No description provided for @schedViewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get schedViewWeek;

  /// No description provided for @schedSlots.
  ///
  /// In en, this message translates to:
  /// **'Booking slots'**
  String get schedSlots;

  /// No description provided for @schedNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get schedNewSession;

  /// No description provided for @schedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the schedule'**
  String get schedLoadFailed;

  /// No description provided for @schedEmptyDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled for this day.\nAdd a session below.'**
  String get schedEmptyDay;

  /// No description provided for @schedCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark session complete'**
  String get schedCompleteTitle;

  /// No description provided for @schedCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'This marks the {time} session with {name} complete and logs it to their workout history.'**
  String schedCompleteBody(String time, String name);

  /// No description provided for @schedNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Trainer\'s note (optional)'**
  String get schedNoteOptional;

  /// No description provided for @schedCompleteAction.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get schedCompleteAction;

  /// No description provided for @schedNewClient.
  ///
  /// In en, this message translates to:
  /// **'New client'**
  String get schedNewClient;

  /// No description provided for @schedSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the session. Please try again'**
  String get schedSaveFailed;

  /// No description provided for @schedAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a session'**
  String get schedAddTitle;

  /// No description provided for @schedEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit session'**
  String get schedEditTitle;

  /// No description provided for @schedFieldClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get schedFieldClient;

  /// No description provided for @schedFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get schedFieldType;

  /// No description provided for @schedFieldTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get schedFieldTime;

  /// No description provided for @schedMinuteSuffix.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get schedMinuteSuffix;

  /// No description provided for @schedFieldDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get schedFieldDuration;

  /// No description provided for @schedNote.
  ///
  /// In en, this message translates to:
  /// **'Trainer\'s note'**
  String get schedNote;

  /// No description provided for @schedNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Anything to prepare, or notes about this client'**
  String get schedNoteHint;

  /// No description provided for @schedAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get schedAddAction;

  /// No description provided for @schedSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get schedSaveAction;

  /// No description provided for @progInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the exercise name and set count'**
  String get progInvalid;

  /// No description provided for @progSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the program. Please try again'**
  String get progSaveFailed;

  /// No description provided for @progEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit program'**
  String get progEditTitle;

  /// No description provided for @progAddExercise.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get progAddExercise;

  /// No description provided for @progNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Notes to follow while running this program'**
  String get progNoteHint;

  /// No description provided for @progSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get progSaving;

  /// No description provided for @progSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save program'**
  String get progSaveAction;

  /// No description provided for @progExerciseName.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get progExerciseName;

  /// No description provided for @progDeleteExercise.
  ///
  /// In en, this message translates to:
  /// **'Remove exercise'**
  String get progDeleteExercise;

  /// No description provided for @progSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get progSets;

  /// No description provided for @progReps.
  ///
  /// In en, this message translates to:
  /// **'Reps/time'**
  String get progReps;

  /// No description provided for @progWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get progWeight;

  /// No description provided for @progOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get progOptional;

  /// No description provided for @progSetsByReps.
  ///
  /// In en, this message translates to:
  /// **'{sets} × {reps}'**
  String progSetsByReps(int sets, String reps);

  /// No description provided for @progEmpty.
  ///
  /// In en, this message translates to:
  /// **'No program planned yet'**
  String get progEmpty;

  /// No description provided for @progEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Build one in the AI routine tab, or agree on it over chat first.'**
  String get progEmptyHint;

  /// No description provided for @schedEmptySlotShort.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get schedEmptySlotShort;

  /// No description provided for @schedSentToClient.
  ///
  /// In en, this message translates to:
  /// **'Sent to the client app'**
  String get schedSentToClient;

  /// No description provided for @schedSentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String schedSentTo(String name);

  /// No description provided for @schedSentProgramTo.
  ///
  /// In en, this message translates to:
  /// **'Sent {name} the PT program for {date}'**
  String schedSentProgramTo(String name, String date);

  /// No description provided for @schedSendUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Completed program delivery is not supported by the API yet.'**
  String get schedSendUnsupported;

  /// No description provided for @slotCapacityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Capacity must be between 1 and 100.'**
  String get slotCapacityInvalid;

  /// No description provided for @slotPastTime.
  ///
  /// In en, this message translates to:
  /// **'Booking slots can only be opened for future times.'**
  String get slotPastTime;

  /// No description provided for @slotOpened.
  ///
  /// In en, this message translates to:
  /// **'Booking slot opened.'**
  String get slotOpened;

  /// No description provided for @slotEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit booking slot'**
  String get slotEditTitle;

  /// No description provided for @slotStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get slotStartTime;

  /// No description provided for @slotCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get slotCapacity;

  /// No description provided for @slotBookedNow.
  ///
  /// In en, this message translates to:
  /// **'{count} booked'**
  String slotBookedNow(int count);

  /// No description provided for @slotUpdated.
  ///
  /// In en, this message translates to:
  /// **'Booking slot updated.'**
  String get slotUpdated;

  /// No description provided for @slotCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close booking slot'**
  String get slotCloseTitle;

  /// No description provided for @slotCloseBody.
  ///
  /// In en, this message translates to:
  /// **'The {count} existing bookings stay; only new bookings stop.'**
  String slotCloseBody(int count);

  /// No description provided for @slotClosed.
  ///
  /// In en, this message translates to:
  /// **'New bookings closed.'**
  String get slotClosed;

  /// No description provided for @slotActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the request. Please try again in a moment.'**
  String get slotActionFailed;

  /// No description provided for @slotManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage booking slots'**
  String get slotManageTitle;

  /// No description provided for @slotIntro.
  ///
  /// In en, this message translates to:
  /// **'Open times for members to book on {date}.'**
  String slotIntro(String date);

  /// No description provided for @slotOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get slotOpenAction;

  /// No description provided for @slotReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get slotReload;

  /// No description provided for @slotEmpty.
  ///
  /// In en, this message translates to:
  /// **'No booking slots open on this day.'**
  String get slotEmpty;

  /// No description provided for @slotClosedSummary.
  ///
  /// In en, this message translates to:
  /// **'Closed · {booked} booked'**
  String slotClosedSummary(int booked);

  /// No description provided for @slotOpenSummary.
  ///
  /// In en, this message translates to:
  /// **'{booked} booked · {remaining} left'**
  String slotOpenSummary(int booked, int remaining);

  /// No description provided for @slotCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Close bookings'**
  String get slotCloseAction;

  /// No description provided for @myCareerInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter years of experience between 0 and 80.'**
  String get myCareerInvalid;

  /// No description provided for @myProfileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your profile.'**
  String get myProfileSaveFailed;

  /// No description provided for @myGymChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change your gym. The rest of your profile was saved.'**
  String get myGymChangeFailed;

  /// No description provided for @myTabProfile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get myTabProfile;

  /// No description provided for @myTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get myTabSettings;

  /// No description provided for @mySaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get mySaving;

  /// No description provided for @myEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get myEditProfile;

  /// No description provided for @mySaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get mySaved;

  /// No description provided for @myCertifications.
  ///
  /// In en, this message translates to:
  /// **'Certifications'**
  String get myCertifications;

  /// No description provided for @myMonthStats.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get myMonthStats;

  /// No description provided for @myGym.
  ///
  /// In en, this message translates to:
  /// **'My gym'**
  String get myGym;

  /// No description provided for @myNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get myNotifications;

  /// No description provided for @myNotifNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New message alerts'**
  String get myNotifNewMessage;

  /// No description provided for @myNotifNewMessageHint.
  ///
  /// In en, this message translates to:
  /// **'A sidebar badge appears when a client messages you'**
  String get myNotifNewMessageHint;

  /// No description provided for @myNotifSessionReminder.
  ///
  /// In en, this message translates to:
  /// **'Session reminders'**
  String get myNotifSessionReminder;

  /// No description provided for @myNotifSessionReminderHint.
  ///
  /// In en, this message translates to:
  /// **'Upcoming sessions are highlighted on the dashboard'**
  String get myNotifSessionReminderHint;

  /// No description provided for @myReminderLead.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get myReminderLead;

  /// No description provided for @myMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String myMinutesBefore(int minutes);

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get myAccount;

  /// No description provided for @myChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get myChangePassword;

  /// No description provided for @myChangePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll confirm your current password first'**
  String get myChangePasswordHint;

  /// No description provided for @myChangePasswordDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo mode has no account, so this is unavailable'**
  String get myChangePasswordDemo;

  /// No description provided for @myLoginAccount.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get myLoginAccount;

  /// No description provided for @myAppInfo.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get myAppInfo;

  /// No description provided for @myService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get myService;

  /// No description provided for @myVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get myVersion;

  /// No description provided for @myContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get myContact;

  /// No description provided for @myPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get myPasswordChanged;

  /// No description provided for @myCareerYears.
  ///
  /// In en, this message translates to:
  /// **'{career} experience'**
  String myCareerYears(String career);

  /// No description provided for @myFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name (account)'**
  String get myFieldName;

  /// No description provided for @myFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email (account)'**
  String get myFieldEmail;

  /// No description provided for @myFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get myFieldPhone;

  /// No description provided for @myFieldSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get myFieldSpecialty;

  /// No description provided for @myFieldCareer.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get myFieldCareer;

  /// No description provided for @myFieldIntro.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get myFieldIntro;

  /// No description provided for @myAddCertification.
  ///
  /// In en, this message translates to:
  /// **'Add a certification...'**
  String get myAddCertification;

  /// No description provided for @myAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get myAdd;

  /// No description provided for @myStatClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get myStatClients;

  /// No description provided for @myStatSessionsDone.
  ///
  /// In en, this message translates to:
  /// **'Sessions done'**
  String get myStatSessionsDone;

  /// No description provided for @myStatRoutinesSent.
  ///
  /// In en, this message translates to:
  /// **'Routines sent'**
  String get myStatRoutinesSent;

  /// No description provided for @myGymName.
  ///
  /// In en, this message translates to:
  /// **'Gym name'**
  String get myGymName;

  /// No description provided for @myGymAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get myGymAddress;

  /// No description provided for @myGymHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get myGymHours;

  /// No description provided for @myGymOpen.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get myGymOpen;

  /// No description provided for @myGymListFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the gym list.'**
  String get myGymListFailed;

  /// No description provided for @myNoGym.
  ///
  /// In en, this message translates to:
  /// **'No gym'**
  String get myNoGym;

  /// No description provided for @mySignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get mySignOut;

  /// No description provided for @myPwCurrentRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get myPwCurrentRequired;

  /// No description provided for @myPwTooShort.
  ///
  /// In en, this message translates to:
  /// **'The new password must be at least {min} characters'**
  String myPwTooShort(int min);

  /// No description provided for @myPwMismatch.
  ///
  /// In en, this message translates to:
  /// **'The new passwords don\'t match'**
  String get myPwMismatch;

  /// No description provided for @myPwChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change your password'**
  String get myPwChangeFailed;

  /// No description provided for @myPwChangeRetry.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Please try again in a moment'**
  String get myPwChangeRetry;

  /// No description provided for @myPwCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get myPwCurrent;

  /// No description provided for @myPwNew.
  ///
  /// In en, this message translates to:
  /// **'New password ({min}+ characters)'**
  String myPwNew(int min);

  /// No description provided for @myPwConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get myPwConfirm;

  /// No description provided for @myPwChanging.
  ///
  /// In en, this message translates to:
  /// **'Changing…'**
  String get myPwChanging;

  /// No description provided for @myPwChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get myPwChangeAction;

  /// No description provided for @mySettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your settings. Please try again in a moment'**
  String get mySettingsSaveFailed;

  /// Display label for the '걷기' routine type. The stored/wire value stays Korean — see kRoutineTypes.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get routineTypeWalking;

  /// No description provided for @routineTypeCardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get routineTypeCardio;

  /// No description provided for @routineTypeStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get routineTypeStrength;

  /// No description provided for @routineTypeYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get routineTypeYoga;

  /// No description provided for @routineTypeStretching.
  ///
  /// In en, this message translates to:
  /// **'Stretching'**
  String get routineTypeStretching;

  /// No description provided for @routineTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get routineTypeOther;

  /// No description provided for @routineFieldType.
  ///
  /// In en, this message translates to:
  /// **'Exercise type'**
  String get routineFieldType;

  /// No description provided for @routineFieldMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get routineFieldMinutes;

  /// No description provided for @routineFieldTotalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Total workout time'**
  String get routineFieldTotalMinutes;

  /// No description provided for @routineFieldIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get routineFieldIntensity;

  /// No description provided for @intensityLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get intensityLight;

  /// No description provided for @intensityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get intensityModerate;

  /// No description provided for @intensityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get intensityHigh;

  /// No description provided for @coachTitle.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get coachTitle;

  /// No description provided for @coachSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create, assign, and manage exercise programs for each member'**
  String get coachSubtitle;

  /// No description provided for @coachMemberPrograms.
  ///
  /// In en, this message translates to:
  /// **'Programs by member'**
  String get coachMemberPrograms;

  /// No description provided for @coachMemberSummary.
  ///
  /// In en, this message translates to:
  /// **'Member summary'**
  String get coachMemberSummary;

  /// No description provided for @reportsDataInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient data'**
  String get reportsDataInsufficient;

  /// No description provided for @reportsAnalysisAvailable.
  ///
  /// In en, this message translates to:
  /// **'Ready to analyze'**
  String get reportsAnalysisAvailable;

  /// No description provided for @reportsFeedbackComplete.
  ///
  /// In en, this message translates to:
  /// **'Feedback complete'**
  String get reportsFeedbackComplete;

  /// No description provided for @reportsFeedbackPending.
  ///
  /// In en, this message translates to:
  /// **'Feedback pending'**
  String get reportsFeedbackPending;

  /// No description provided for @reportsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get reportsThisWeek;

  /// No description provided for @reportsAnalysisCount.
  ///
  /// In en, this message translates to:
  /// **'{total} total · {available} ready'**
  String reportsAnalysisCount(int total, int available);

  /// No description provided for @coachSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Please try again'**
  String get coachSendFailed;

  /// No description provided for @coachCustomRoutine.
  ///
  /// In en, this message translates to:
  /// **'AI custom routine'**
  String get coachCustomRoutine;

  /// No description provided for @coachNeedOneExercise.
  ///
  /// In en, this message translates to:
  /// **'Add at least one exercise'**
  String get coachNeedOneExercise;

  /// No description provided for @coachScheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add it to the schedule. Please try again'**
  String get coachScheduleFailed;

  /// No description provided for @coachNoClients.
  ///
  /// In en, this message translates to:
  /// **'No clients yet'**
  String get coachNoClients;

  /// No description provided for @coachTodayDiet.
  ///
  /// In en, this message translates to:
  /// **'Today\'s meals'**
  String get coachTodayDiet;

  /// No description provided for @coachRecommended.
  ///
  /// In en, this message translates to:
  /// **'AI suggestions'**
  String get coachRecommended;

  /// No description provided for @coachBackToList.
  ///
  /// In en, this message translates to:
  /// **'Back to suggestions'**
  String get coachBackToList;

  /// No description provided for @coachReviewed.
  ///
  /// In en, this message translates to:
  /// **'AI-generated, reviewed by you'**
  String get coachReviewed;

  /// No description provided for @coachTrainerAdded.
  ///
  /// In en, this message translates to:
  /// **'Added by trainer'**
  String get coachTrainerAdded;

  /// No description provided for @coachClientNotified.
  ///
  /// In en, this message translates to:
  /// **'The client app was notified'**
  String get coachClientNotified;

  /// No description provided for @coachRegisteredOn.
  ///
  /// In en, this message translates to:
  /// **'Added to the {date} schedule'**
  String coachRegisteredOn(String date);

  /// No description provided for @coachRegisterOn.
  ///
  /// In en, this message translates to:
  /// **'Add to the {date} PT schedule'**
  String coachRegisterOn(String date);

  /// No description provided for @labelTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get labelTomorrow;

  /// No description provided for @coachFindInSchedule.
  ///
  /// In en, this message translates to:
  /// **'You\'ll find it in the Schedule tab as the {date} session\'s program'**
  String coachFindInSchedule(String date);

  /// No description provided for @coachVerdictSodium.
  ///
  /// In en, this message translates to:
  /// **'AI: sodium over target → favour more cardio'**
  String get coachVerdictSodium;

  /// No description provided for @coachVerdictBalanced.
  ///
  /// In en, this message translates to:
  /// **'AI: meals well balanced → keep a strength-led routine'**
  String get coachVerdictBalanced;

  /// No description provided for @coachRequestCustom.
  ///
  /// In en, this message translates to:
  /// **'Ask AI for a custom routine'**
  String get coachRequestCustom;

  /// No description provided for @coachRequestBlurb.
  ///
  /// In en, this message translates to:
  /// **'We\'ll analyse {name}\'s data, draft a recovery and a push option, and let you compare and edit them here.'**
  String coachRequestBlurb(String name);

  /// No description provided for @coachTapToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit'**
  String get coachTapToEdit;

  /// No description provided for @coachAddExerciseManually.
  ///
  /// In en, this message translates to:
  /// **'+ Add an exercise'**
  String get coachAddExerciseManually;

  /// No description provided for @coachExerciseNameHint.
  ///
  /// In en, this message translates to:
  /// **'Exercise (e.g. leg press, 3 sets)'**
  String get coachExerciseNameHint;

  /// No description provided for @coachSentToClient.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String coachSentToClient(String name);

  /// No description provided for @coachReviewAndSend.
  ///
  /// In en, this message translates to:
  /// **'Reviewed · send to {name}'**
  String coachReviewAndSend(String name);

  /// No description provided for @coachTemplates.
  ///
  /// In en, this message translates to:
  /// **'Program templates'**
  String get coachTemplates;

  /// No description provided for @coachSentHistory.
  ///
  /// In en, this message translates to:
  /// **'Sent history'**
  String get coachSentHistory;

  /// No description provided for @coachHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load history'**
  String get coachHistoryFailed;

  /// No description provided for @coachHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t sent any programs yet'**
  String get coachHistoryEmpty;

  /// No description provided for @coachHomework.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get coachHomework;

  /// No description provided for @coachRoutineSummary.
  ///
  /// In en, this message translates to:
  /// **'{name} · {minutes} min'**
  String coachRoutineSummary(String name, int minutes);

  /// No description provided for @coachTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get coachTrainer;

  /// No description provided for @coachSessionExercises.
  ///
  /// In en, this message translates to:
  /// **'{type} · {count} exercises'**
  String coachSessionExercises(String type, int count);

  /// No description provided for @aiReasonSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium is over target today, so lean into low-intensity cardio.'**
  String get aiReasonSodium;

  /// No description provided for @aiReasonBalanced.
  ///
  /// In en, this message translates to:
  /// **'Today\'s meals are balanced, so the current intensity is fine to keep.'**
  String get aiReasonBalanced;

  /// No description provided for @aiReasonGoal.
  ///
  /// In en, this message translates to:
  /// **'Based on the {goal} goal and recent {last} activity.'**
  String aiReasonGoal(String goal, String last);

  /// No description provided for @aiTagExisting.
  ///
  /// In en, this message translates to:
  /// **'Existing suggestion'**
  String get aiTagExisting;

  /// No description provided for @aiTagCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get aiTagCustom;

  /// No description provided for @aiExistingBlurb.
  ///
  /// In en, this message translates to:
  /// **'The existing suggestion, based on their recent meals and workouts.'**
  String get aiExistingBlurb;

  /// No description provided for @aiOptionRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get aiOptionRecovery;

  /// No description provided for @aiOptionPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get aiOptionPush;

  /// No description provided for @aiOptionExisting.
  ///
  /// In en, this message translates to:
  /// **'Existing'**
  String get aiOptionExisting;

  /// No description provided for @aiGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'AI generation failed. Please try again in a moment'**
  String get aiGenerateFailed;

  /// No description provided for @aiGenerateRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many generation requests. Please try again shortly'**
  String get aiGenerateRateLimited;

  /// No description provided for @aiExerciseNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an exercise name'**
  String get aiExerciseNameRequired;

  /// No description provided for @aiKeepOneExercise.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one exercise'**
  String get aiKeepOneExercise;

  /// No description provided for @aiRoutineSent.
  ///
  /// In en, this message translates to:
  /// **'Routine sent to {name}'**
  String aiRoutineSent(String name);

  /// No description provided for @aiExerciseWithMinutes.
  ///
  /// In en, this message translates to:
  /// **'{name} · {minutes} min'**
  String aiExerciseWithMinutes(String name, int minutes);

  /// No description provided for @aiCustomRoutineNamed.
  ///
  /// In en, this message translates to:
  /// **'AI custom routine ({option})'**
  String aiCustomRoutineNamed(String option);

  /// No description provided for @aiAnalysing.
  ///
  /// In en, this message translates to:
  /// **'AI is analysing…'**
  String get aiAnalysing;

  /// No description provided for @aiGenerateCandidates.
  ///
  /// In en, this message translates to:
  /// **'Generate candidates'**
  String get aiGenerateCandidates;

  /// No description provided for @aiReviewDone.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get aiReviewDone;

  /// No description provided for @aiRoutineFor.
  ///
  /// In en, this message translates to:
  /// **'AI routine · {name}'**
  String aiRoutineFor(String name);

  /// No description provided for @aiAnalysedData.
  ///
  /// In en, this message translates to:
  /// **'Analysed this client\'s data'**
  String get aiAnalysedData;

  /// No description provided for @aiGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get aiGoal;

  /// No description provided for @aiTodaySodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium today'**
  String get aiTodaySodium;

  /// No description provided for @aiOverTarget.
  ///
  /// In en, this message translates to:
  /// **' · over target'**
  String get aiOverTarget;

  /// No description provided for @aiBasisRuleBased.
  ///
  /// In en, this message translates to:
  /// **' · rule-based'**
  String get aiBasisRuleBased;

  /// No description provided for @aiChatEvidenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent conversation used'**
  String get aiChatEvidenceTitle;

  /// No description provided for @aiEditOption.
  ///
  /// In en, this message translates to:
  /// **'Edit {option}'**
  String aiEditOption(String option);

  /// No description provided for @aiEditBlurb.
  ///
  /// In en, this message translates to:
  /// **'Edit names, durations and structure just like the existing suggestion.'**
  String get aiEditBlurb;

  /// No description provided for @aiAddExerciseManually.
  ///
  /// In en, this message translates to:
  /// **'Add an exercise'**
  String get aiAddExerciseManually;

  /// No description provided for @aiExerciseNameExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. leg press, 3 sets'**
  String get aiExerciseNameExample;

  /// No description provided for @aiRegister.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get aiRegister;

  /// No description provided for @aiNoteForClient.
  ///
  /// In en, this message translates to:
  /// **'A note to send with it'**
  String get aiNoteForClient;

  /// No description provided for @aiReviewedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Reviewed · AI suggestion ({option})'**
  String aiReviewedSuggestion(String option);

  /// No description provided for @aiEditsApplied.
  ///
  /// In en, this message translates to:
  /// **'Your choice and edits are now in the final suggestion list.'**
  String get aiEditsApplied;

  /// No description provided for @aiGoToChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat with {name}'**
  String aiGoToChat(String name);

  /// No description provided for @aiSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get aiSending;

  /// No description provided for @aiSendToClient.
  ///
  /// In en, this message translates to:
  /// **'Send to client'**
  String get aiSendToClient;

  /// No description provided for @aiGoToChatHint.
  ///
  /// In en, this message translates to:
  /// **'Use the button below to jump into their chat and explain it.'**
  String get aiGoToChatHint;

  /// No description provided for @aiStepConditions.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get aiStepConditions;

  /// No description provided for @aiStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get aiStepReview;

  /// No description provided for @aiStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get aiStepDone;

  /// No description provided for @aiStepperLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom routine progress'**
  String get aiStepperLabel;

  /// No description provided for @coachTemplateSummaryWithGoal.
  ///
  /// In en, this message translates to:
  /// **'{goal} · {count} exercises · {minutes} min'**
  String coachTemplateSummaryWithGoal(String goal, int count, int minutes);

  /// No description provided for @aiWithinTarget.
  ///
  /// In en, this message translates to:
  /// **' · within target'**
  String get aiWithinTarget;

  /// No description provided for @aiRecentRoutine.
  ///
  /// In en, this message translates to:
  /// **'Recent routine'**
  String get aiRecentRoutine;

  /// No description provided for @aiTrainerNoteEditable.
  ///
  /// In en, this message translates to:
  /// **'Trainer\'s note · editable'**
  String get aiTrainerNoteEditable;

  /// No description provided for @aiNotePlaceholderHint.
  ///
  /// In en, this message translates to:
  /// **'The grey suggestion is only a prompt — only what you type is saved and sent.'**
  String get aiNotePlaceholderHint;

  /// No description provided for @aiGenerateConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get aiGenerateConditions;

  /// No description provided for @aiCompareCandidates.
  ///
  /// In en, this message translates to:
  /// **'Compare the candidates'**
  String get aiCompareCandidates;

  /// No description provided for @goalWeightLoss.
  ///
  /// In en, this message translates to:
  /// **'Weight loss'**
  String get goalWeightLoss;

  /// No description provided for @goalStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get goalStrength;

  /// No description provided for @goalFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get goalFitness;

  /// No description provided for @goalPosture.
  ///
  /// In en, this message translates to:
  /// **'Posture'**
  String get goalPosture;

  /// No description provided for @goalHealth.
  ///
  /// In en, this message translates to:
  /// **'General health'**
  String get goalHealth;

  /// No description provided for @goalOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get goalOther;

  /// No description provided for @purposeWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight management'**
  String get purposeWeight;

  /// No description provided for @purposeChronic.
  ///
  /// In en, this message translates to:
  /// **'Chronic condition'**
  String get purposeChronic;

  /// No description provided for @purposeRehab.
  ///
  /// In en, this message translates to:
  /// **'Rehabilitation'**
  String get purposeRehab;

  /// No description provided for @purposeGeneral.
  ///
  /// In en, this message translates to:
  /// **'General wellbeing'**
  String get purposeGeneral;

  /// No description provided for @purposeNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get purposeNone;

  /// No description provided for @purposeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get purposeOther;

  /// No description provided for @slotMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get slotMorning;

  /// No description provided for @slotAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get slotAfternoon;

  /// No description provided for @slotEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get slotEvening;

  /// No description provided for @slotFlexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get slotFlexible;

  /// No description provided for @unknownMember.
  ///
  /// In en, this message translates to:
  /// **'Unknown member'**
  String get unknownMember;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @alertSodiumOver.
  ///
  /// In en, this message translates to:
  /// **'Sodium over'**
  String get alertSodiumOver;

  /// No description provided for @alertLowCompletion.
  ///
  /// In en, this message translates to:
  /// **'Low completion'**
  String get alertLowCompletion;

  /// No description provided for @alertAwaitingReply.
  ///
  /// In en, this message translates to:
  /// **'Awaiting reply'**
  String get alertAwaitingReply;

  /// No description provided for @clientLastRoutine.
  ///
  /// In en, this message translates to:
  /// **'Last routine'**
  String get clientLastRoutine;

  /// No description provided for @metricOverBy.
  ///
  /// In en, this message translates to:
  /// **'{unit} over'**
  String metricOverBy(String unit);

  /// No description provided for @chartNotEnoughData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get chartNotEnoughData;

  /// No description provided for @authErrInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'That email or password isn\'t right.'**
  String get authErrInvalidCredentials;

  /// No description provided for @authErrEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'That email is already registered.'**
  String get authErrEmailTaken;

  /// No description provided for @authErrInviteCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That invite code isn\'t valid. Please check with your gym.'**
  String get authErrInviteCodeInvalid;

  /// No description provided for @authErrSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get authErrSessionExpired;

  /// No description provided for @authErrNoSocialToken.
  ///
  /// In en, this message translates to:
  /// **'No social sign-in token'**
  String get authErrNoSocialToken;

  /// No description provided for @authErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Please check your network connection.'**
  String get authErrNetwork;

  /// No description provided for @authErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong signing in. Please try again in a moment.'**
  String get authErrGeneric;

  /// No description provided for @authErrEmptyResponse.
  ///
  /// In en, this message translates to:
  /// **'The response was empty.'**
  String get authErrEmptyResponse;

  /// No description provided for @coachDemoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI coaching isn\'t available in demo mode'**
  String get coachDemoUnavailable;

  /// No description provided for @coachNotMyClient.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t one of your clients'**
  String get coachNotMyClient;

  /// No description provided for @coachAskFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your question'**
  String get coachAskFailed;

  /// No description provided for @slotCapacityRange.
  ///
  /// In en, this message translates to:
  /// **'Capacity must be between 1 and 100.'**
  String get slotCapacityRange;

  /// No description provided for @slotFutureOnly.
  ///
  /// In en, this message translates to:
  /// **'Booking slots can only be set for future times.'**
  String get slotFutureOnly;

  /// No description provided for @slotNotFound.
  ///
  /// In en, this message translates to:
  /// **'Booking slot not found.'**
  String get slotNotFound;

  /// No description provided for @slotCapacityBelowBooked.
  ///
  /// In en, this message translates to:
  /// **'Capacity can\'t be lower than the number already booked.'**
  String get slotCapacityBelowBooked;

  /// No description provided for @authErrNotTrainer.
  ///
  /// In en, this message translates to:
  /// **'Please sign in with a trainer account.'**
  String get authErrNotTrainer;

  /// No description provided for @aiBasisGoalCompletion.
  ///
  /// In en, this message translates to:
  /// **'{goal} · based on {rate}% completion'**
  String aiBasisGoalCompletion(String goal, int rate);

  /// No description provided for @aiTotalAndIntensity.
  ///
  /// In en, this message translates to:
  /// **'{total} min total · {intensity}'**
  String aiTotalAndIntensity(int total, String intensity);

  /// No description provided for @aiBulletExercise.
  ///
  /// In en, this message translates to:
  /// **'· {name} · {minutes} min '**
  String aiBulletExercise(String name, int minutes);

  /// No description provided for @schedHourLabel.
  ///
  /// In en, this message translates to:
  /// **'{hour}:00'**
  String schedHourLabel(String hour);

  /// No description provided for @schedMinuteLabel.
  ///
  /// In en, this message translates to:
  /// **'{minute} min'**
  String schedMinuteLabel(String minute);

  /// No description provided for @progDefaultReps.
  ///
  /// In en, this message translates to:
  /// **'10 reps'**
  String get progDefaultReps;

  /// Login screen wordmark with the spaced hyphen used in the visual design.
  ///
  /// In en, this message translates to:
  /// **'On - Care Trainer'**
  String get appTitleSpaced;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifReadAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifReadAll;

  /// No description provided for @notifEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notifEmpty;

  /// No description provided for @notifLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications'**
  String get notifLoadFailed;

  /// No description provided for @notifAllRead.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get notifAllRead;

  /// No description provided for @notifReadAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark them read. Please try again in a moment'**
  String get notifReadAllFailed;

  /// No description provided for @notifUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String notifUnreadCount(int count);

  /// No description provided for @myDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get myDeleteAccount;

  /// No description provided for @myDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get myDeleteAction;

  /// No description provided for @myDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Your client links and bookings go with it'**
  String get myDeleteHint;

  /// No description provided for @myDeleteDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo mode has no account to delete'**
  String get myDeleteDemo;

  /// No description provided for @myDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get myDeleteTitle;

  /// No description provided for @myDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Your client links and bookings are removed and your clients are notified. This can\'t be undone.'**
  String get myDeleteBody;

  /// No description provided for @myDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Please try again in a moment'**
  String get myDeleteFailed;

  /// No description provided for @myDeleteConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type your name ({name}) to continue'**
  String myDeleteConfirmPrompt(String name);

  /// No description provided for @routineAlreadyGone.
  ///
  /// In en, this message translates to:
  /// **'That routine is already gone'**
  String get routineAlreadyGone;

  /// No description provided for @routineUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the routine. Please try again in a moment'**
  String get routineUpdateFailed;

  /// No description provided for @routineUpdated.
  ///
  /// In en, this message translates to:
  /// **'Routine updated'**
  String get routineUpdated;

  /// No description provided for @routineDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this routine?'**
  String get routineDeleteTitle;

  /// No description provided for @routineDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the routine. Please try again in a moment'**
  String get routineDeleteFailed;

  /// No description provided for @routineDeleted.
  ///
  /// In en, this message translates to:
  /// **'Routine deleted'**
  String get routineDeleted;

  /// No description provided for @routineEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit routine'**
  String get routineEdit;

  /// No description provided for @routineDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete routine'**
  String get routineDelete;

  /// No description provided for @routineNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a routine name'**
  String get routineNameRequired;

  /// No description provided for @routineNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the name to 100 characters or fewer'**
  String get routineNameTooLong;

  /// No description provided for @routineMinutesRange.
  ///
  /// In en, this message translates to:
  /// **'Duration must be between 0 and 600 minutes'**
  String get routineMinutesRange;

  /// No description provided for @routineReasonTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the reason to 200 characters or fewer'**
  String get routineReasonTooLong;

  /// No description provided for @routineFieldName.
  ///
  /// In en, this message translates to:
  /// **'Routine name'**
  String get routineFieldName;

  /// No description provided for @routineFieldMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get routineFieldMinutesLabel;

  /// No description provided for @routineFieldReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get routineFieldReason;

  /// No description provided for @routineDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{name} disappears from the client\'s app too.'**
  String routineDeleteBody(String name);

  /// Label/tooltip of the console header's client search.
  ///
  /// In en, this message translates to:
  /// **'Search clients'**
  String get searchClients;

  /// No description provided for @searchClientsHint.
  ///
  /// In en, this message translates to:
  /// **'Search clients, goals, messages, or routines'**
  String get searchClientsHint;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// No description provided for @searchQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Open in another tab'**
  String get searchQuickActions;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No client matches “{query}”'**
  String searchNoResults(String query);

  /// Search dropdown footer: what picking a result does on this tab.
  ///
  /// In en, this message translates to:
  /// **'Picking one opens their detail'**
  String get searchGoClientDetail;

  /// No description provided for @searchGoSchedule.
  ///
  /// In en, this message translates to:
  /// **'Picking one jumps to their next booked day'**
  String get searchGoSchedule;

  /// No description provided for @searchGoCoaching.
  ///
  /// In en, this message translates to:
  /// **'Picking one loads them into AI coaching'**
  String get searchGoCoaching;

  /// No description provided for @searchGoReport.
  ///
  /// In en, this message translates to:
  /// **'Picking one opens their weekly report'**
  String get searchGoReport;

  /// No description provided for @searchDetailNoIssues.
  ///
  /// In en, this message translates to:
  /// **'Nothing to act on today'**
  String get searchDetailNoIssues;

  /// No description provided for @searchDetailUnread.
  ///
  /// In en, this message translates to:
  /// **'{count} awaiting a reply'**
  String searchDetailUnread(int count);

  /// No description provided for @searchDetailMessage.
  ///
  /// In en, this message translates to:
  /// **'{message} · {time}'**
  String searchDetailMessage(String message, String time);

  /// No description provided for @searchDetailNextSession.
  ///
  /// In en, this message translates to:
  /// **'Next session {date} {time}'**
  String searchDetailNextSession(String date, String time);

  /// No description provided for @searchDetailNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Nothing booked'**
  String get searchDetailNoUpcoming;

  /// No description provided for @searchDetailLastRoutine.
  ///
  /// In en, this message translates to:
  /// **'Last routine {when}'**
  String searchDetailLastRoutine(String when);

  /// No description provided for @searchDetailNoRoutine.
  ///
  /// In en, this message translates to:
  /// **'No routine sent yet'**
  String get searchDetailNoRoutine;

  /// No description provided for @searchDetailCompletion.
  ///
  /// In en, this message translates to:
  /// **'{percent}% completion this week'**
  String searchDetailCompletion(int percent);

  /// No description provided for @searchDetailNoRecord.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded this week'**
  String get searchDetailNoRecord;

  /// No description provided for @routineFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout feedback'**
  String get routineFeedbackTitle;

  /// No description provided for @routineFeedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Write coaching feedback for the member'**
  String get routineFeedbackHint;

  /// No description provided for @routineFeedbackWrite.
  ///
  /// In en, this message translates to:
  /// **'Write feedback'**
  String get routineFeedbackWrite;

  /// No description provided for @routineFeedbackEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit feedback'**
  String get routineFeedbackEdit;

  /// No description provided for @routineFeedbackSaved.
  ///
  /// In en, this message translates to:
  /// **'Feedback saved'**
  String get routineFeedbackSaved;

  /// No description provided for @routineFeedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save feedback. Please try again'**
  String get routineFeedbackFailed;

  /// No description provided for @navOperationsGroup.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get navOperationsGroup;

  /// No description provided for @navCoachingGroup.
  ///
  /// In en, this message translates to:
  /// **'Coaching'**
  String get navCoachingGroup;

  /// No description provided for @dashTodayTasks.
  ///
  /// In en, this message translates to:
  /// **'Today\'s tasks'**
  String get dashTodayTasks;

  /// No description provided for @dashTasksReviewed.
  ///
  /// In en, this message translates to:
  /// **'All reviewed'**
  String get dashTasksReviewed;

  /// No description provided for @dashTasksNeedReview.
  ///
  /// In en, this message translates to:
  /// **'{count} to review'**
  String dashTasksNeedReview(int count);

  /// No description provided for @dashTasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no new coaching tasks to review.'**
  String get dashTasksEmpty;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @messagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange coaching updates with clients and follow up quickly'**
  String get messagesSubtitle;

  /// No description provided for @messagesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load conversations.'**
  String get messagesLoadFailed;

  /// No description provided for @messagesConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get messagesConversations;

  /// No description provided for @messagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations match these filters.'**
  String get messagesEmpty;

  /// No description provided for @messagesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get messagesFilterAll;

  /// No description provided for @messagesFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get messagesFilterUnread;

  /// No description provided for @messagesFilterAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get messagesFilterAttention;

  /// No description provided for @messagesFilterUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'Unread {count}'**
  String messagesFilterUnreadCount(int count);

  /// No description provided for @messagesBackToList.
  ///
  /// In en, this message translates to:
  /// **'Conversation list'**
  String get messagesBackToList;

  /// No description provided for @messagesProgram.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get messagesProgram;

  /// No description provided for @messagesSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get messagesSchedule;

  /// No description provided for @messagesRecentWorkout.
  ///
  /// In en, this message translates to:
  /// **'Recent workout {value}'**
  String messagesRecentWorkout(String value);

  /// No description provided for @messagesNoCompletion.
  ///
  /// In en, this message translates to:
  /// **'No completion record this week'**
  String get messagesNoCompletion;

  /// No description provided for @messagesCompletion.
  ///
  /// In en, this message translates to:
  /// **'{percent}% completion this week'**
  String messagesCompletion(int percent);

  /// No description provided for @messagesClientDetail.
  ///
  /// In en, this message translates to:
  /// **'View client details'**
  String get messagesClientDetail;

  /// No description provided for @messagesSelectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a client from the list to start a conversation.'**
  String get messagesSelectPrompt;

  /// No description provided for @clientQuickMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get clientQuickMessages;

  /// No description provided for @clientQuickProgram.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get clientQuickProgram;

  /// No description provided for @clientQuickSchedule.
  ///
  /// In en, this message translates to:
  /// **'Add schedule'**
  String get clientQuickSchedule;

  /// No description provided for @clientHealthGoals.
  ///
  /// In en, this message translates to:
  /// **'Body profile & goals'**
  String get clientHealthGoals;

  /// No description provided for @clientTrainerMemoUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Trainer memo storage isn\'t supported yet.'**
  String get clientTrainerMemoUnsupported;

  /// No description provided for @clientTrainerMemo.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get clientTrainerMemo;

  /// No description provided for @dashTaskReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get dashTaskReply;

  /// No description provided for @dashTaskDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get dashTaskDiet;

  /// No description provided for @dashTaskWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get dashTaskWorkout;

  /// No description provided for @dashTaskReview.
  ///
  /// In en, this message translates to:
  /// **'Review {name}: {alert}'**
  String dashTaskReview(String alert, String name);

  /// No description provided for @programEditorDefaultName.
  ///
  /// In en, this message translates to:
  /// **'{goal} program'**
  String programEditorDefaultName(String goal);

  /// No description provided for @programEditorDefaultSession.
  ///
  /// In en, this message translates to:
  /// **'Session A'**
  String get programEditorDefaultSession;

  /// No description provided for @programEditorSaveUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Multi-session program storage isn\'t supported yet.'**
  String get programEditorSaveUnsupported;

  /// No description provided for @programEditorAssignUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The server currently supports flat routine assignments only.'**
  String get programEditorAssignUnsupported;

  /// No description provided for @programEditorAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign to client'**
  String get programEditorAssign;

  /// No description provided for @programEditorInfo.
  ///
  /// In en, this message translates to:
  /// **'Program information'**
  String get programEditorInfo;

  /// No description provided for @programEditorName.
  ///
  /// In en, this message translates to:
  /// **'Program name'**
  String get programEditorName;

  /// No description provided for @programEditorGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal (optional)'**
  String get programEditorGoal;

  /// No description provided for @programEditorPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period (optional)'**
  String get programEditorPeriod;

  /// No description provided for @programEditorMemo.
  ///
  /// In en, this message translates to:
  /// **'Program memo (optional)'**
  String get programEditorMemo;

  /// No description provided for @programEditorAiHint.
  ///
  /// In en, this message translates to:
  /// **'Apply AI coaching suggestions to the first session as a local draft.'**
  String get programEditorAiHint;

  /// No description provided for @programEditorApply.
  ///
  /// In en, this message translates to:
  /// **'Apply to editor'**
  String get programEditorApply;

  /// No description provided for @programEditorExerciseConfig.
  ///
  /// In en, this message translates to:
  /// **'Workout structure'**
  String get programEditorExerciseConfig;

  /// No description provided for @programEditorAddSession.
  ///
  /// In en, this message translates to:
  /// **'Add session'**
  String get programEditorAddSession;

  /// No description provided for @programEditorSessionName.
  ///
  /// In en, this message translates to:
  /// **'Session {letter}'**
  String programEditorSessionName(String letter);

  /// No description provided for @programEditorLocalBanner.
  ///
  /// In en, this message translates to:
  /// **'This is a local draft. Saving and assigning multi-session programs requires the new Program API.'**
  String get programEditorLocalBanner;

  /// No description provided for @programEditorSessionUp.
  ///
  /// In en, this message translates to:
  /// **'Move session up'**
  String get programEditorSessionUp;

  /// No description provided for @programEditorSessionDown.
  ///
  /// In en, this message translates to:
  /// **'Move session down'**
  String get programEditorSessionDown;

  /// No description provided for @programEditorSessionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get programEditorSessionDelete;

  /// No description provided for @programEditorSessionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add exercises to build this session.'**
  String get programEditorSessionEmpty;

  /// No description provided for @programEditorExerciseSearch.
  ///
  /// In en, this message translates to:
  /// **'Search exercises or enter one'**
  String get programEditorExerciseSearch;

  /// No description provided for @programEditorAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get programEditorAdd;

  /// No description provided for @programEditorAddExercise.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get programEditorAddExercise;

  /// No description provided for @programEditorExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get programEditorExercise;

  /// No description provided for @programEditorExerciseUp.
  ///
  /// In en, this message translates to:
  /// **'Move exercise up'**
  String get programEditorExerciseUp;

  /// No description provided for @programEditorExerciseDown.
  ///
  /// In en, this message translates to:
  /// **'Move exercise down'**
  String get programEditorExerciseDown;

  /// No description provided for @programEditorExerciseDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete exercise'**
  String get programEditorExerciseDelete;

  /// No description provided for @programEditorSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get programEditorSets;

  /// No description provided for @programEditorReps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get programEditorReps;

  /// No description provided for @programEditorWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight kg'**
  String get programEditorWeight;

  /// No description provided for @programEditorDuration.
  ///
  /// In en, this message translates to:
  /// **'Time min'**
  String get programEditorDuration;

  /// No description provided for @programEditorDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance m'**
  String get programEditorDistance;

  /// No description provided for @programEditorRest.
  ///
  /// In en, this message translates to:
  /// **'Rest sec'**
  String get programEditorRest;

  /// No description provided for @programEditorExerciseMemo.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get programEditorExerciseMemo;

  /// No description provided for @reportsComparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'This week vs last week'**
  String get reportsComparisonTitle;

  /// No description provided for @reportsLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get reportsLastWeek;

  /// No description provided for @reportsSelectedWeek.
  ///
  /// In en, this message translates to:
  /// **'Selected week'**
  String get reportsSelectedWeek;

  /// No description provided for @reportsBackToList.
  ///
  /// In en, this message translates to:
  /// **'Client list'**
  String get reportsBackToList;

  /// No description provided for @reportsPreviousLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load last week\'s data.'**
  String get reportsPreviousLoadFailed;

  /// No description provided for @reportsAverageSodium.
  ///
  /// In en, this message translates to:
  /// **'Average sodium'**
  String get reportsAverageSodium;

  /// No description provided for @reportsPreviousValue.
  ///
  /// In en, this message translates to:
  /// **'Last week {value}'**
  String reportsPreviousValue(String value);

  /// No description provided for @reportsFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Trainer feedback'**
  String get reportsFeedbackTitle;

  /// No description provided for @reportsFeedbackSaveUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Feedback draft storage isn\'t supported yet.'**
  String get reportsFeedbackSaveUnsupported;

  /// No description provided for @reportsFeedbackSave.
  ///
  /// In en, this message translates to:
  /// **'Save feedback'**
  String get reportsFeedbackSave;

  /// No description provided for @reportsFeedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Write coaching feedback for the client.'**
  String get reportsFeedbackHint;

  /// No description provided for @reportsFeedbackHelper.
  ///
  /// In en, this message translates to:
  /// **'The draft isn\'t stored on the server. Sending delivers it through the existing chat.'**
  String get reportsFeedbackHelper;

  /// No description provided for @reportsTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout completion · Last 4 weeks'**
  String get reportsTrendTitle;

  /// No description provided for @reportsTrendWeek.
  ///
  /// In en, this message translates to:
  /// **'Week {index}'**
  String reportsTrendWeek(int index);

  /// No description provided for @reportsAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI coaching assistant · Report summary'**
  String get reportsAiTitle;

  /// No description provided for @reportsAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Available after the report summary API is connected. No summary is generated now.'**
  String get reportsAiUnavailable;

  /// No description provided for @reportsPdfUnsupported.
  ///
  /// In en, this message translates to:
  /// **'PDF generation isn\'t supported yet.'**
  String get reportsPdfUnsupported;

  /// No description provided for @reportsPdfLabel.
  ///
  /// In en, this message translates to:
  /// **'Shareable PDF'**
  String get reportsPdfLabel;

  /// No description provided for @reportsPrintUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Available after PDF/print report snapshots are supported.'**
  String get reportsPrintUnsupported;

  /// No description provided for @reportsPrintLabel.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get reportsPrintLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
