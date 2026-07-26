// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'On-Care';

  @override
  String get navDashboard => 'Home';

  @override
  String get navDiet => 'Diet';

  @override
  String get navExercise => 'Exercise';

  @override
  String get navMyHealth => 'MY';

  @override
  String get pageDashboardTitle => 'Home';

  @override
  String get pageDietTitle => 'Diet';

  @override
  String get pageExerciseTitle => 'Exercise';

  @override
  String get pageMyHealthTitle => 'My';

  @override
  String get pageAiCoachTitle => 'AI Coach';

  @override
  String get pageNotificationTitle => 'Notifications';

  @override
  String get pagePlaceTitle => 'Place';

  @override
  String get pageSignInTitle => 'Sign in';

  @override
  String get actionOpenAiCoach => 'Open AI Coach';

  @override
  String get actionFindPlace => 'Find a place';

  @override
  String get actionSignInPlaceholder => 'Sign in (placeholder)';

  @override
  String get actionRetry => 'Retry';

  @override
  String get placeholderDashboard => 'Dashboard (placeholder)';

  @override
  String get placeholderDiet => 'Diet Record (placeholder)';

  @override
  String get placeholderExercise => 'Exercise (placeholder)';

  @override
  String get placeholderMyHealth => 'My Health (placeholder)';

  @override
  String get placeholderAiCoach => 'AI Coach (placeholder, mock responses)';

  @override
  String get placeholderNotification => 'Notifications (placeholder)';

  @override
  String get placeholderPlace => 'Place (placeholder, Google Maps in Stage 4)';

  @override
  String get placeholderSignIn =>
      'Sign in (placeholder, social SDKs in Stage 4)';

  @override
  String get errorNetwork => 'Network problem';

  @override
  String get errorUnauthorized => 'Sign in required';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get errorServer => 'Server error';

  @override
  String get errorCancelled => 'Cancelled';

  @override
  String get errorUnknown => 'Something went wrong';

  @override
  String get dashboardSectionToday => 'Today';

  @override
  String get dashboardMetricCalories => 'Calories';

  @override
  String get dashboardMetricExercise => 'Exercise';

  @override
  String get dashboardMetricWeight => 'Weight';

  @override
  String get dashboardChartWeightWeek => 'Weekly weight';

  @override
  String dashboardCaloriesProgress(int pct, int goal) {
    return '$pct% of $goal';
  }

  @override
  String dashboardWeightDelta(String sign, String delta) {
    return '$sign$delta vs last week';
  }

  @override
  String homeGreeting(String name) {
    return '$name, let\'s ease into the day 👋';
  }

  @override
  String get homeGreetingGeneric => 'Let\'s ease into the day 👋';

  @override
  String get homeCoachingPill => '✦ AI Coaching';

  @override
  String get homeCoachingTitle => 'Today\'s tailored advice';

  @override
  String get homeCoachingBody =>
      'Cut back on sodium at dinner and\ntake about a 20-minute walk';

  @override
  String get homeCoachingReady => 'AI prepared 3 tailored tips for you today';

  @override
  String get homeDietSodiumAlert => 'Sodium over limit detected';

  @override
  String get homeMacroCarbs => 'Carbs';

  @override
  String get homeMacroProtein => 'Protein';

  @override
  String get homeMacroFat => 'Fat';

  @override
  String get homeDietRecBadge => '✦ AI dinner recommendation';

  @override
  String get homeMealChickenSalad => 'Chicken breast salad';

  @override
  String get homeDietRecRice => 'Half bowl of brown rice';

  @override
  String get homeDietLogButton => 'Log diet →';

  @override
  String get homeExerciseRoutineProgress => 'AI routine 1/3 done';

  @override
  String homeExerciseBurnGoal(String unit, int goal) {
    return '$unit burned · Goal $goal';
  }

  @override
  String get homeExerciseBrisk => 'Brisk walking';

  @override
  String get homeExerciseLegStretch => 'Lower-body stretch';

  @override
  String get homeExerciseRecBadge => '✦ AI remaining routine';

  @override
  String get homeExerciseRecStretch => 'Lower-body stretch 10 min';

  @override
  String get homeExerciseRecStrength => 'Low-intensity strength 15 min';

  @override
  String get homeExerciseLogButton => 'Log exercise →';

  @override
  String get homeSummaryToday => 'Today total';

  @override
  String get homeVsGoal => 'vs goal';

  @override
  String get homeNutritionTitle => 'Nutrition status';

  @override
  String get homeAiAnalysisPill => '✦ AI analysis';

  @override
  String get homeNutritionSubtitle => 'Weekly trend · vs last week';

  @override
  String get homeDetails => 'Details';

  @override
  String get homeThisWeekAvg => 'This week avg';

  @override
  String get homeLastWeekAvg => 'Last week avg';

  @override
  String get homeGoal => 'Goal';

  @override
  String get homeVsLastWeek => 'vs last week';

  @override
  String homeSodiumInsight(String trend, String alert) {
    return 'Sodium intake has been $trend. Cut back on salt and turn on $alert?';
  }

  @override
  String get homeSodiumInsightTrend => 'rising for 2 weeks';

  @override
  String get homeSodiumInsightAlert => 'high-sodium meal alerts';

  @override
  String get homeAiPill => '✦ AI';

  @override
  String get homeLegendThisWeek => 'This week';

  @override
  String get homeLegendLastWeek => 'Last week';

  @override
  String get homeLegendToday => 'Today';

  @override
  String get homeMealReasonSodium => 'Great for sodium control';

  @override
  String get homeMealTagLowSodium => 'Low sodium';

  @override
  String get homeMealBrownRiceBox => 'Brown rice lunchbox';

  @override
  String get homeMealReasonGlucose => 'Helps steady blood sugar';

  @override
  String get homeMealTagLowGi => 'Low GI';

  @override
  String get homeMealSalmon => 'Grilled salmon + greens';

  @override
  String get homeMealReasonOmega => 'Omega-3 + fiber';

  @override
  String get homeMealTagHighProtein => 'High protein';

  @override
  String get homeMealTofu => 'Stir-fried tofu & veggies';

  @override
  String get homeMealReasonLowCal => 'Low calorie, keeps you full';

  @override
  String get homeMealTagLowCal => 'Low calorie';

  @override
  String get homeRecMealsTitle => 'This week\'s AI meal picks';

  @override
  String get homeViewAll => 'View all';

  @override
  String homeScheduleDate(String weekday, int month, int day) {
    return '$weekday, $month/$day';
  }

  @override
  String get homeScheduleTitle => 'Today\'s schedule';

  @override
  String get homeScheduleEveningWalk => 'Evening walk';

  @override
  String get homeScheduleWalkDetail => 'Around home · 20 min';

  @override
  String get unitKcal => 'kcal';

  @override
  String get unitMinutes => 'min';

  @override
  String unitKcalValue(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString kcal';
  }

  @override
  String unitMinutesValue(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString min';
  }

  @override
  String get unitKg => 'kg';

  @override
  String get dietTitle => 'Diet';

  @override
  String get dietToday => 'Today';

  @override
  String dietWeekLabel(int month, int week) {
    return 'Month $month, Week $week';
  }

  @override
  String get dietWeekdayMon => 'Mon';

  @override
  String get dietWeekdayTue => 'Tue';

  @override
  String get dietWeekdayWed => 'Wed';

  @override
  String get dietWeekdayThu => 'Thu';

  @override
  String get dietWeekdayFri => 'Fri';

  @override
  String get dietWeekdaySat => 'Sat';

  @override
  String get dietWeekdaySun => 'Sun';

  @override
  String get dietNutritionSummary => 'Today\'s Nutrition';

  @override
  String get dietCalories => 'Calories';

  @override
  String get dietSodium => 'Sodium';

  @override
  String get dietSugar => 'Sugar';

  @override
  String get dietUnitMg => 'mg';

  @override
  String get dietUnitG => 'g';

  @override
  String get dietAiFeedback => 'AI Feedback';

  @override
  String get dietTodayMeals => 'Today\'s Meals';

  @override
  String get dietAddMeal => 'Add Meal';

  @override
  String get dietEmptyLog =>
      'No meals logged yet.\nAdd your first meal with a photo!';

  @override
  String get dietPhotoAnalysis => 'Photo Analysis';

  @override
  String get dietLoadError => 'Couldn\'t load your diet.';

  @override
  String get dietOtherDateEmpty =>
      'Records for the selected date aren\'t available yet.\nPlease check your diet on today\'s date.';

  @override
  String dietTagSodium(int mg) {
    return 'Sodium ${mg}mg';
  }

  @override
  String dietTagSugar(int g) {
    return 'Sugar ${g}g';
  }

  @override
  String get dietMealBreakfast => 'Breakfast';

  @override
  String get dietMealLunch => 'Lunch';

  @override
  String get dietMealDinner => 'Dinner';

  @override
  String get dietMealSnack => 'Snack';

  @override
  String dietMealSheetTitle(String meal) {
    return '$meal';
  }

  @override
  String get dietAddSheetTitle => 'Add a Meal';

  @override
  String get dietAddSheetSubtitle => 'Analyze your food from a photo';

  @override
  String get dietPickPhoto => 'Choose a Photo';

  @override
  String get dietPickPhotoSub => 'Pick a food photo from your gallery';

  @override
  String get dietTakePhoto => 'Take a Photo';

  @override
  String get dietTakePhotoSub => 'Snap your food with the camera';

  @override
  String get dietPhotoLoadError =>
      'Couldn\'t load the photo. Please try again in a moment.';

  @override
  String get dietAnalyzing => 'Analyzing…';

  @override
  String get dietAnalysisFailed => 'Analysis failed';

  @override
  String get dietAnalysisDone => 'Analysis complete!';

  @override
  String get dietAiNutritionResult => 'AI Nutrition Result';

  @override
  String get dietAnalyzingBody => 'Analyzing the food in your photo';

  @override
  String get dietAnalysisFailedBody =>
      'Analysis failed. Please try again in a moment.';

  @override
  String get dietRecognizedFood => 'Recognized Food';

  @override
  String get dietNoRecognizedFood => 'No food recognized';

  @override
  String get dietNutritionResult => 'Nutrition Result';

  @override
  String get dietSaved => 'Meal saved';

  @override
  String get dietDone => 'Done';

  @override
  String get dietSaveFailed => 'Couldn\'t save. Please try again in a moment.';

  @override
  String get dietDeleteTitle => 'Delete Meal Record';

  @override
  String get dietDeleteConfirm => 'Delete this meal record?';

  @override
  String get dietCancel => 'Cancel';

  @override
  String get dietDelete => 'Delete';

  @override
  String get dietDeleted => 'Meal deleted';

  @override
  String get dietDeleteFailed =>
      'Couldn\'t delete. Please try again in a moment.';

  @override
  String get dietSave => 'Save';

  @override
  String get dietMealInfo => 'Meal Info';

  @override
  String get dietEatenTime => 'Time Eaten';

  @override
  String get dietEatenFood => 'Food Eaten';

  @override
  String get dietNewFood => 'New food';

  @override
  String get dietAddFood => '+ Add Food';

  @override
  String get dietEditFoodHint => 'You can edit the food name and calories';

  @override
  String get dietTotalCalories => 'Total Calories';

  @override
  String get dietNutritionInfo => 'Nutrition Info';

  @override
  String get dietEditNutritionHint =>
      'You can edit the analyzed values directly';

  @override
  String get dietSodiumHint => 'Recommended under 2,000mg/day';

  @override
  String get dietSugarHint => 'Recommended under 50g/day';

  @override
  String get dietDeleteMeal => 'Delete Meal';

  @override
  String get exTypeWalking => 'Walking';

  @override
  String get exTypeCardio => 'Cardio';

  @override
  String get exTypeStrength => 'Strength';

  @override
  String get exTypeYoga => 'Yoga';

  @override
  String get exTypeStretching => 'Stretching';

  @override
  String get exTypeOther => 'Exercise';

  @override
  String get exTypeOtherChip => 'Other';

  @override
  String get exLevelLight => 'Light';

  @override
  String get exLevelModerate => 'Moderate';

  @override
  String get exLevelHigh => 'High';

  @override
  String get exExerciseLog => 'Exercise Log';

  @override
  String get exGymTab => 'Gym';

  @override
  String get exWeekSummary => 'This Week\'s Summary';

  @override
  String get exActivityTitle => 'Activity';

  @override
  String get exThisWeek => 'This week';

  @override
  String get exAiRoutineToday => 'AI Routine · Today';

  @override
  String get exStatTime => 'Time';

  @override
  String get exStatCalories => 'Calories';

  @override
  String get exStatStreak => 'Streak';

  @override
  String get exUnitCount => 'times';

  @override
  String get exUnitStreakDays => 'day streak';

  @override
  String get exToday => 'Today';

  @override
  String get exLoadError => 'Couldn\'t load your exercise data.';

  @override
  String get exEmptyLog =>
      'No workouts logged this week.\nAdd one to start your log!';

  @override
  String get exAiFeedback => 'AI Feedback';

  @override
  String get exAddExercise => 'Add Exercise';

  @override
  String get exRoutineBriskTitle => 'Brisk walking 30 min';

  @override
  String get exRoutineBriskSub => 'Cardio · Blood pressure';

  @override
  String get exRoutineStretchTitle => 'Lower-body stretch';

  @override
  String get exRoutineStretchSub => 'Stretching · Flexibility';

  @override
  String get exRoutineStrengthTitle => 'Low-intensity strength';

  @override
  String get exRoutineStrengthSub => 'Strength · Endurance';

  @override
  String get exMissionComplete => 'Mission complete!';

  @override
  String exMinutesExercise(int minutes) {
    return '$minutes min exercise';
  }

  @override
  String exDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get exEditExercise => 'Edit Exercise Record';

  @override
  String get exSave => 'Save';

  @override
  String get exExerciseType => 'Exercise Type';

  @override
  String get exExerciseDuration => 'Duration';

  @override
  String get exExerciseIntensity => 'Intensity';

  @override
  String get exEstimatedCalories => 'Estimated Calories';

  @override
  String get exEnterDuration => 'Please enter a duration';

  @override
  String get exCannotEdit => 'This record can\'t be edited';

  @override
  String get exUpdated => 'Exercise record updated';

  @override
  String get exLogged => 'Exercise logged';

  @override
  String get exSaveFailed => 'Couldn\'t save. Please try again in a moment';

  @override
  String get exFindGym => 'Find a Gym';

  @override
  String get exGymSearchHint => 'Search by gym or area';

  @override
  String get exNearbyGyms => 'Nearby Gyms · O2O';

  @override
  String get exAiAnalysis => '✦ AI analysis';

  @override
  String exNoGymMatch(String query) {
    return 'No gyms match \'$query\'';
  }

  @override
  String get exGymsLoadError => 'Couldn\'t load gyms.';

  @override
  String get exAiTopPick => '✦ AI top pick';

  @override
  String get exTrainerChat => 'Trainer Chat';

  @override
  String get exSendHealthSummary => 'Share Health Summary';

  @override
  String exSendHealthSummaryBody(String gym) {
    return 'Share your recent workouts and health profile summary\nwith the $gym trainer?';
  }

  @override
  String get exCancel => 'Cancel';

  @override
  String get exSend => 'Share';

  @override
  String exHealthSummarySent(String gym) {
    return 'Shared your health summary with $gym';
  }

  @override
  String exReasonTrainer(String name, String role) {
    return 'Personal trainer $name$role on site';
  }

  @override
  String exReasonHours(String hours, String weekend) {
    return 'Open $hours$weekend';
  }

  @override
  String exGymWeekdayHours(String hours) {
    return 'Weekdays $hours';
  }

  @override
  String exGymWeekendHours(String hours) {
    return 'Weekends $hours';
  }

  @override
  String get exTrainer => 'Trainer';

  @override
  String get exMyGym => 'My Gym';

  @override
  String get exTrainerDedicated => 'Personal trainer';

  @override
  String get exAiSlotTitle => '✦ AI recommended times';

  @override
  String exTrainerAvailability(String trainer) {
    return '$trainer\'s openings';
  }

  @override
  String get exSlotToday19 => 'Today 19:00';

  @override
  String get exSlotTomorrow0730 => 'Tomorrow 07:30';

  @override
  String get exSlotTomorrow20 => 'Tomorrow 20:00';

  @override
  String get exSlot1Left => '1 spot left';

  @override
  String get exSlotAvailable => 'Open';

  @override
  String get exSlot2Left => '2 spots left';

  @override
  String exReserveConfirmedSlotGym(String slot, String gym) {
    return '$slot · $gym reservation confirmed';
  }

  @override
  String exReserveConfirm(String slot) {
    return 'Confirm $slot';
  }

  @override
  String get exGymInfo => 'Gym Info';

  @override
  String get exConsultButton => '💬 1:1 Consult';

  @override
  String get exGymLoadError => 'Couldn\'t load the gym.';

  @override
  String get exNoGymTitle => 'No gym registered';

  @override
  String get exNoGymSub => 'Register a nearby gym with Find a Gym';

  @override
  String get exAddress => 'Address';

  @override
  String get exHours => 'Hours';

  @override
  String get exPhone => 'Phone';

  @override
  String get exSpecialty => 'Specialties';

  @override
  String get exKakaoMapArea => 'Kakao Map area';

  @override
  String get exDefaultTrainerName => 'Trainer Kim';

  @override
  String get exDefaultGymName => 'Gangnam Fitness Center';

  @override
  String exChatGreeting(String trainer) {
    return 'Hello, I\'m $trainer. 😊\nHow can I help you?';
  }

  @override
  String get exChatChipPt => 'PT consult';

  @override
  String get exChatChipPass => 'Membership inquiry';

  @override
  String get exChatChipVisit => 'Book a visit';

  @override
  String get exChatReply =>
      'Got it! Your trainer will reply soon. Please share a convenient time to visit. 🙌';

  @override
  String exGymConsultSubtitle(String gym) {
    return '$gym · 1:1 Consult';
  }

  @override
  String get exMessageHint => 'Type a message';

  @override
  String get myTabTitle => 'MY';

  @override
  String get myDefaultUserName => 'User';

  @override
  String myRank(int rank) {
    return 'Rank $rank';
  }

  @override
  String get mySettingsTitle => 'Settings';

  @override
  String get myProfileTitle => 'My Profile';

  @override
  String get myGoalsTitle => 'Health Goals';

  @override
  String get myNotifTitle => 'Notification Settings';

  @override
  String get mySupportTitle => 'Customer Support';

  @override
  String get myLogout => 'Log out';

  @override
  String get myLogoutConfirm => 'Log out of your account?';

  @override
  String get myCancel => 'Cancel';

  @override
  String get mySave => 'Save';

  @override
  String get myProfileSaved => 'Profile saved';

  @override
  String get myGoalsSaved => 'Health goals saved';

  @override
  String get mySaveFailed => 'Couldn\'t save. Please try again in a moment';

  @override
  String get myFieldName => 'Name';

  @override
  String get myFieldEmail => 'Email';

  @override
  String get myFieldPhone => 'Phone';

  @override
  String get myFieldBirth => 'Date of birth';

  @override
  String get myGoalsDesc =>
      'Summaries and feedback across the app are based on these goals.';

  @override
  String get myGoalWeight => 'Target weight';

  @override
  String get myGoalBp => 'Target blood pressure (systolic)';

  @override
  String get myGoalBloodSugar => 'Target blood sugar';

  @override
  String get myGoalCalories => 'Daily calories';

  @override
  String get myGoalSodium => 'Sodium limit';

  @override
  String get myNotifDietLog => 'Diet log reminder';

  @override
  String get myNotifExercise => 'Exercise reminder';

  @override
  String get myNotifTrainer => 'Trainer message';

  @override
  String get myNotifAiCoaching => 'AI coaching tips';

  @override
  String get myNotifWeeklyReport => 'Weekly report';

  @override
  String get mySupportFaq => 'FAQ';

  @override
  String get mySupportInquiry => '1:1 Inquiry';

  @override
  String get myLegalTermsTitle => 'Terms of Service';

  @override
  String get myLegalPrivacyTitle => 'Privacy Policy';

  @override
  String get myLegalTermsBody => 'Terms of Service (Korean original governs).';

  @override
  String get myLegalPrivacyBody => 'Privacy Policy (Korean original governs).';

  @override
  String get myLegalEffectiveDate => 'Effective Jan 1, 2026';

  @override
  String get myAppVersion => 'On-Care · Version 1.0.0';

  @override
  String myComingSoon(String label) {
    return '$label is coming soon';
  }

  @override
  String get coachHeaderPill => 'AI Health Assistant';

  @override
  String get coachHeaderSubtitle => 'Here are today\'s tailored tips';

  @override
  String get coachCardDietTag => 'Diet';

  @override
  String get coachCardDietTitle => 'Try easing back on sodium at dinner.';

  @override
  String get coachCardDietBody => 'Grilled dishes or a salad are great.';

  @override
  String get coachCardExerciseTag => 'Exercise';

  @override
  String get coachCardExerciseTitle => 'A 20-minute evening walk.';

  @override
  String get coachCardExerciseBody =>
      'A light walk after meals helps manage blood sugar.';

  @override
  String get coachCardWaterTag => 'Hydration';

  @override
  String get coachCardWaterTitle => 'Drink one more glass of water.';

  @override
  String get coachCardWaterBody => 'You\'ve been quite active today.';

  @override
  String get coachProgressLabel => 'Today\'s recommendation progress';

  @override
  String coachProgressDone(int done, int total) {
    return '$done/$total done';
  }

  @override
  String get coachCtaChat => 'Chat with AI';

  @override
  String get navAddRecordTitle => 'Add a record';

  @override
  String get navAddRecordSubtitle => 'Choose diet or exercise';

  @override
  String get navDietOptionSub => 'Nutrition analysis from a photo';

  @override
  String get navExerciseOptionSub => 'Log the type and duration';

  @override
  String get aicHeaderSubtitle => 'Ask me anytime';

  @override
  String get aicDatePillToday => 'Today';

  @override
  String get aicInputHint => 'Ask the AI anything';

  @override
  String get aicQuickRepliesLabel => 'Try asking';

  @override
  String get aicQuickReply1 => 'Recommend a dinner menu for today';

  @override
  String get aicQuickReply2 => 'How much should I exercise today?';

  @override
  String get aicQuickReply3 => 'How are my blood sugar readings?';
}
