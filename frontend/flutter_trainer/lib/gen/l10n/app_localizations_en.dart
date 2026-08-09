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

  @override
  String get authTagline => 'The trainer-only app for managing your clients';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authSignUp => 'Sign up';

  @override
  String get authBrowseDemo => 'Explore the demo without signing in';

  @override
  String get authOr => 'or';

  @override
  String get authContinueKakao => 'Continue with Kakao';

  @override
  String get authContinueGoogle => 'Continue with Google';

  @override
  String get authSignUpSubtitle =>
      'Create an On-Care account and start managing clients';

  @override
  String get authName => 'Name';

  @override
  String get authPasswordHint => 'Password (8+ characters)';

  @override
  String get authPasswordConfirm => 'Confirm password';

  @override
  String get authInviteCode => 'Gym invite code';

  @override
  String get authInviteCodeHelp =>
      'Enter the code issued by the gym you work at.';

  @override
  String get authSignUpAndStart => 'Sign up and start';

  @override
  String get authHasAccount => 'Already have an account?';

  @override
  String get authErrEmptyCredentials => 'Enter your email and password';

  @override
  String get authErrSocialFailed =>
      'Social sign-in failed. Please try again in a moment.';

  @override
  String get authErrSignInFailed =>
      'Sign-in failed. Please try again in a moment.';

  @override
  String get authErrPasswordTooShort =>
      'Password must be at least 8 characters';

  @override
  String get authErrPasswordMismatch => 'Passwords don\'t match';

  @override
  String get authErrInviteCodeRequired =>
      'Enter the invite code you received from your gym';

  @override
  String get authErrSignUpFailed =>
      'Sign-up failed. Please try again in a moment.';

  @override
  String get dashTitle => 'Dashboard';

  @override
  String get dashAddSchedule => 'Add session';

  @override
  String get dashCreateAiRoutine => 'Create AI routine';

  @override
  String get dashLoadFailed => 'Couldn\'t load the dashboard';

  @override
  String get dashTodayReservations => 'Today\'s bookings';

  @override
  String get dashUnitCount => '';

  @override
  String get dashUnitPeople => '';

  @override
  String get dashSeeInSchedule => 'View in schedule';

  @override
  String get dashMyClients => 'My clients';

  @override
  String dashDormantClients(int count) {
    return '$count dormant';
  }

  @override
  String get dashAllActive => 'All active';

  @override
  String get dashNeedsReply => 'Awaiting reply';

  @override
  String dashWaitingClients(int count) {
    return '$count waiting';
  }

  @override
  String get dashAllReplied => 'All replied';

  @override
  String get dashAttentionClients => 'Needs attention';

  @override
  String get dashNoIssues => 'No issues';

  @override
  String get dashCheckSodiumCompletion => 'Check sodium & completion';

  @override
  String get dashWeeklyCompletion => 'Weekly session completion';

  @override
  String dashAveragePercent(int percent) {
    return 'Avg $percent%';
  }

  @override
  String get dashNoRecordsThisWeek => 'No records this week yet';

  @override
  String get dashAiSummaryTitle => 'AI coaching summary';

  @override
  String get dashToday => 'Today';

  @override
  String get dashAiNoClients =>
      'No clients yet. Once you add one, I\'ll gather their diet and workout data and point out what to coach.';

  @override
  String dashAiUnread(int count) {
    return '$count clients are waiting for a reply. Check their chats first, then adjust today\'s routines.';
  }

  @override
  String dashAiSodium(int total, int over) {
    return '$over of your $total clients went over their sodium target this week. Suggest a low-sodium diet and cardio-led routines.';
  }

  @override
  String dashAiLowCompletion(int count, int threshold) {
    return '$count clients are below $threshold% weekly completion. Ease the intensity and rebuild the habit.';
  }

  @override
  String dashAiAllOnTrack(int total) {
    return 'All $total clients are within target. Hold this intensity and raise next week\'s goal.';
  }

  @override
  String get dashAttentionTitle => 'Clients to check';

  @override
  String dashMoreCount(int count) {
    return '+$count';
  }

  @override
  String get dashNoAttention => 'No one needs attention right now';

  @override
  String get dashTodaySchedule => 'Today\'s schedule';

  @override
  String get dashSeeAll => 'See all';

  @override
  String get dashScheduleLoadFailed => 'Couldn\'t load the schedule';

  @override
  String get dashNoScheduleToday => 'Nothing scheduled today';

  @override
  String get dashEmptySlot => 'Open slot';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get clientsLoadFailed => 'Couldn\'t load client data';

  @override
  String clientsCountSummary(int total, int active) {
    return '$total clients · $active active';
  }

  @override
  String get clientsNew => 'New client';

  @override
  String get clientsTitle => 'Clients';

  @override
  String get clientsPickHint =>
      'Pick a client on the left to open\ntheir chat, meals and workouts here';

  @override
  String get clientsEmpty => 'No clients yet';

  @override
  String clientsEmptyForFilter(String filter) {
    return 'No clients match $filter';
  }

  @override
  String clientsFilterSummary(String filter, int shown, int total) {
    return '$filter · $shown/$total';
  }

  @override
  String get clientsSeeAll => 'See all';

  @override
  String get clientsNameRequired => 'Enter a name';

  @override
  String get clientsAddFailed => 'Couldn\'t add the client. Please try again';

  @override
  String get clientsDuplicateName => 'A client with that name already exists';

  @override
  String get clientsAddTitle => 'Add a client';

  @override
  String get clientsNameLabel => 'Client name';

  @override
  String get clientsGoalLabel => 'Goal (e.g. weight loss · strength)';

  @override
  String get clientsAddAction => 'Add';

  @override
  String get clientTabDiet => 'Meals';

  @override
  String get clientTabWorkout => 'Workouts';

  @override
  String get clientNotFound => 'Client not found';

  @override
  String get clientBackToList => 'Back to clients';

  @override
  String get clientList => 'Client list';

  @override
  String get metricCalories => 'Calories';

  @override
  String get metricSodium => 'Sodium';

  @override
  String get metricSugar => 'Sugar';

  @override
  String get clientWeeklyReport => 'Weekly report';

  @override
  String get clientAskAi => 'Ask AI';

  @override
  String get clientActive => 'Active';

  @override
  String get clientDormant => 'Dormant';

  @override
  String get clientClosePanel => 'Close panel';

  @override
  String get clientChat => 'Chat';

  @override
  String clientChatWithUnread(String name, int count) {
    return 'Chat with $name, $count unread';
  }

  @override
  String clientChatWith(String name) {
    return 'Chat with $name';
  }

  @override
  String get chatTooLong => 'Message is too long (2000 characters max)';

  @override
  String get chatSendFailed => 'Couldn\'t send the message. Please try again';

  @override
  String get chatLoadFailed => 'Couldn\'t load the conversation';

  @override
  String chatDemoAnalyzed(String name) {
    return 'AI analysed $name\'s meals and workouts';
  }

  @override
  String get chatDemoReportSent => 'A summary report was sent to you';

  @override
  String chatDemoRoutineSent(String name) {
    return 'An AI-built routine was sent to $name';
  }

  @override
  String get chatDemoNotified => 'The client app was notified';

  @override
  String get chatInputHint => 'Type a message...';

  @override
  String get coachSheetThisClient => 'this client';

  @override
  String get coachSheetLoadFailed => 'Couldn\'t load AI coaching';

  @override
  String coachSheetTitle(String name) {
    return 'Coaching for $name';
  }

  @override
  String get coachSheetSubtitle =>
      'Answers are grounded in this client\'s meals and workouts.';

  @override
  String get coachSheetHint =>
      'e.g. Sodium keeps running high — what meals should I suggest?';

  @override
  String get coachSheetSources => 'Sources';

  @override
  String get coachSheetAsk => 'Ask';

  @override
  String get coachSheetAskAgain => 'Ask again';

  @override
  String get consultTitle => 'Consultation requests';

  @override
  String consultPendingCount(int count) {
    return '$count pending';
  }

  @override
  String get consultNoPending => 'No pending requests';

  @override
  String get consultShowAll => 'All';

  @override
  String get consultShowPending => 'Pending only';

  @override
  String get consultLoadFailed => 'Couldn\'t load consultation requests';

  @override
  String get consultRetryLater => 'Please try again in a moment';

  @override
  String get consultEmptyPending => 'No pending consultation requests';

  @override
  String get consultEmptyHistory => 'No consultation history';

  @override
  String get consultEmptyHint =>
      'Requests appear here when a member asks for a consultation with your gym or with you';

  @override
  String get consultActionFailed => 'Couldn\'t process the request';

  @override
  String consultApproved(String name) {
    return '$name is now one of your clients';
  }

  @override
  String get consultRejected => 'Request declined';

  @override
  String get consultTargetGym => 'Gym enquiry';

  @override
  String get consultTargetTrainer => 'Direct request';

  @override
  String get consultExerciseGoal => 'Training goal';

  @override
  String get consultHealthPurpose => 'Health purpose';

  @override
  String get consultPreferredTime => 'Preferred time';

  @override
  String get consultGym => 'Gym';

  @override
  String get consultReject => 'Decline';

  @override
  String get consultApprove => 'Approve';

  @override
  String get consultRejectTitle => 'Decline request';

  @override
  String get consultRejectNotice =>
      'The reason you write is sent to the member as a notification.';

  @override
  String get consultRejectHint => 'e.g. We\'re fully booked this month';

  @override
  String get consultRejectAction => 'Decline';

  @override
  String get consultStatusApproved => 'Added as a client';

  @override
  String get workoutRecords => 'Workout log';

  @override
  String get workoutLoadFailed => 'Couldn\'t load the workout log';

  @override
  String get workoutEmpty => 'No workouts logged yet';

  @override
  String get routinesAssigned => 'Assigned routines';

  @override
  String get routineNew => 'New routine';

  @override
  String get routinesLoadFailed => 'Couldn\'t load routines';

  @override
  String get routinesEmpty => 'No routines assigned to this client yet';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get ptProgramHistory => 'PT program history';

  @override
  String get scheduleLoadFailed => 'Couldn\'t load the schedule';

  @override
  String get ptSessionsEmpty => 'No PT sessions yet';

  @override
  String get labelToday => 'Today';

  @override
  String sessionTypeAndDuration(String type, int minutes) {
    return '$type · $minutes min';
  }

  @override
  String get programNone => 'No program recorded';

  @override
  String get weekCompletionRate => 'This week\'s completion';

  @override
  String get legendDone => 'Done';

  @override
  String get legendPartial => 'Partial';

  @override
  String get legendMissed => 'Missed';

  @override
  String get clientFeedback => 'Client feedback';

  @override
  String get trainerNote => 'Trainer\'s note';

  @override
  String get dietLoadFailed => 'Couldn\'t load meals';

  @override
  String get dietTodaySummary => 'Today\'s nutrition';

  @override
  String get dietSodiumTrend => 'Sodium over the last 7 days';

  @override
  String dietAverageMg(int value) {
    return 'Avg ${value}mg';
  }

  @override
  String dietSodiumOverDays(int days, int target) {
    return 'Over the ${target}mg target on $days of the last 7 days.';
  }

  @override
  String dietSodiumAllWithin(int target) {
    return 'Under the ${target}mg target every day this week. Nice!';
  }

  @override
  String dietSodiumValue(int value) {
    return 'Sodium ${value}mg';
  }

  @override
  String get dietAiAnalysis => 'AI analysis';

  @override
  String dietAiOverSodium(int over) {
    return 'Sodium is ${over}mg over target. Adding cardio to today\'s routine would help.';
  }

  @override
  String get dietAiBalanced =>
      'Today\'s meals are well balanced. Keep the current routine.';

  @override
  String get consultStatusRejected => 'Declined';

  @override
  String consultStatusRejectedWithNote(String note) {
    return 'Declined · $note';
  }

  @override
  String get dateToday => 'Today';

  @override
  String get dateTomorrow => 'Tomorrow';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String dateMonthDayWeekday(int month, int day, String weekday) {
    return '$month/$day ($weekday)';
  }

  @override
  String datePrefixed(String prefix, String date) {
    return '$prefix · $date';
  }

  @override
  String dateMonthDay(int month, int day) {
    return '$month/$day';
  }

  @override
  String dateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get reportsTitle => 'Reports';

  @override
  String reportsSubtitle(String week) {
    return 'Week of $week · operating metrics and client reports';
  }

  @override
  String get reportsPrevWeek => 'Previous week';

  @override
  String get reportsNextWeek => 'Next week';

  @override
  String get reportsLoadFailed => 'Couldn\'t load reports';

  @override
  String get reportsNoClients =>
      'No clients yet, so there\'s nothing to report on';

  @override
  String get reportsWeekly => 'Weekly report';

  @override
  String get reportsSendFailed => 'Couldn\'t send the report. Please try again';

  @override
  String reportsSent(String name) {
    return 'Report sent to $name';
  }

  @override
  String get reportsScheduleWarning =>
      'This week\'s schedule didn\'t load, so session counts may be missing';

  @override
  String get reportsSessionsThisWeek => 'Sessions this week';

  @override
  String get unitTimes => '';

  @override
  String get unitDays => 'd';

  @override
  String reportsCompletionRate(int rate) {
    return '$rate% completed';
  }

  @override
  String get reportsProgramReady => 'Programs ready';

  @override
  String get reportsSessionsWithRoutine => 'Sessions with a routine';

  @override
  String get reportsActiveClients => 'Active clients';

  @override
  String get reportsPickClient => 'Pick a client';

  @override
  String reportsClientWeekly(String name) {
    return '$name\'s weekly report';
  }

  @override
  String get reportsPtSessions => 'PT sessions';

  @override
  String get reportsCompletionAvg => 'Workout completion';

  @override
  String get reportsSodiumOver => 'Sodium over target';

  @override
  String get reportsCompletionByDay => 'Completion by day';

  @override
  String get reportsNoLastWeekDaily => 'No daily records for last week yet';

  @override
  String get reportsNoWorkoutsThisWeek => 'No workouts logged this week';

  @override
  String get reportsSodiumTrend => 'Sodium trend';

  @override
  String get reportsNoLastWeekSodium => 'No sodium trend for last week yet';

  @override
  String get reportsSendStateSent => 'Sent';

  @override
  String get reportsSendStateSending => 'Sending…';

  @override
  String get reportsSendAction => 'Send to client';

  @override
  String reportBodyTitle(String range) {
    return '📊 Weekly report · $range';
  }

  @override
  String reportBodySessions(int done, int booked) {
    return 'PT sessions: $done/$booked completed';
  }

  @override
  String reportBodyCompletion(int avg) {
    return 'Average workout completion: $avg%';
  }

  @override
  String reportBodySodium(int avg, int days) {
    return 'Average sodium: ${avg}mg · over target on $days days';
  }

  @override
  String get reportBodyPraise =>
      'Great week — let\'s keep this pace next week!';

  @override
  String get reportBodyEncourage =>
      'Let\'s tighten things up next week. I\'ll adjust your routine.';

  @override
  String get schedTitle => 'Schedule';

  @override
  String get schedSent => 'Sent';

  @override
  String get schedDeleteTitle => 'Delete session';

  @override
  String schedDeleteConfirm(String time, String name) {
    return 'Delete the $time session with $name?';
  }

  @override
  String get schedDeleteFailed =>
      'Couldn\'t delete the session. Please try again';

  @override
  String get schedCompleteFailed =>
      'Couldn\'t mark it complete. Please try again';

  @override
  String get schedViewDay => 'Day';

  @override
  String get schedViewWeek => 'Week';

  @override
  String get schedSlots => 'Booking slots';

  @override
  String get schedNewSession => 'New session';

  @override
  String get schedLoadFailed => 'Couldn\'t load the schedule';

  @override
  String get schedEmptyDay =>
      'Nothing scheduled for this day.\nAdd a session below.';

  @override
  String get schedCompleteTitle => 'Mark session complete';

  @override
  String schedCompleteBody(String time, String name) {
    return 'This marks the $time session with $name complete and logs it to their workout history.';
  }

  @override
  String get schedNoteOptional => 'Trainer\'s note (optional)';

  @override
  String get schedCompleteAction => 'Mark complete';

  @override
  String get schedNewClient => 'New client';

  @override
  String get schedSaveFailed => 'Couldn\'t save the session. Please try again';

  @override
  String get schedAddTitle => 'Add a session';

  @override
  String get schedEditTitle => 'Edit session';

  @override
  String get schedFieldClient => 'Client';

  @override
  String get schedFieldType => 'Type';

  @override
  String get schedFieldTime => 'Time';

  @override
  String get schedHourSuffix => ':00';

  @override
  String get schedMinuteSuffix => 'min';

  @override
  String get schedFieldDuration => 'Duration';

  @override
  String get schedNote => 'Trainer\'s note';

  @override
  String get schedNoteHint => 'Anything to prepare, or notes about this client';

  @override
  String get schedAddAction => 'Add';

  @override
  String get schedSaveAction => 'Save';

  @override
  String get progInvalid => 'Check the exercise name and set count';

  @override
  String get progSaveFailed => 'Couldn\'t save the program. Please try again';

  @override
  String get progEditTitle => 'Edit program';

  @override
  String get progAddExercise => 'Add exercise';

  @override
  String get progNoteHint => 'Notes to follow while running this program';

  @override
  String get progSaving => 'Saving...';

  @override
  String get progSaveAction => 'Save program';

  @override
  String get progExerciseName => 'Exercise';

  @override
  String get progDeleteExercise => 'Remove exercise';

  @override
  String get progSets => 'Sets';

  @override
  String get progReps => 'Reps/time';

  @override
  String get progWeight => 'Weight';

  @override
  String get progOptional => 'Optional';

  @override
  String progSetsByReps(int sets, String reps) {
    return '$sets × $reps';
  }

  @override
  String get progEmpty => 'No program planned yet';

  @override
  String get progEmptyHint =>
      'Build one in the AI routine tab, or agree on it over chat first.';

  @override
  String get schedEmptySlotShort => 'Empty';

  @override
  String get schedSentToClient => 'Sent to the client app';

  @override
  String schedSentTo(String name) {
    return 'Sent to $name';
  }

  @override
  String schedSentProgramTo(String name, String date) {
    return 'Sent $name the PT program for $date';
  }

  @override
  String get slotCapacityInvalid => 'Capacity must be between 1 and 100.';

  @override
  String get slotPastTime =>
      'Booking slots can only be opened for future times.';

  @override
  String get slotOpened => 'Booking slot opened.';

  @override
  String get slotEditTitle => 'Edit booking slot';

  @override
  String get slotStartTime => 'Start time';

  @override
  String get slotCapacity => 'Capacity';

  @override
  String slotBookedNow(int count) {
    return '$count booked';
  }

  @override
  String get slotUpdated => 'Booking slot updated.';

  @override
  String get slotCloseTitle => 'Close booking slot';

  @override
  String slotCloseBody(int count) {
    return 'The $count existing bookings stay; only new bookings stop.';
  }

  @override
  String get slotClosed => 'New bookings closed.';

  @override
  String get slotActionFailed =>
      'Couldn\'t complete the request. Please try again in a moment.';

  @override
  String get slotManageTitle => 'Manage booking slots';

  @override
  String slotIntro(String date) {
    return 'Open times for members to book on $date.';
  }

  @override
  String get slotOpenAction => 'Open';

  @override
  String get slotReload => 'Reload';

  @override
  String get slotEmpty => 'No booking slots open on this day.';

  @override
  String slotClosedSummary(int booked) {
    return 'Closed · $booked booked';
  }

  @override
  String slotOpenSummary(int booked, int remaining) {
    return '$booked booked · $remaining left';
  }

  @override
  String get slotCloseAction => 'Close bookings';
}
