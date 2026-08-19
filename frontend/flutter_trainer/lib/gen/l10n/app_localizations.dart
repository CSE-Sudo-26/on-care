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

  /// No description provided for @scheduleStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get scheduleStatusCancelled;

  /// No description provided for @scheduleStatusNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get scheduleStatusNoShow;

  /// No description provided for @schedCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel session'**
  String get schedCancel;

  /// No description provided for @schedNoShow.
  ///
  /// In en, this message translates to:
  /// **'Mark no-show'**
  String get schedNoShow;

  /// No description provided for @schedCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this PT?'**
  String get schedCancelTitle;

  /// No description provided for @schedCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'The {time} session with {name} will be recorded as cancelled. The entry stays.'**
  String schedCancelConfirm(String time, String name);

  /// No description provided for @schedCancelSource.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by'**
  String get schedCancelSource;

  /// No description provided for @schedCancelByMember.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get schedCancelByMember;

  /// No description provided for @schedCancelByTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get schedCancelByTrainer;

  /// No description provided for @schedCancelByOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get schedCancelByOther;

  /// No description provided for @schedCancelReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional, only you see it)'**
  String get schedCancelReasonHint;

  /// No description provided for @schedCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel the session. Please try again.'**
  String get schedCancelFailed;

  /// No description provided for @schedNoShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Record as a no-show?'**
  String get schedNoShowTitle;

  /// No description provided for @schedNoShowConfirm.
  ///
  /// In en, this message translates to:
  /// **'The {time} session with {name} will be recorded as a no-show.'**
  String schedNoShowConfirm(String time, String name);

  /// No description provided for @schedNoShowFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t record the no-show. Please try again.'**
  String get schedNoShowFailed;

  /// No description provided for @schedCancelledBy.
  ///
  /// In en, this message translates to:
  /// **'{source} · {date}'**
  String schedCancelledBy(String source, String date);

  /// No description provided for @schedDeleteMeansRemove.
  ///
  /// In en, this message translates to:
  /// **'Deleting erases the record. Use cancel or no-show for a PT that didn\'t happen.'**
  String get schedDeleteMeansRemove;

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
  /// **'Check diet & completion'**
  String get dashCheckSodiumCompletion;

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

  /// No description provided for @dashAiAllOnTrack.
  ///
  /// In en, this message translates to:
  /// **'All {total} clients are within target. Hold this intensity and raise next week\'s goal.'**
  String dashAiAllOnTrack(int total);

  /// No description provided for @dashAiLoading.
  ///
  /// In en, this message translates to:
  /// **'Reviewing diet, workouts, and recent conversations…'**
  String get dashAiLoading;

  /// No description provided for @dashAiLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the detailed coaching summary.'**
  String get dashAiLoadFailed;

  /// No description provided for @dashAiRateLimited.
  ///
  /// In en, this message translates to:
  /// **'There are too many summary requests. Try again shortly.'**
  String get dashAiRateLimited;

  /// No description provided for @dashAiStatus.
  ///
  /// In en, this message translates to:
  /// **'Current status'**
  String get dashAiStatus;

  /// No description provided for @dashAiExerciseFocus.
  ///
  /// In en, this message translates to:
  /// **'Today\'s exercise focus'**
  String get dashAiExerciseFocus;

  /// No description provided for @dashAiEvidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get dashAiEvidence;

  /// No description provided for @dashAiCaution.
  ///
  /// In en, this message translates to:
  /// **'Check before session'**
  String get dashAiCaution;

  /// No description provided for @dashAiPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'Check first'**
  String get dashAiPriorityHigh;

  /// No description provided for @dashAiPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get dashAiPriorityMedium;

  /// No description provided for @dashAiPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Maintain'**
  String get dashAiPriorityLow;

  /// No description provided for @dashAiRuleHeadline.
  ///
  /// In en, this message translates to:
  /// **'Check {name} first and adjust training load to the diet and condition signals.'**
  String dashAiRuleHeadline(String name);

  /// No description provided for @dashAiRuleKneeStatus.
  ///
  /// In en, this message translates to:
  /// **'A recent message indicates knee or lower-body discomfort, so lower-body load should be adjusted.'**
  String get dashAiRuleKneeStatus;

  /// No description provided for @dashAiRuleKneeFocus.
  ///
  /// In en, this message translates to:
  /// **'Reduce heavy squats and lunges; focus on glute activation, knee mobility, and level walking.'**
  String get dashAiRuleKneeFocus;

  /// No description provided for @dashAiRuleKneeCaution.
  ///
  /// In en, this message translates to:
  /// **'Confirm the pain location and range of motion before the session.'**
  String get dashAiRuleKneeCaution;

  /// No description provided for @dashAiRuleUpperStatus.
  ///
  /// In en, this message translates to:
  /// **'Shoulder or neck discomfort indicates that upper-body pushing and pulling intensity should be adjusted.'**
  String get dashAiRuleUpperStatus;

  /// No description provided for @dashAiRuleUpperFocus.
  ///
  /// In en, this message translates to:
  /// **'Reduce heavy upper-body work; focus on thoracic mobility, scapular stability, and stretching.'**
  String get dashAiRuleUpperFocus;

  /// No description provided for @dashAiRuleUpperCaution.
  ///
  /// In en, this message translates to:
  /// **'Check which arm elevation angles feel uncomfortable.'**
  String get dashAiRuleUpperCaution;

  /// No description provided for @dashAiRuleFatigueStatus.
  ///
  /// In en, this message translates to:
  /// **'Overtime or fatigue is making exercise harder to sustain, so a manageable intensity comes first.'**
  String get dashAiRuleFatigueStatus;

  /// No description provided for @dashAiRuleFatigueFocus.
  ///
  /// In en, this message translates to:
  /// **'Reduce high-intensity full-body work and focus on 15–20 minutes of easy cardio and recovery stretching.'**
  String get dashAiRuleFatigueFocus;

  /// No description provided for @dashAiRuleFatigueCaution.
  ///
  /// In en, this message translates to:
  /// **'Confirm sleep and current fatigue before setting the intensity.'**
  String get dashAiRuleFatigueCaution;

  /// No description provided for @dashAiRuleSodiumStatus.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sodium intake is over the target, so set intensity with the current condition in mind.'**
  String get dashAiRuleSodiumStatus;

  /// No description provided for @dashAiRuleSodiumFocus.
  ///
  /// In en, this message translates to:
  /// **'Prefer moderate walking or cycling and steady full-body strength volume over high-intensity intervals.'**
  String get dashAiRuleSodiumFocus;

  /// No description provided for @dashAiRuleSodiumCaution.
  ///
  /// In en, this message translates to:
  /// **'Check hydration, dizziness, and swelling.'**
  String get dashAiRuleSodiumCaution;

  /// No description provided for @dashAiRuleCompletionStatus.
  ///
  /// In en, this message translates to:
  /// **'Weekly workout adherence is low, so review exercise volume, difficulty, and goals.'**
  String get dashAiRuleCompletionStatus;

  /// No description provided for @dashAiRuleCompletionFocus.
  ///
  /// In en, this message translates to:
  /// **'Reduce exercise count and volume, start at a manageable difficulty, and rebuild the weekly goal gradually.'**
  String get dashAiRuleCompletionFocus;

  /// No description provided for @dashAiRuleCompletionCaution.
  ///
  /// In en, this message translates to:
  /// **'Check which schedule or condition issues disrupted exercise this week.'**
  String get dashAiRuleCompletionCaution;

  /// No description provided for @dashAiRuleUnansweredStatus.
  ///
  /// In en, this message translates to:
  /// **'There is an unread message, so confirm the client\'s current condition before today\'s workout.'**
  String get dashAiRuleUnansweredStatus;

  /// No description provided for @dashAiRuleUnansweredFocus.
  ///
  /// In en, this message translates to:
  /// **'Hold off on increasing load until they reply, and begin with mobility work at the existing intensity.'**
  String get dashAiRuleUnansweredFocus;

  /// No description provided for @dashAiRuleUnansweredCaution.
  ///
  /// In en, this message translates to:
  /// **'Confirm pain, fatigue, and sleep before choosing today\'s body area and intensity.'**
  String get dashAiRuleUnansweredCaution;

  /// No description provided for @dashAiRuleEvidenceMessage.
  ///
  /// In en, this message translates to:
  /// **'Recent message: “{message}”'**
  String dashAiRuleEvidenceMessage(String message);

  /// No description provided for @dashAiRuleEvidenceSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium today: {value}mg / target: {target}mg'**
  String dashAiRuleEvidenceSodium(int value, int target);

  /// No description provided for @dashAiRuleEvidenceCompletion.
  ///
  /// In en, this message translates to:
  /// **'Average completion on recorded days this week: {average}%'**
  String dashAiRuleEvidenceCompletion(int average);

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

  /// No description provided for @memberHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Body and goals'**
  String get memberHealthTitle;

  /// No description provided for @memberHealthSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get memberHealthSaving;

  /// No description provided for @memberHealthGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get memberHealthGender;

  /// No description provided for @memberHealthGenderUnset.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get memberHealthGenderUnset;

  /// No description provided for @memberHealthGenderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get memberHealthGenderMale;

  /// No description provided for @memberHealthGenderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get memberHealthGenderFemale;

  /// No description provided for @memberHealthGenderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get memberHealthGenderOther;

  /// No description provided for @memberHealthHeight.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get memberHealthHeight;

  /// No description provided for @memberHealthWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get memberHealthWeight;

  /// No description provided for @memberHealthConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions and cautions'**
  String get memberHealthConditions;

  /// No description provided for @memberHealthGoals.
  ///
  /// In en, this message translates to:
  /// **'Member goals'**
  String get memberHealthGoals;

  /// No description provided for @memberHealthWeeklyGoal.
  ///
  /// In en, this message translates to:
  /// **'Weekly exercise goal'**
  String get memberHealthWeeklyGoal;

  /// No description provided for @memberHealthWeeklyCount.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get memberHealthWeeklyCount;

  /// No description provided for @memberHealthWeeklyMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get memberHealthWeeklyMinutes;

  /// No description provided for @memberHealthWeeklyBurn.
  ///
  /// In en, this message translates to:
  /// **'Calories burned'**
  String get memberHealthWeeklyBurn;

  /// No description provided for @memberHealthRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a value between {min} and {max}.'**
  String memberHealthRange(String min, String max);

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

  /// No description provided for @clientStatusChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the status. Please try again.'**
  String get clientStatusChangeFailed;

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

  /// No description provided for @chatPdfOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the PDF. Please try again'**
  String get chatPdfOpenFailed;

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

  /// No description provided for @chatInsightMemoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the memo. Please try again.'**
  String get chatInsightMemoSaveFailed;

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

  /// No description provided for @legendDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get legendDone;

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
  /// **'Previous'**
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

  /// No description provided for @unitTimes.
  ///
  /// In en, this message translates to:
  /// **''**
  String get unitTimes;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get unitMinutes;

  /// No description provided for @clientTrendWorkoutDaysValue.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String clientTrendWorkoutDaysValue(int days);

  /// No description provided for @clientPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get clientPeriodToday;

  /// No description provided for @clientPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get clientPeriodWeek;

  /// No description provided for @clientPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get clientPeriodMonth;

  /// No description provided for @clientPeriodAverage.
  ///
  /// In en, this message translates to:
  /// **'Daily average'**
  String get clientPeriodAverage;

  /// No description provided for @clientPeriodLoggedDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day logged} other{{days} days logged}}'**
  String clientPeriodLoggedDays(int days);

  /// No description provided for @clientPeriodEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing was logged in this period'**
  String get clientPeriodEmpty;

  /// No description provided for @clientDietTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Nutrition trend'**
  String get clientDietTrendTitle;

  /// No description provided for @unitKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get unitKcal;

  /// No description provided for @clientTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout trend'**
  String get clientTrendTitle;

  /// No description provided for @clientTrendLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the workout trend. Please try again'**
  String get clientTrendLoadFailed;

  /// No description provided for @clientTrendTodayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workout logged today'**
  String get clientTrendTodayEmpty;

  /// No description provided for @clientTrendWorkoutDays.
  ///
  /// In en, this message translates to:
  /// **'Active days'**
  String get clientTrendWorkoutDays;

  /// No description provided for @clientTrendWorkoutCount.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get clientTrendWorkoutCount;

  /// No description provided for @clientTrendWorkoutMinutes.
  ///
  /// In en, this message translates to:
  /// **'Exercise time'**
  String get clientTrendWorkoutMinutes;

  /// No description provided for @clientTrendCaloriesBurned.
  ///
  /// In en, this message translates to:
  /// **'Calories burned'**
  String get clientTrendCaloriesBurned;

  /// No description provided for @clientTrendSegmentTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get clientTrendSegmentTime;

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

  /// No description provided for @reportsCompletionAvg.
  ///
  /// In en, this message translates to:
  /// **'Workout completion'**
  String get reportsCompletionAvg;

  /// No description provided for @reportsCompletionByDay.
  ///
  /// In en, this message translates to:
  /// **'Weekly workout completion'**
  String get reportsCompletionByDay;

  /// No description provided for @reportsNoWorkoutsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No workouts logged this week'**
  String get reportsNoWorkoutsThisWeek;

  /// No description provided for @reportsMetricTrend.
  ///
  /// In en, this message translates to:
  /// **'{metric} trend'**
  String reportsMetricTrend(String metric);

  /// No description provided for @reportsNoLastWeekMetricTrend.
  ///
  /// In en, this message translates to:
  /// **'No {metric} trend for last week yet'**
  String reportsNoLastWeekMetricTrend(String metric);

  /// No description provided for @reportsNoMetricRecords.
  ///
  /// In en, this message translates to:
  /// **'No {metric} logged this week yet'**
  String reportsNoMetricRecords(String metric);

  /// No description provided for @reportsDietTrend.
  ///
  /// In en, this message translates to:
  /// **'Weekly diet trend'**
  String get reportsDietTrend;

  /// No description provided for @reportsSodiumOverInline.
  ///
  /// In en, this message translates to:
  /// **'{days} days over sodium'**
  String reportsSodiumOverInline(int days);

  /// No description provided for @workoutDoneOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String workoutDoneOfTotal(int total, int done);

  /// No description provided for @chartNoRecord.
  ///
  /// In en, this message translates to:
  /// **'Not logged'**
  String get chartNoRecord;

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

  /// No description provided for @reportsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get reportsShare;

  /// No description provided for @reportsShareSendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to {name}'**
  String reportsShareSendTo(String name);

  /// No description provided for @reportsShareNeedsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Write feedback first to send it.'**
  String get reportsShareNeedsFeedback;

  /// No description provided for @reportsShareNoClient.
  ///
  /// In en, this message translates to:
  /// **'Pick a client to see their report first.'**
  String get reportsShareNoClient;

  /// No description provided for @reportBodyGreeting.
  ///
  /// In en, this message translates to:
  /// **'{name}, here\'s your weekly report for {range}.'**
  String reportBodyGreeting(String name, String range);

  /// No description provided for @reportBodySessions.
  ///
  /// In en, this message translates to:
  /// **'We got through {done} of {booked} PT sessions.'**
  String reportBodySessions(int done, int booked);

  /// No description provided for @reportBodyCompletionGood.
  ///
  /// In en, this message translates to:
  /// **'You kept up well this week — {avg}% of your workouts done.'**
  String reportBodyCompletionGood(int avg);

  /// No description provided for @reportBodyCompletionLow.
  ///
  /// In en, this message translates to:
  /// **'Workout completion came in at {avg}% this week. Sounds like a busy one.'**
  String reportBodyCompletionLow(int avg);

  /// No description provided for @reportBodySkipped.
  ///
  /// In en, this message translates to:
  /// **'One thing — {names} got skipped. If that was a condition thing, tell me at the next session and I\'ll swap in an alternative.'**
  String reportBodySkipped(String names);

  /// No description provided for @reportBodySodiumOver.
  ///
  /// In en, this message translates to:
  /// **'Sodium averaged {avg}mg a day, over the 2,000mg target on {days} days. Leaving half the broth behind saves 400-500mg a day.'**
  String reportBodySodiumOver(int avg, int days);

  /// No description provided for @reportBodySodiumOk.
  ///
  /// In en, this message translates to:
  /// **'Sodium averaged {avg}mg a day — comfortably inside your target.'**
  String reportBodySodiumOk(int avg);

  /// No description provided for @reportBodyCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories averaged {avg}kcal a day.'**
  String reportBodyCalories(int avg);

  /// No description provided for @reportBodyPraise.
  ///
  /// In en, this message translates to:
  /// **'Great week — let\'s keep this pace next week!'**
  String get reportBodyPraise;

  /// No description provided for @reportBodyEncourage.
  ///
  /// In en, this message translates to:
  /// **'Let\'s focus on just that one thing next week. I\'ll adjust your routine and send it over.'**
  String get reportBodyEncourage;

  /// No description provided for @reportBodyNoRecords.
  ///
  /// In en, this message translates to:
  /// **'There\'s nothing logged this week, so nothing to sum up. Let\'s plan next week\'s start together.'**
  String get reportBodyNoRecords;

  /// No description provided for @schedTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedTitle;

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

  /// No description provided for @schedRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get schedRepeat;

  /// No description provided for @schedRepeatNone.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get schedRepeatNone;

  /// No description provided for @schedRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get schedRepeatWeekly;

  /// No description provided for @schedRepeatDays.
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get schedRepeatDays;

  /// No description provided for @schedRepeatEnd.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get schedRepeatEnd;

  /// No description provided for @schedRepeatEndByCount.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get schedRepeatEndByCount;

  /// No description provided for @schedRepeatEndByDate.
  ///
  /// In en, this message translates to:
  /// **'On date'**
  String get schedRepeatEndByDate;

  /// No description provided for @schedRepeatCount.
  ///
  /// In en, this message translates to:
  /// **'{count} times'**
  String schedRepeatCount(int count);

  /// No description provided for @schedRepeatPreview.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions · {first} – {last}'**
  String schedRepeatPreview(int count, String first, String last);

  /// No description provided for @schedRepeatNeedsDays.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one weekday.'**
  String get schedRepeatNeedsDays;

  /// No description provided for @schedRepeatConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} sessions clash'**
  String schedRepeatConflictTitle(int total, int count);

  /// No description provided for @schedRepeatConflictRow.
  ///
  /// In en, this message translates to:
  /// **'{date} {time} · already booked: {name}'**
  String schedRepeatConflictRow(String date, String time, String name);

  /// No description provided for @schedRepeatConflictHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing was created. Change the time, or clear the sessions that clash.'**
  String get schedRepeatConflictHint;

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

  /// No description provided for @reportsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get reportsThisWeek;

  /// No description provided for @coachSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Please try again'**
  String get coachSendFailed;

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

  /// No description provided for @coachSentToClient.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String coachSentToClient(String name);

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

  /// No description provided for @aiConditionsAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to auto-fill from recent history or goals.'**
  String get aiConditionsAutoHint;

  /// No description provided for @aiConditionsEditToggle.
  ///
  /// In en, this message translates to:
  /// **'Edit recommended conditions'**
  String get aiConditionsEditToggle;

  /// No description provided for @aiGenerateGoalBased.
  ///
  /// In en, this message translates to:
  /// **'Generate goal-based routine'**
  String get aiGenerateGoalBased;

  /// No description provided for @aiStatusTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal-based starter routine'**
  String get aiStatusTemplateTitle;

  /// No description provided for @aiStatusTemplateBody.
  ///
  /// In en, this message translates to:
  /// **'Not enough workout history yet to personalize — this starts from a goal-based default.'**
  String get aiStatusTemplateBody;

  /// No description provided for @aiStatusLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalizing (learning)'**
  String get aiStatusLearningTitle;

  /// No description provided for @aiStatusLearningBody.
  ///
  /// In en, this message translates to:
  /// **'Recent workouts were used, but there isn\'t a clear repeated pattern yet.'**
  String get aiStatusLearningBody;

  /// No description provided for @aiStatusPersonalizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalized from recent patterns'**
  String get aiStatusPersonalizedTitle;

  /// No description provided for @aiStatusPersonalizedBody.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} sessions over the last {days} days.'**
  String aiStatusPersonalizedBody(int count, int days);

  /// No description provided for @aiFrequentExercisesLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequently done'**
  String get aiFrequentExercisesLabel;

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

  /// No description provided for @alertSugarOver.
  ///
  /// In en, this message translates to:
  /// **'Sugar over target'**
  String get alertSugarOver;

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
  /// **'Clients, goals, recent messages, last routine sent date'**
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

  /// No description provided for @searchDetailCompletion.
  ///
  /// In en, this message translates to:
  /// **'{percent}% completion this week'**
  String searchDetailCompletion(int percent);

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

  /// No description provided for @clientHealthGoals.
  ///
  /// In en, this message translates to:
  /// **'Body profile & goals'**
  String get clientHealthGoals;

  /// No description provided for @clientTrainerMemo.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get clientTrainerMemo;

  /// No description provided for @clientTrainerMemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Memos on {name}'**
  String clientTrainerMemoTitle(String name);

  /// No description provided for @clientTrainerMemoHint.
  ///
  /// In en, this message translates to:
  /// **'Note what you want to remember about this member'**
  String get clientTrainerMemoHint;

  /// No description provided for @clientTrainerMemoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add memo'**
  String get clientTrainerMemoAdd;

  /// No description provided for @clientTrainerMemoEmpty.
  ///
  /// In en, this message translates to:
  /// **'No memos yet.'**
  String get clientTrainerMemoEmpty;

  /// No description provided for @clientTrainerMemoFromChat.
  ///
  /// In en, this message translates to:
  /// **'From chat'**
  String get clientTrainerMemoFromChat;

  /// No description provided for @clientTrainerMemoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load memos. Please try again.'**
  String get clientTrainerMemoLoadFailed;

  /// No description provided for @clientTrainerMemoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the memo. Please try again.'**
  String get clientTrainerMemoSaveFailed;

  /// No description provided for @clientTrainerMemoDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the memo. Please try again.'**
  String get clientTrainerMemoDeleteFailed;

  /// No description provided for @clientTrainerMemoDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this memo?'**
  String get clientTrainerMemoDeleteTitle;

  /// No description provided for @clientTrainerMemoDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'A deleted memo can\'t be restored.'**
  String get clientTrainerMemoDeleteBody;

  /// No description provided for @followUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-ups'**
  String get followUp;

  /// No description provided for @followUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow-ups on {name}'**
  String followUpTitle(String name);

  /// No description provided for @followUpHint.
  ///
  /// In en, this message translates to:
  /// **'Note what you want to check again'**
  String get followUpHint;

  /// No description provided for @followUpAdd.
  ///
  /// In en, this message translates to:
  /// **'Add follow-up'**
  String get followUpAdd;

  /// No description provided for @followUpDue.
  ///
  /// In en, this message translates to:
  /// **'Check on'**
  String get followUpDue;

  /// No description provided for @followUpDueOn.
  ///
  /// In en, this message translates to:
  /// **'Check on {date}'**
  String followUpDueOn(String date);

  /// No description provided for @followUpOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get followUpOverdue;

  /// No description provided for @followUpContext.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get followUpContext;

  /// No description provided for @followUpContextGeneral.
  ///
  /// In en, this message translates to:
  /// **'Client detail'**
  String get followUpContextGeneral;

  /// No description provided for @followUpContextDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get followUpContextDiet;

  /// No description provided for @followUpContextExercise.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get followUpContextExercise;

  /// No description provided for @followUpContextMessage.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get followUpContextMessage;

  /// No description provided for @followUpContextProgram.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get followUpContextProgram;

  /// No description provided for @followUpContextSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get followUpContextSchedule;

  /// No description provided for @followUpComplete.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get followUpComplete;

  /// No description provided for @followUpCount.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String followUpCount(int count);

  /// No description provided for @followUpEmpty.
  ///
  /// In en, this message translates to:
  /// **'No follow-ups left.'**
  String get followUpEmpty;

  /// No description provided for @followUpDashboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to follow up on today.'**
  String get followUpDashboardEmpty;

  /// No description provided for @followUpLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load follow-ups. Please try again.'**
  String get followUpLoadFailed;

  /// No description provided for @followUpSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the follow-up. Please try again.'**
  String get followUpSaveFailed;

  /// No description provided for @followUpCompleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark it done. Please try again.'**
  String get followUpCompleteFailed;

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
  /// **'Give the program a name first.'**
  String get programEditorSaveUnsupported;

  /// No description provided for @programEditorSaveEdit.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get programEditorSaveEdit;

  /// No description provided for @programSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved programs'**
  String get programSavedTitle;

  /// No description provided for @programSavedExerciseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} exercises'**
  String programSavedExerciseCount(int count);

  /// No description provided for @programSavedNew.
  ///
  /// In en, this message translates to:
  /// **'New program'**
  String get programSavedNew;

  /// No description provided for @suggestionReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'AI personal exercises'**
  String get suggestionReviewTitle;

  /// No description provided for @suggestionReviewBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} to review'**
  String suggestionReviewBadge(int count);

  /// No description provided for @suggestionReviewIntro.
  ///
  /// In en, this message translates to:
  /// **'Prepared for {name} from recent PT feedback and exercise records. The client sees only what you recommend.'**
  String suggestionReviewIntro(String name);

  /// No description provided for @suggestionReviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No AI personal exercises are waiting for review.'**
  String get suggestionReviewEmpty;

  /// No description provided for @suggestionReviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the AI suggestions.'**
  String get suggestionReviewLoadFailed;

  /// No description provided for @suggestionApprove.
  ///
  /// In en, this message translates to:
  /// **'Recommend to client'**
  String get suggestionApprove;

  /// No description provided for @suggestionDismiss.
  ///
  /// In en, this message translates to:
  /// **'Don\'t recommend'**
  String get suggestionDismiss;

  /// No description provided for @suggestionApproved.
  ///
  /// In en, this message translates to:
  /// **'Recommended {name} to {client}.'**
  String suggestionApproved(String name, String client);

  /// No description provided for @suggestionDismissed.
  ///
  /// In en, this message translates to:
  /// **'{name} won\'t be recommended.'**
  String suggestionDismissed(String name);

  /// No description provided for @suggestionActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t finish that. Please try again.'**
  String get suggestionActionFailed;

  /// No description provided for @suggestionAlreadyReviewed.
  ///
  /// In en, this message translates to:
  /// **'This suggestion was already reviewed. The list has been refreshed.'**
  String get suggestionAlreadyReviewed;

  /// No description provided for @suggestionEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit personal exercise'**
  String get suggestionEditTitle;

  /// No description provided for @suggestionEditSubmit.
  ///
  /// In en, this message translates to:
  /// **'Edit and recommend'**
  String get suggestionEditSubmit;

  /// No description provided for @suggestionEditName.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get suggestionEditName;

  /// No description provided for @suggestionEditMemo.
  ///
  /// In en, this message translates to:
  /// **'Note for the client'**
  String get suggestionEditMemo;

  /// No description provided for @suggestionEditMemoHint.
  ///
  /// In en, this message translates to:
  /// **'Stop if your right shoulder hurts.'**
  String get suggestionEditMemoHint;

  /// No description provided for @programDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Program saved.'**
  String get programDraftSaved;

  /// No description provided for @programDraftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the program. Please try again.'**
  String get programDraftSaveFailed;

  /// No description provided for @programDraftLoaded.
  ///
  /// In en, this message translates to:
  /// **'Opened {name} in the editor.'**
  String programDraftLoaded(String name);

  /// No description provided for @programDraftLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the saved program. Please try again.'**
  String get programDraftLoadFailed;

  /// No description provided for @programDraftDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the program. Please try again.'**
  String get programDraftDeleteFailed;

  /// No description provided for @programDraftDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this saved program?'**
  String get programDraftDeleteTitle;

  /// No description provided for @programDraftDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Routines you already assigned and sessions you scheduled stay as they are.'**
  String get programDraftDeleteBody;

  /// No description provided for @programEditorAssignUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Check each exercise\'s name and set count.'**
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
  /// **'{week} vs last week'**
  String reportsComparisonTitle(String week);

  /// No description provided for @reportsGoThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Go to this week'**
  String get reportsGoThisWeek;

  /// Placeholder in the report summary slot before a client is picked.
  ///
  /// In en, this message translates to:
  /// **'Select a client to see their weekly summary and coaching suggestions here'**
  String get reportsSummaryEmptyClient;

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

  /// No description provided for @reportsFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Trainer feedback'**
  String get reportsFeedbackTitle;

  /// No description provided for @reportsFeedbackDraftNote.
  ///
  /// In en, this message translates to:
  /// **'A draft filled in from this week\'s figures. Check it over before sending.'**
  String get reportsFeedbackDraftNote;

  /// No description provided for @reportsFeedbackRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore draft'**
  String get reportsFeedbackRestore;

  /// No description provided for @reportsFeedbackSave.
  ///
  /// In en, this message translates to:
  /// **'Save feedback'**
  String get reportsFeedbackSave;

  /// No description provided for @reportsFeedbackSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get reportsFeedbackSaving;

  /// No description provided for @reportsFeedbackSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved the feedback draft.'**
  String get reportsFeedbackSaved;

  /// No description provided for @reportsFeedbackSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the draft. Please try again.'**
  String get reportsFeedbackSaveFailed;

  /// No description provided for @reportsFeedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Write coaching feedback for the client.'**
  String get reportsFeedbackHint;

  /// No description provided for @reportsRecentWeeks.
  ///
  /// In en, this message translates to:
  /// **'Last 4 weekly averages'**
  String get reportsRecentWeeks;

  /// No description provided for @chartGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal\n{value}'**
  String chartGoalLabel(String value);

  /// No description provided for @reportsGoalMarker.
  ///
  /// In en, this message translates to:
  /// **'│ Goal {value}'**
  String reportsGoalMarker(String value);

  /// No description provided for @reportsWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}w ago'**
  String reportsWeeksAgo(int count);

  /// No description provided for @reportsAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI coaching assistant · Report summary'**
  String get reportsAiTitle;

  /// No description provided for @reportsAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI generated'**
  String get reportsAiGenerated;

  /// No description provided for @reportsAiLoading.
  ///
  /// In en, this message translates to:
  /// **'Writing this week\'s summary…'**
  String get reportsAiLoading;

  /// No description provided for @reportsAiUseAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Use as feedback'**
  String get reportsAiUseAsDraft;

  /// No description provided for @reportsAiRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get reportsAiRegenerate;

  /// No description provided for @reportsAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Available after the report summary API is connected. No summary is generated now.'**
  String get reportsAiUnavailable;

  /// No description provided for @reportsPdfLabel.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get reportsPdfLabel;

  /// No description provided for @reportsPdfGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating PDF…'**
  String get reportsPdfGenerating;

  /// No description provided for @reportsPdfGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate the PDF. Please try again.'**
  String get reportsPdfGenerationFailed;

  /// No description provided for @reportsPdfReady.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s weekly report is ready.'**
  String reportsPdfReady(String name);

  /// No description provided for @reportsPdfSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get reportsPdfSending;

  /// No description provided for @reportsPdfSendToClient.
  ///
  /// In en, this message translates to:
  /// **'Send to client'**
  String get reportsPdfSendToClient;

  /// No description provided for @reportsPdfSave.
  ///
  /// In en, this message translates to:
  /// **'Save PDF'**
  String get reportsPdfSave;

  /// No description provided for @reportsPdfPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get reportsPdfPrint;

  /// No description provided for @reportsPdfClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get reportsPdfClose;

  /// No description provided for @reportsPdfActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the action. Please try again.'**
  String get reportsPdfActionFailed;

  /// No description provided for @reportsPdfSent.
  ///
  /// In en, this message translates to:
  /// **'Sent the PDF to {name}.'**
  String reportsPdfSent(String name);

  /// No description provided for @reportsPdfSaveStarted.
  ///
  /// In en, this message translates to:
  /// **'Started saving the PDF.'**
  String get reportsPdfSaveStarted;

  /// No description provided for @reportsPdfPrintOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened the print dialog.'**
  String get reportsPdfPrintOpened;

  /// No description provided for @reportsPdfMessage.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your weekly report.'**
  String get reportsPdfMessage;

  /// No description provided for @reportsPdfFallbackClient.
  ///
  /// In en, this message translates to:
  /// **'client'**
  String get reportsPdfFallbackClient;
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
