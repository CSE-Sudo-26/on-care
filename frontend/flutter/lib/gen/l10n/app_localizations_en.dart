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
  String get pageDietTitle => 'Diet';

  @override
  String get pageExerciseTitle => 'Exercise';

  @override
  String get pageAiCoachTitle => 'AI Coach';

  @override
  String get pageNotificationTitle => 'Notifications';

  @override
  String get actionRetry => 'Retry';

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
  String get dashboardMetricCalories => 'Calories';

  @override
  String get dashboardMetricExercise => 'Weekly exercise';

  @override
  String get homeDashboardLoadError => 'Could not load the dashboard.';

  @override
  String get homeDashboardEmpty =>
      'No records yet today. Add a meal or workout to get started.';

  @override
  String get homeScheduleEmpty => 'No events scheduled for today.';

  @override
  String get homeAiAdviceTitle => 'Today\'s combined AI advice';

  @override
  String get homeAiAdviceBody =>
      'Your breakfast and evening PT were perfect! To bring down the sodium and blood sugar raised by the lunch jjamppong, drink plenty of water and finish well with the shoulder stretches your coach emphasized.';

  @override
  String get homeSodiumExceededBadge => 'Sodium over';

  @override
  String get homeMacroCarbs => 'Carbs';

  @override
  String get homeMacroProtein => 'Protein';

  @override
  String get homeMacroFat => 'Fat';

  @override
  String get homeMealChickenSalad => 'Chicken breast salad';

  @override
  String get homeDetails => 'Details';

  @override
  String get homeGoal => 'Goal';

  @override
  String get homeDietNutritionTitle => 'Diet & nutrition';

  @override
  String get homeCalorieIntake => 'Today\'s calories';

  @override
  String get homeAchieveRate => 'Progress';

  @override
  String homeWeeklyMetricTrend(String metric) {
    return 'Weekly $metric trend';
  }

  @override
  String get homeWeeklyExerciseTrend => 'Exercise trend';

  @override
  String get homeExerciseTrendUnavailable =>
      'Couldn\'t load this week\'s workout history.';

  @override
  String get homeExerciseActiveTime => 'Active time';

  @override
  String get homeExerciseBurned => 'Calories';

  @override
  String get homeExerciseDays => 'Workout days';

  @override
  String get homeMealReasonSodium => 'Great for sodium control';

  @override
  String get homeMealSourceTrainer => 'Trainer pick';

  @override
  String get homeMealSourceAi => 'AI pick';

  @override
  String get homeMealTagLowSodium => 'Low sodium';

  @override
  String get homeMealBrownRiceBox => 'Brown rice lunchbox';

  @override
  String get homeMealReasonGlucose => 'Helps steady blood sugar';

  @override
  String get homeMealTagLowSugar => 'Low sugar';

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
  String get homeMealNamulBibimbap => 'Namul bibimbap';

  @override
  String get homeMealReasonFiber => 'Rich in dietary fiber';

  @override
  String get homeMealTagLowFat => 'Low fat';

  @override
  String homeRecBasisSodium(int days, String sodium) {
    return '$days-day avg sodium ${sodium}mg';
  }

  @override
  String get homeRecBasisOverLimit => 'over the daily limit';

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
  String get unitKcal => 'kcal';

  @override
  String get unitMinutes => 'min';

  @override
  String get unitDays => 'days';

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
  String get dietTitle => 'Diet';

  @override
  String get dietToday => 'Today';

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
  String get dietNutritionSummary => 'Nutrition';

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
  String get dietAiFeedback => 'AI advice';

  @override
  String get dietMealLog => 'Meal Log';

  @override
  String get dietAddMeal => 'Add Meal';

  @override
  String get dietEmptyLog => 'No meals logged.\nAdd a meal with a photo!';

  @override
  String get dietLoadError => 'Couldn\'t load your diet.';

  @override
  String get dietPeriodAverage => 'Daily average';

  @override
  String get dietPeriodTotal => 'Period total';

  @override
  String get dietPeriodEmpty => 'No meals were logged in this period.';

  @override
  String dietPeriodRange(String start, String end) {
    return '$start - $end';
  }

  @override
  String get dietPeriodNoRecord => 'No record';

  @override
  String get dietPeriodNotYet => 'Not yet';

  @override
  String dietPeriodOverGoal(String amount, String unit) {
    return '$amount $unit over goal';
  }

  @override
  String otherDateEmpty(Object section) {
    return 'No $section records for the selected date.';
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
  String get dietCameraPermissionDenied =>
      'Camera permission is needed to photograph your meal. Tap Take Photo to try again.';

  @override
  String get dietCameraPermissionPermanentlyDenied =>
      'Camera access is off. Turn it on in Settings to photograph your meal.';

  @override
  String get dietPhotoPermissionDenied =>
      'Photo permission is needed to choose a meal photo. Tap Choose Photo to try again.';

  @override
  String get dietPhotoPermissionPermanentlyDenied =>
      'Photo access is off. Turn it on in Settings to choose a meal photo.';

  @override
  String get dietPhotoPermissionRestricted =>
      'Camera or photo access is unavailable because of this device\'s settings or management policy.';

  @override
  String get dietPhotoUnsupportedFormat =>
      'That photo format isn\'t supported. Please try a JPG or PNG photo.';

  @override
  String get dietPhotoTooLarge =>
      'That photo is too large. Please try a different one.';

  @override
  String get dietOpenSettings => 'Open Settings';

  @override
  String get dietOpenSettingsFailed =>
      'Couldn\'t open Settings. Turn on camera and photo access under Settings > Oncare.';

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
  String get dietAnalysisUnsupportedFormat =>
      'This photo format can\'t be analyzed. Please pick a JPG or PNG photo instead.';

  @override
  String get dietAnalysisBadRequest =>
      'The photo couldn\'t be read. Please pick a different one.';

  @override
  String get dietAnalysisUnauthorized =>
      'Your session expired. Please sign in again to log this meal.';

  @override
  String get dietAnalysisNotImplemented =>
      'Photo analysis is unavailable right now. Please log the meal manually.';

  @override
  String get dietAnalysisPickAnother => 'Pick another photo';

  @override
  String get dietAnalysisSignIn => 'Sign in again';

  @override
  String get dietAnalysisClose => 'Close';

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
  String get exMyGymSection => 'My Gym';

  @override
  String get exConnected => 'Connected';

  @override
  String get exRecommendedGyms => 'Recommended Gyms';

  @override
  String get exRecommendedTrainers => 'Recommended Trainers';

  @override
  String get exSeeMore => 'See more';

  @override
  String get exNoConnectedGym => 'You don\'t have a connected gym yet.';

  @override
  String get exNoRecommendedGyms => 'No gym recommendations yet.';

  @override
  String get exNoRecommendedTrainers => 'No trainer recommendations yet.';

  @override
  String get exTrainerAffiliation => 'Gym';

  @override
  String get exTrainerIntroSection => 'About the trainer';

  @override
  String exTrainerCareer(String career) {
    return '$career of experience';
  }

  @override
  String get exTrainerCertifications => 'Certifications';

  @override
  String get exTrainerRecommendationReason =>
      'A great fit for reaching my health goals';

  @override
  String get exNearbyGymsMapLabel => 'Gyms near me';

  @override
  String get exWeekSummary => 'This Week\'s Summary';

  @override
  String get exActivityTitle => 'Activity';

  @override
  String exWeekOfMonthLabel(int month, int week) {
    return 'Week $week, $month/';
  }

  @override
  String get exBurnTodayTitle => 'Burned today';

  @override
  String get exBurnWeekTitle => 'Burned this week';

  @override
  String get exBurnAllTitle => 'Average burned';

  @override
  String get exLoadDayTitle => 'Burned';

  @override
  String exGoalValue(String value) {
    return 'Goal $value';
  }

  @override
  String get exLoadEmpty => 'No records yet.';

  @override
  String get exThisWeek => 'This week';

  @override
  String get exPeriodAll => 'All';

  @override
  String get exExerciseContent => 'What you did';

  @override
  String get exViewDetail => 'View details';

  @override
  String get exRegister => 'Register';

  @override
  String exGymRegistered(String gym) {
    return 'Registered $gym';
  }

  @override
  String get actionClose => 'Close';

  @override
  String exWeekNumber(int n) {
    return 'Week $n';
  }

  @override
  String get exTodayTotalTime => 'Today\'s total time';

  @override
  String get exRest => 'Rest';

  @override
  String get exAiRecommendedExercise => 'AI recommended exercise';

  @override
  String get exStatTime => 'Time';

  @override
  String get exStatCalories => 'Calories';

  @override
  String get exStatStreak => 'Streak';

  @override
  String get exUnitStreakDays => 'day streak';

  @override
  String exStreakCheer(int days) {
    return '$days days in a row!';
  }

  @override
  String get exStreakStart => 'Start a streak with today\'s workout.';

  @override
  String get exToday => 'Today';

  @override
  String get exLoadError => 'Couldn\'t load your exercise data.';

  @override
  String get exCompletedPtTitle => 'Today\'s completed PT';

  @override
  String exCompletedPtTime(String time) {
    return '$time completed';
  }

  @override
  String get exCompletedPtNoProgram => 'No workout program was recorded.';

  @override
  String exCompletedPtFeedback(String coachName) {
    return '$coachName · Today\'s feedback';
  }

  @override
  String exProgramSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String get exAddExercise => 'Add Exercise';

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
  String get exFindTrainer => 'Find a Trainer';

  @override
  String get exGymDetailTitle => 'Gym Details';

  @override
  String get exTrainerDetailTitle => 'Trainer Details';

  @override
  String get exDistance => 'Distance';

  @override
  String get exRating => 'Rating';

  @override
  String get exAffiliatedTrainer => 'Affiliated Trainer';

  @override
  String get exRecommendationReason => 'Why we recommend this trainer';

  @override
  String get exGymNotFound => 'Couldn\'t find this gym.';

  @override
  String get exTrainerNotFound => 'Couldn\'t find this trainer.';

  @override
  String get exGymSearchPlaceholder => 'Search by area or gym name';

  @override
  String get exTrainerSearchPlaceholder =>
      'Search by specialty or trainer name';

  @override
  String get exSortRecommended => 'Recommended';

  @override
  String get exSortDistance => 'Distance';

  @override
  String get exSortRating => 'Rating';

  @override
  String get exSortName => 'Name';

  @override
  String exResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get exNoSearchResults => 'No search results.';

  @override
  String get exTrainersLoadError => 'Couldn\'t load trainers.';

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
  String get exGymDetailHint => 'See trainers and request a consultation';

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
  String get exTrainerDedicated => 'Personal trainer';

  @override
  String exTrainerAvailability(String trainer) {
    return '$trainer\'s open booking times';
  }

  @override
  String exSlotWhen(String date, String time) {
    return '$date $time';
  }

  @override
  String get exSlotFull => 'Fully booked';

  @override
  String get exSlotTypePersonalTraining => '1:1 PT';

  @override
  String get exSlotTypeConsultation => 'Consultation';

  @override
  String get exSlotsEmpty => 'No times available';

  @override
  String get exSlotsAllBooked => 'All available times are fully booked';

  @override
  String get exSlotsLoadError => 'Could not load available times.';

  @override
  String get exReserveFailed => 'Could not book that time. Please try again.';

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
  String get myTabTitle => 'MY';

  @override
  String get myDefaultUserName => 'User';

  @override
  String get mySettingsTitle => 'Settings';

  @override
  String get myProfileTitle => 'My Profile';

  @override
  String get myNotifTitle => 'Notification Settings';

  @override
  String get mySupportTitle => 'Customer Support';

  @override
  String get myPointsBenefitsTitle => 'Use Points';

  @override
  String myPointsBalance(int points) {
    return 'Balance: ${points}P';
  }

  @override
  String get myPointsBenefitsSubtitle => 'Benefits available with points';

  @override
  String get myPointsBenefitsHint =>
      'Keep logging your activity to earn points and use the benefits above.';

  @override
  String get myPointsDiscountTitle => 'Cash discount with points';

  @override
  String get myPointsDiscountDescription =>
      'Use points like cash for up to 10% off 1:1 coaching and personal training.';

  @override
  String get myPointsDiscountCost => 'Up to 10%';

  @override
  String get myPointsReportTitle => 'Unlock glucose and blood pressure reports';

  @override
  String get myPointsReportDescription =>
      'View comprehensive weekly and monthly health-data reports.';

  @override
  String get myPointsReportCost => '500P';

  @override
  String get myPointsRecipeTitle => 'Personalized healthy recipe package';

  @override
  String get myPointsRecipeDescription =>
      'Get PDF and interactive meal guides tailored to goals such as diabetes prevention or weight loss.';

  @override
  String get myPointsRecipeCost => '500P';

  @override
  String get myLogout => 'Log out';

  @override
  String get myLogoutConfirm => 'Log out of your account?';

  @override
  String get myCancel => 'Cancel';

  @override
  String get myTrainerGymTitle => 'My Trainer & Gym';

  @override
  String get myConnectionDeleteTitle => 'Remove Connection';

  @override
  String get myDelete => 'Remove';

  @override
  String myGymDisconnectWithTrainerConfirm(String gym, String trainer) {
    return 'Disconnect $gym?\nYour trainer link with $trainer will also be removed.';
  }

  @override
  String myGymDisconnectConfirm(String gym) {
    return 'Disconnect $gym?';
  }

  @override
  String myTrainerDisconnectConfirm(String trainer, String gym) {
    return 'Disconnect trainer $trainer?\nYour connection to $gym will remain.';
  }

  @override
  String get myGymDetailTooltip => 'Gym details';

  @override
  String get myTrainerDetailTooltip => 'Trainer details';

  @override
  String get myGymDisconnectTooltip => 'Disconnect gym';

  @override
  String get myTrainerDisconnectTooltip => 'Disconnect trainer';

  @override
  String get myNoTrainer => 'No assigned trainer';

  @override
  String get myNoGymConnected => 'No gym connected yet';

  @override
  String get myGymLoadFailed => 'Couldn\'t load your gym connection.';

  @override
  String get mySave => 'Save';

  @override
  String get myProfileSaved => 'Profile saved';

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
  String get myFieldGender => 'Gender';

  @override
  String get myFieldHeight => 'Height (cm)';

  @override
  String get myFieldWeight => 'Weight (kg)';

  @override
  String get myFieldGoals => 'Health and exercise goals';

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
  String get coachHeaderPill => 'AI Health Assistant';

  @override
  String get coachHeaderSubtitle => 'Here are today\'s tailored tips';

  @override
  String get coachCardDietTag => 'Diet';

  @override
  String get coachCardDietTitle => 'Great breakfast — watch lunch sodium';

  @override
  String get coachCardDietBody =>
      'Your breakfast was great, but the lunch jjamppong is heavy on sodium and sugar, so drink plenty of water to help flush the sodium out.';

  @override
  String get coachCardExerciseTag => 'Exercise';

  @override
  String get coachCardExerciseTitle => 'Upper-body PT session 12 done';

  @override
  String get coachCardExerciseBody =>
      'Nice work finishing upper-body PT session 12! As your coach advised, wrap up with rotator-cuff shoulder stretches and light cardio.';

  @override
  String get coachCardWaterTag => 'Hydration';

  @override
  String get coachInviteTitle => 'A trainer wants to coach you';

  @override
  String coachInviteFrom(String name) {
    return 'Trainer $name';
  }

  @override
  String coachInviteGym(String gym) {
    return 'at $gym';
  }

  @override
  String get coachInviteExplain =>
      'Accepting lets this trainer see your meal and workout records.';

  @override
  String get coachInviteAccept => 'Accept';

  @override
  String get coachInviteReject => 'Decline';

  @override
  String coachInviteAccepted(String name) {
    return '$name is now your coach';
  }

  @override
  String get coachInviteRejected => 'Request declined';

  @override
  String get coachInviteFailed => 'Couldn\'t complete that. Please try again';

  @override
  String get coachImageUnavailable => 'Couldn\'t load the photo';

  @override
  String get coachChatSubtitle => 'Personal trainer · Available';

  @override
  String get coachChatBack => 'Back';

  @override
  String get coachChatLoadFailed => 'Couldn\'t load the conversation';

  @override
  String get coachChatSendFailed =>
      'Couldn\'t send your message. Please try again';

  @override
  String get coachChatPdfOpenFailed =>
      'Couldn\'t open the PDF. Please try again';

  @override
  String get coachChatInputHint => 'Message your trainer...';

  @override
  String get coachChatDemoAnalyzed => 'AI analyzed your diet and exercise data';

  @override
  String coachChatDemoReportSent(String trainer) {
    return 'A summary report was sent to $trainer';
  }

  @override
  String get coachChatDemoRoutineReceived =>
      'You received a routine based on AI analysis';

  @override
  String get coachChatDemoNotified => 'It was also delivered as a notification';

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
  String get aicMedicalDisclaimer =>
      'The AI coach is a reference for diet and exercise habits, not a diagnosis or prescription. Please consult a doctor about symptoms.';

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

  @override
  String get exConsultRequestTitle => 'Consultation Request';

  @override
  String get exGymConsultRequest => 'Request a Consultation';

  @override
  String get exGymConsultPickTrainer => 'Choose a trainer';

  @override
  String get exGymConsultPickTrainerHint => 'Your request goes to one trainer.';

  @override
  String get exGymConsultNoTrainers => 'No trainers are affiliated yet.';

  @override
  String get exTrainerConsultRequest => 'Request a Trainer Consultation';

  @override
  String get exConsultPendingCta => 'Consultation Request Pending';

  @override
  String get exViewConsultationRequest => 'View consultation request';

  @override
  String get exConsultTarget => 'Consultation Target';

  @override
  String get exTrainerConsultType => 'Trainer Consultation';

  @override
  String get exAssignedTrainer => 'Assigned Trainer';

  @override
  String get exConsultDataSharingNotice =>
      'Once this trainer accepts your request, they\'ll be able to see your diet log, exercise log, and body info and health goals.';

  @override
  String get exConsultDataSharingAgree =>
      'I have read this and agree to share my meal and workout records and body information with this trainer';

  @override
  String get exConsultDataSharingRequired =>
      'Please agree to sharing before requesting a consultation';

  @override
  String get coachInviteConsentTitle => 'Before you connect';

  @override
  String coachInviteConsentBody(String name) {
    return 'Once $name becomes your trainer, they can see your meal records, workout records, body information and health goals. Disconnecting also revokes that access.';
  }

  @override
  String get coachInviteConsentAgree => 'Agree and connect';

  @override
  String get exExerciseGoal => 'Exercise Goal';

  @override
  String get exGoalWeightLoss => 'Weight Loss';

  @override
  String get exGoalStrength => 'Build Strength';

  @override
  String get exGoalFitness => 'Improve Fitness';

  @override
  String get exGoalPosture => 'Improve Posture';

  @override
  String get exGoalHealth => 'Health Management';

  @override
  String get exOptionOther => 'Other';

  @override
  String get exHealthPurpose => 'Health Management Purpose';

  @override
  String get exPurposeWeight => 'Weight Management';

  @override
  String get exPurposeChronic => 'Chronic Condition Management';

  @override
  String get exPurposeRehab => 'Pain or Rehabilitation';

  @override
  String get exPurposeGeneral => 'General Health Management';

  @override
  String get exPurposeNone => 'None';

  @override
  String get exHealthPurposeOtherHint =>
      'For example, back rehabilitation, knee pain, or cholesterol management';

  @override
  String get exOtherGoalHint =>
      'Please describe your specific exercise goal in the message.';

  @override
  String get exPreferredDate => 'Preferred Date';

  @override
  String get exSelectDate => 'Select a date';

  @override
  String get exPreferredTime => 'Preferred Time';

  @override
  String get exTimeMorning => 'Morning';

  @override
  String get exTimeAfternoon => 'Afternoon';

  @override
  String get exTimeEvening => 'Evening';

  @override
  String get exTimeFlexible => 'Discuss Later';

  @override
  String get exConsultMessage => 'Message';

  @override
  String get exConsultMessageHint =>
      'Share your exercise experience or anything helpful for the consultation.';

  @override
  String get exSendConsultRequest => 'Send Consultation Request';

  @override
  String get exGoalRequired => 'Please select an exercise goal.';

  @override
  String get exHealthPurposeRequired =>
      'Please select a health management purpose.';

  @override
  String get exHealthPurposeInputRequired =>
      'Please enter a health management purpose.';

  @override
  String get exDateRequired => 'Please select a preferred date.';

  @override
  String get exTimeRequired => 'Please select a preferred time.';

  @override
  String get exConsultTargetNotFound =>
      'Couldn\'t find the consultation target.';

  @override
  String get exConsultPendingExists =>
      'A consultation request is already pending.';

  @override
  String get exConsultReceived => 'Your consultation request was received';

  @override
  String get exConsultCompletionInfo =>
      'We\'ll let you know when the other party reviews your request.';

  @override
  String get exConsultStatus => 'Current Status';

  @override
  String get exConsultPendingStatus => 'Pending';

  @override
  String get exConsultAcceptedStatus => 'Accepted';

  @override
  String get exConsultRejectedStatus => 'Rejected';

  @override
  String get exReturnExercise => 'Return to Exercise';

  @override
  String get exConsultStatusSection => 'Consultation Request Status';

  @override
  String get exConsultRejectedReasonLabel => 'Reason for decline';

  @override
  String get exConsultRejectedNoReason =>
      'No reason was given. Try requesting a consultation with another trainer.';

  @override
  String get exConsultAcceptedGuide =>
      'You\'re connected with your trainer. You can start chatting now.';

  @override
  String get exMyReservations => 'My bookings';

  @override
  String get exCancelReservation => 'Cancel booking';

  @override
  String get exCancelKeep => 'Keep';

  @override
  String get exCancelConfirmTitle => 'Cancel this booking?';

  @override
  String get exCancelFailed =>
      'Couldn\'t cancel the booking. Please try again in a moment';

  @override
  String get exReservationPast => 'Past booking';

  @override
  String exCancelConfirmBody(String when) {
    return 'The $when booking is cancelled and the slot reopens.';
  }

  @override
  String exCancelDone(String when) {
    return 'Cancelled the $when booking';
  }

  @override
  String get mySupportOpenFailed =>
      'Couldn\'t open the link. Please try again in a moment';

  @override
  String get mySupportExternalHint => 'Opens the KakaoTalk channel';

  @override
  String get authTagline => 'AI healthcare for hypertension and diabetes';

  @override
  String get authEmailHint => 'Email';

  @override
  String get authPasswordHint => 'Password';

  @override
  String get authSignInAction => 'Sign in';

  @override
  String get authNoAccountQuestion => 'Don\'t have an account?';

  @override
  String get authSignUpAction => 'Sign up';

  @override
  String get authDemoAction => 'Explore the demo without signing in';

  @override
  String get authOrDivider => 'or';

  @override
  String get authKakaoAction => 'Continue with Kakao';

  @override
  String get authGoogleAction => 'Continue with Google';

  @override
  String get authMissingCredentials => 'Enter your email and password';

  @override
  String get authSignInFailed =>
      'Sign-in failed. Check your email and password';

  @override
  String get authSocialSignInFailed =>
      'Social sign-in failed. Please try again in a moment';

  @override
  String get signUpTitle => 'Sign up';

  @override
  String get signUpSubtitle =>
      'Create an On-Care account and start managing your health';

  @override
  String get signUpNameHint => 'Name';

  @override
  String get signUpPasswordHint => 'Password (8+ characters)';

  @override
  String get signUpPasswordConfirmHint => 'Confirm password';

  @override
  String get signUpAction => 'Sign up and start';

  @override
  String get signUpHaveAccountQuestion => 'Already have an account?';

  @override
  String get signUpPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get signUpPasswordMismatch => 'Passwords do not match';

  @override
  String get signUpEmailTaken =>
      'That email is already registered. Please sign in.';

  @override
  String get signUpFailed => 'Sign-up failed. Please try again in a moment.';

  @override
  String get onboardSkip => 'Do this later';

  @override
  String get onboardPrevious => 'Back';

  @override
  String get onboardNext => 'Next';

  @override
  String get onboardDone => 'Done';

  @override
  String get onboardSaveFailed =>
      'Could not save. Please try again in a moment';

  @override
  String get onboardBasicTitle => 'Basic information';

  @override
  String get onboardBasicSubtitle =>
      'Tell us a little about yourself so we can tailor your care.';

  @override
  String get onboardBirthHint => 'Date of birth (YYYY-MM-DD)';

  @override
  String get onboardHeightHint => 'Height (cm)';

  @override
  String get onboardWeightHint => 'Weight (kg)';

  @override
  String get onboardHealthTitle => 'Health conditions';

  @override
  String get onboardHealthSubtitle =>
      'Select the chronic conditions you manage. (Choose any that apply)';

  @override
  String get onboardGoalTitle => 'Health goals';

  @override
  String get onboardGoalSubtitle =>
      'Tell us what you want to achieve. You can change this later.';

  @override
  String get onboardGoalHint => 'Health and exercise goals';

  @override
  String get onboardSodiumGoalHint => 'Daily sodium goal (mg)';

  @override
  String get onboardGenderMale => 'Male';

  @override
  String get onboardGenderFemale => 'Female';

  @override
  String get onboardGenderOther => 'Other';

  @override
  String get onboardConditionHypertension => 'Hypertension';

  @override
  String get onboardConditionDiabetes => 'Diabetes';

  @override
  String get onboardConditionDyslipidemia => 'Dyslipidemia';

  @override
  String get onboardConditionObesity => 'Obesity';

  @override
  String get aiCoachWelcome =>
      'Hi, I\'m Oni, your AI health coach 🙂\nAsk me anything about diet, exercise, blood pressure, or blood sugar.';

  @override
  String get aiCoachFailure =>
      'Something went wrong. Please try again in a moment.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionConfirm => 'OK';

  @override
  String get scheduleCategoryHospital => 'Hospital';

  @override
  String get scheduleCategoryExercise => 'Exercise';

  @override
  String get scheduleCategoryMeal => 'Meal';

  @override
  String get scheduleCategoryMedication => 'Medication';

  @override
  String get scheduleCategoryOther => 'Other';

  @override
  String get eventAddTitle => 'Add event';

  @override
  String get eventEditTitle => 'Edit event';

  @override
  String get eventTitleLabel => 'Event title';

  @override
  String get eventTitleHint => 'e.g. Regular checkup';

  @override
  String get eventDateLabel => 'Date';

  @override
  String get eventTimeLabel => 'Time';

  @override
  String get eventTimeNone => 'No time';

  @override
  String get eventTitleRequired => 'Please enter an event title';

  @override
  String get eventAddFailed =>
      'Couldn\'t add the event. Please try again in a moment';

  @override
  String get eventEditFailed =>
      'Couldn\'t save the event. Please try again in a moment';

  @override
  String get eventSaving => 'Saving…';

  @override
  String get eventAdding => 'Adding…';

  @override
  String get eventSave => 'Save';

  @override
  String get eventAdd => 'Add';

  @override
  String eventClearField(String label) {
    return 'Clear $label';
  }

  @override
  String get eventDeleteTitle => 'Delete event';

  @override
  String eventDeleteConfirm(String title) {
    return 'Delete “$title”? This can\'t be undone.';
  }

  @override
  String get eventDeleteFailed =>
      'Couldn\'t delete the event. Please try again in a moment';

  @override
  String get eventDeleted => 'Event deleted';

  @override
  String get eventsEmptyForDay => 'No events on this day';

  @override
  String get eventAddForDay => 'Add an event on this day';

  @override
  String get eventTimeUnset => 'Time TBD';

  @override
  String get scheduleSheetTitle => 'Schedule';

  @override
  String get eventsLoadFailed => 'Couldn\'t load events';

  @override
  String get coachCardSleepTag => 'Sleep';

  @override
  String get myHealthGoalsTitle => 'Health goals';

  @override
  String get myGoalsDietSection => 'Daily diet goals';

  @override
  String get myGoalsExerciseSection => 'Weekly exercise goals';

  @override
  String get myGoalCalories => 'Daily calorie limit (kcal)';

  @override
  String get myGoalSodium => 'Daily sodium limit (mg)';

  @override
  String get myGoalSugar => 'Daily sugar limit (g)';

  @override
  String get myGoalCarbs => 'Daily carbohydrate limit (g)';

  @override
  String get myGoalProtein => 'Daily protein limit (g)';

  @override
  String get myGoalFat => 'Daily fat limit (g)';

  @override
  String get myGoalCaloriesFromMacros =>
      'Calculated from your carb, protein and fat goals';

  @override
  String myGoalMacroSuggestionNote(int kcal) {
    return 'Suggested split for $kcal kcal: 50% carbs · 30% protein · 20% fat';
  }

  @override
  String get myGoalMacroApplySuggestion => 'Use suggested split';

  @override
  String get myGoalWorkoutCount => 'Weekly workout count goal';

  @override
  String get myGoalWorkoutMinutes => 'Weekly workout minutes goal';

  @override
  String get myGoalWorkoutCalories => 'Weekly calories burned goal (kcal)';

  @override
  String get myGoalsSaved => 'Health goals saved';

  @override
  String get mySettingsLoadFailed => 'Couldn\'t load your settings';

  @override
  String get mySettingsLoadFailedBody =>
      'Editing is locked because saving now could wipe your existing settings.';

  @override
  String get myNotificationSaveFailed => 'Couldn\'t save notification settings';

  @override
  String get myPointsGuideTitle => 'How to earn points';

  @override
  String get myPointsDietAdd => 'Log a meal';

  @override
  String get myPointsAiExercise => 'Complete an AI-recommended workout';

  @override
  String get myPointsExerciseAdd => 'Log a workout yourself';

  @override
  String get coachAssignedTrainer => 'My trainer';

  @override
  String get coachAiCoaching => 'AI coaching';

  @override
  String get coachPointsTitle => 'This week\'s coaching points';

  @override
  String get coachRoutineTitle => 'Recommended solo workouts';

  @override
  String get coachRoutineSubtitle =>
      'Workouts to do on your own between PT sessions';

  @override
  String get coachRoutineByTrainer => 'Recommended by your trainer';

  @override
  String coachRoutineAiChecked(String name) {
    return 'AI suggestion · reviewed by $name';
  }

  @override
  String get coachRoutineAiAuto => 'AI suggestion';

  @override
  String get coachRoutineLogged => 'Added to your workout log';

  @override
  String get coachRoutineGone =>
      'This routine no longer exists. Please refresh the list';

  @override
  String get coachRoutineNetworkError => 'Check your connection and try again';

  @override
  String get coachRoutineLogFailed => 'Couldn\'t record it as done.';

  @override
  String get coachRoutineDone => 'Done';

  @override
  String get coachRoutineCancel => 'Cancel this workout';

  @override
  String coachRoutineCancelConfirm(String name) {
    return 'Remove \'$name\' from the list? Anything you already logged stays.';
  }

  @override
  String get coachRoutineCancelled => 'Workout cancelled';

  @override
  String get coachRoutineCancelFailed => 'Couldn\'t cancel the workout';

  @override
  String coachRoutineMyNote(String note) {
    return 'My note: $note';
  }

  @override
  String coachRoutineTrainerFeedback(String feedback) {
    return 'Trainer feedback: $feedback';
  }

  @override
  String get coachRoutineCompleteTitle => 'Mark routine done';

  @override
  String get coachRoutineMinutesLabel => 'Actual minutes';

  @override
  String get coachRoutineMinutesError =>
      'Enter a value between 1 and 600 minutes';

  @override
  String get coachRoutineIntensity => 'Intensity';

  @override
  String get coachIntensityLight => 'Light';

  @override
  String get coachIntensityModerate => 'Moderate';

  @override
  String get coachIntensityHigh => 'High';

  @override
  String get coachRoutineNoteLabel => 'Note (optional)';

  @override
  String get coachRoutineNoteHint =>
      'Share how it felt or how your body is doing';

  @override
  String get coachRoutineSubmit => 'Save';

  @override
  String get coachChatWithTrainer => 'Chat with trainer';

  @override
  String get coachTrainerLoading => 'Loading your trainer…';

  @override
  String get coachTrainerNone =>
      'You don\'t have a trainer yet. Connect a gym and trainer from the Exercise tab';

  @override
  String get alertCategoryReminder => 'Reminder';

  @override
  String get alertCategoryHealth => 'Health';

  @override
  String get alertCategoryAchievement => 'Achievement';

  @override
  String get alertCategorySystem => 'System';

  @override
  String get alertMarkAllRead => 'Mark all read';

  @override
  String get alertEmpty => 'No notifications';

  @override
  String get alertLoadFailed => 'Couldn\'t load the latest notifications';

  @override
  String get alertSimulatedTitle => 'Simulated notification';

  @override
  String get alertSimulatedBody => 'A test push just arrived.';

  @override
  String get alertJustNow => 'Just now';

  @override
  String get exPtLogTitle => 'Today\'s completed PT';

  @override
  String get exPtFeedbackTitle => 'Today\'s feedback';

  @override
  String exNextPtSchedule(String when) {
    return 'Next PT · $when';
  }

  @override
  String get exNextPtNone => 'No PT scheduled yet';

  @override
  String exDatedTitle(int month, int day, String title) {
    return '$title · $month/$day';
  }

  @override
  String a11yChartSummary(String title, String detail) {
    return '$title. $detail';
  }

  @override
  String a11yChartEmpty(String title) {
    return '$title. No records yet';
  }

  @override
  String a11yChartPoint(String day, String value) {
    return '$day $value';
  }

  @override
  String get a11yShowPassword => 'Show password';

  @override
  String get a11yHidePassword => 'Hide password';

  @override
  String get a11yOpenCoaching => 'Open coaching tips';

  @override
  String get a11ySendMessage => 'Send message';

  @override
  String get a11yClearSearch => 'Clear search';

  @override
  String get a11yRemoveFood => 'Remove food';

  @override
  String get a11yOpenCalendar => 'Open schedule calendar';

  @override
  String get a11yPrevWeek => 'Previous week';

  @override
  String get a11yNextWeek => 'Next week';
}
