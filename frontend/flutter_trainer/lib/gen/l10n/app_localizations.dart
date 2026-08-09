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
  /// **'Coaching'**
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

  /// No description provided for @navMy.
  ///
  /// In en, this message translates to:
  /// **'My page'**
  String get navMy;

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

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

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
  /// **'Clients'**
  String get clientsTitle;

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

  /// No description provided for @coachSheetThisClient.
  ///
  /// In en, this message translates to:
  /// **'this client'**
  String get coachSheetThisClient;

  /// No description provided for @coachSheetLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load AI coaching'**
  String get coachSheetLoadFailed;

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

  /// No description provided for @dietTodaySummary.
  ///
  /// In en, this message translates to:
  /// **'Today\'s nutrition'**
  String get dietTodaySummary;

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
  /// **'Week of {week} · operating metrics and client reports'**
  String reportsSubtitle(String week);

  /// No description provided for @reportsPrevWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get reportsPrevWeek;

  /// No description provided for @reportsNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get reportsNextWeek;

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

  /// No description provided for @schedHourSuffix.
  ///
  /// In en, this message translates to:
  /// **':00'**
  String get schedHourSuffix;

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

  /// No description provided for @myGymPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get myGymPhone;

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

  /// No description provided for @myProfileEmpty.
  ///
  /// In en, this message translates to:
  /// **'The profile response was empty.'**
  String get myProfileEmpty;

  /// No description provided for @myInputInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please check your input.'**
  String get myInputInvalid;

  /// No description provided for @myGymConflict.
  ///
  /// In en, this message translates to:
  /// **'That conflicts with your current gym.'**
  String get myGymConflict;

  /// No description provided for @myGymNotFound.
  ///
  /// In en, this message translates to:
  /// **'Gym not found.'**
  String get myGymNotFound;

  /// No description provided for @myPwDemoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Password changes aren\'t available in demo mode'**
  String get myPwDemoUnavailable;

  /// No description provided for @mySettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your settings. Please try again in a moment'**
  String get mySettingsSaveFailed;

  /// No description provided for @myYearsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{years} years'**
  String myYearsSuffix(int years);
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
