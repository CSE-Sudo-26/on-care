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

  /// Application name shown in window/AppBar titles.
  ///
  /// In en, this message translates to:
  /// **'On-Care'**
  String get appTitle;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navDashboard;

  /// No description provided for @navDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get navDiet;

  /// No description provided for @navExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get navExercise;

  /// No description provided for @navMyHealth.
  ///
  /// In en, this message translates to:
  /// **'MY'**
  String get navMyHealth;

  /// No description provided for @pageDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get pageDashboardTitle;

  /// No description provided for @pageDietTitle.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get pageDietTitle;

  /// No description provided for @pageExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get pageExerciseTitle;

  /// No description provided for @pageMyHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'My'**
  String get pageMyHealthTitle;

  /// No description provided for @pageAiCoachTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Coach'**
  String get pageAiCoachTitle;

  /// No description provided for @pageNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get pageNotificationTitle;

  /// No description provided for @pagePlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get pagePlaceTitle;

  /// No description provided for @pageSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get pageSignInTitle;

  /// No description provided for @actionOpenAiCoach.
  ///
  /// In en, this message translates to:
  /// **'Open AI Coach'**
  String get actionOpenAiCoach;

  /// No description provided for @actionFindPlace.
  ///
  /// In en, this message translates to:
  /// **'Find a place'**
  String get actionFindPlace;

  /// No description provided for @actionSignInPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Sign in (placeholder)'**
  String get actionSignInPlaceholder;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @placeholderDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard (placeholder)'**
  String get placeholderDashboard;

  /// No description provided for @placeholderDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet Record (placeholder)'**
  String get placeholderDiet;

  /// No description provided for @placeholderExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise (placeholder)'**
  String get placeholderExercise;

  /// No description provided for @placeholderMyHealth.
  ///
  /// In en, this message translates to:
  /// **'My Health (placeholder)'**
  String get placeholderMyHealth;

  /// No description provided for @placeholderAiCoach.
  ///
  /// In en, this message translates to:
  /// **'AI Coach (placeholder, mock responses)'**
  String get placeholderAiCoach;

  /// No description provided for @placeholderNotification.
  ///
  /// In en, this message translates to:
  /// **'Notifications (placeholder)'**
  String get placeholderNotification;

  /// No description provided for @placeholderPlace.
  ///
  /// In en, this message translates to:
  /// **'Place (placeholder, Google Maps in Stage 4)'**
  String get placeholderPlace;

  /// No description provided for @placeholderSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in (placeholder, social SDKs in Stage 4)'**
  String get placeholderSignIn;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network problem'**
  String get errorNetwork;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get errorUnauthorized;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFound;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get errorServer;

  /// No description provided for @errorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get errorCancelled;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnknown;

  /// No description provided for @dashboardSectionToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardSectionToday;

  /// No description provided for @dashboardMetricCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get dashboardMetricCalories;

  /// No description provided for @dashboardMetricExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get dashboardMetricExercise;

  /// No description provided for @dashboardMetricWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get dashboardMetricWeight;

  /// No description provided for @dashboardChartWeightWeek.
  ///
  /// In en, this message translates to:
  /// **'Weekly weight'**
  String get dashboardChartWeightWeek;

  /// No description provided for @dashboardCaloriesProgress.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of {goal}'**
  String dashboardCaloriesProgress(int pct, int goal);

  /// No description provided for @dashboardWeightDelta.
  ///
  /// In en, this message translates to:
  /// **'{sign}{delta} vs last week'**
  String dashboardWeightDelta(String sign, String delta);

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'{name}, let\'s ease into the day 👋'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingGeneric.
  ///
  /// In en, this message translates to:
  /// **'Let\'s ease into the day 👋'**
  String get homeGreetingGeneric;

  /// No description provided for @homeCoachingPill.
  ///
  /// In en, this message translates to:
  /// **'✦ AI Coaching'**
  String get homeCoachingPill;

  /// No description provided for @homeCoachingTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s tailored advice'**
  String get homeCoachingTitle;

  /// No description provided for @homeCoachingBody.
  ///
  /// In en, this message translates to:
  /// **'Cut back on sodium at dinner and\ntake about a 20-minute walk'**
  String get homeCoachingBody;

  /// No description provided for @homeCoachingReady.
  ///
  /// In en, this message translates to:
  /// **'AI prepared 3 tailored tips for you today'**
  String get homeCoachingReady;

  /// No description provided for @homeDietSodiumAlert.
  ///
  /// In en, this message translates to:
  /// **'Sodium over limit detected'**
  String get homeDietSodiumAlert;

  /// No description provided for @homeMacroCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get homeMacroCarbs;

  /// No description provided for @homeMacroProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get homeMacroProtein;

  /// No description provided for @homeMacroFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get homeMacroFat;

  /// No description provided for @homeDietRecBadge.
  ///
  /// In en, this message translates to:
  /// **'✦ AI dinner recommendation'**
  String get homeDietRecBadge;

  /// No description provided for @homeMealChickenSalad.
  ///
  /// In en, this message translates to:
  /// **'Chicken breast salad'**
  String get homeMealChickenSalad;

  /// No description provided for @homeDietRecRice.
  ///
  /// In en, this message translates to:
  /// **'Half bowl of brown rice'**
  String get homeDietRecRice;

  /// No description provided for @homeDietLogButton.
  ///
  /// In en, this message translates to:
  /// **'Log diet →'**
  String get homeDietLogButton;

  /// No description provided for @homeExerciseRoutineProgress.
  ///
  /// In en, this message translates to:
  /// **'AI routine 1/3 done'**
  String get homeExerciseRoutineProgress;

  /// No description provided for @homeExerciseBurnGoal.
  ///
  /// In en, this message translates to:
  /// **'{unit} burned · Goal {goal}'**
  String homeExerciseBurnGoal(String unit, int goal);

  /// No description provided for @homeExerciseBrisk.
  ///
  /// In en, this message translates to:
  /// **'Brisk walking'**
  String get homeExerciseBrisk;

  /// No description provided for @homeExerciseLegStretch.
  ///
  /// In en, this message translates to:
  /// **'Lower-body stretch'**
  String get homeExerciseLegStretch;

  /// No description provided for @homeExerciseRecBadge.
  ///
  /// In en, this message translates to:
  /// **'✦ AI remaining routine'**
  String get homeExerciseRecBadge;

  /// No description provided for @homeExerciseRecStretch.
  ///
  /// In en, this message translates to:
  /// **'Lower-body stretch 10 min'**
  String get homeExerciseRecStretch;

  /// No description provided for @homeExerciseRecStrength.
  ///
  /// In en, this message translates to:
  /// **'Low-intensity strength 15 min'**
  String get homeExerciseRecStrength;

  /// No description provided for @homeExerciseLogButton.
  ///
  /// In en, this message translates to:
  /// **'Log exercise →'**
  String get homeExerciseLogButton;

  /// No description provided for @homeSummaryToday.
  ///
  /// In en, this message translates to:
  /// **'Today total'**
  String get homeSummaryToday;

  /// No description provided for @homeVsGoal.
  ///
  /// In en, this message translates to:
  /// **'vs goal'**
  String get homeVsGoal;

  /// No description provided for @homeNutritionTitle.
  ///
  /// In en, this message translates to:
  /// **'Nutrition status'**
  String get homeNutritionTitle;

  /// No description provided for @homeAiAnalysisPill.
  ///
  /// In en, this message translates to:
  /// **'✦ AI analysis'**
  String get homeAiAnalysisPill;

  /// No description provided for @homeNutritionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly trend · vs last week'**
  String get homeNutritionSubtitle;

  /// No description provided for @homeDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get homeDetails;

  /// No description provided for @homeThisWeekAvg.
  ///
  /// In en, this message translates to:
  /// **'This week avg'**
  String get homeThisWeekAvg;

  /// No description provided for @homeLastWeekAvg.
  ///
  /// In en, this message translates to:
  /// **'Last week avg'**
  String get homeLastWeekAvg;

  /// No description provided for @homeGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get homeGoal;

  /// No description provided for @homeVsLastWeek.
  ///
  /// In en, this message translates to:
  /// **'vs last week'**
  String get homeVsLastWeek;

  /// No description provided for @homeSodiumInsightPre.
  ///
  /// In en, this message translates to:
  /// **'Sodium intake has been '**
  String get homeSodiumInsightPre;

  /// No description provided for @homeSodiumInsightTrend.
  ///
  /// In en, this message translates to:
  /// **'rising for 2 weeks'**
  String get homeSodiumInsightTrend;

  /// No description provided for @homeSodiumInsightMid.
  ///
  /// In en, this message translates to:
  /// **'. Cut back on salt and turn on '**
  String get homeSodiumInsightMid;

  /// No description provided for @homeSodiumInsightAlert.
  ///
  /// In en, this message translates to:
  /// **'high-sodium meal alerts'**
  String get homeSodiumInsightAlert;

  /// No description provided for @homeSodiumInsightPost.
  ///
  /// In en, this message translates to:
  /// **'?'**
  String get homeSodiumInsightPost;

  /// No description provided for @homeAiPill.
  ///
  /// In en, this message translates to:
  /// **'✦ AI'**
  String get homeAiPill;

  /// No description provided for @homeLegendThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get homeLegendThisWeek;

  /// No description provided for @homeLegendLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get homeLegendLastWeek;

  /// No description provided for @homeLegendToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeLegendToday;

  /// No description provided for @homeMealReasonSodium.
  ///
  /// In en, this message translates to:
  /// **'Great for sodium control'**
  String get homeMealReasonSodium;

  /// No description provided for @homeMealTagLowSodium.
  ///
  /// In en, this message translates to:
  /// **'Low sodium'**
  String get homeMealTagLowSodium;

  /// No description provided for @homeMealBrownRiceBox.
  ///
  /// In en, this message translates to:
  /// **'Brown rice lunchbox'**
  String get homeMealBrownRiceBox;

  /// No description provided for @homeMealReasonGlucose.
  ///
  /// In en, this message translates to:
  /// **'Helps steady blood sugar'**
  String get homeMealReasonGlucose;

  /// No description provided for @homeMealTagLowGi.
  ///
  /// In en, this message translates to:
  /// **'Low GI'**
  String get homeMealTagLowGi;

  /// No description provided for @homeMealSalmon.
  ///
  /// In en, this message translates to:
  /// **'Grilled salmon + greens'**
  String get homeMealSalmon;

  /// No description provided for @homeMealReasonOmega.
  ///
  /// In en, this message translates to:
  /// **'Omega-3 + fiber'**
  String get homeMealReasonOmega;

  /// No description provided for @homeMealTagHighProtein.
  ///
  /// In en, this message translates to:
  /// **'High protein'**
  String get homeMealTagHighProtein;

  /// No description provided for @homeMealTofu.
  ///
  /// In en, this message translates to:
  /// **'Stir-fried tofu & veggies'**
  String get homeMealTofu;

  /// No description provided for @homeMealReasonLowCal.
  ///
  /// In en, this message translates to:
  /// **'Low calorie, keeps you full'**
  String get homeMealReasonLowCal;

  /// No description provided for @homeMealTagLowCal.
  ///
  /// In en, this message translates to:
  /// **'Low calorie'**
  String get homeMealTagLowCal;

  /// No description provided for @homeRecMealsTitle.
  ///
  /// In en, this message translates to:
  /// **'This week\'s AI meal picks'**
  String get homeRecMealsTitle;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// No description provided for @homeScheduleDate.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {month}/{day}'**
  String homeScheduleDate(String weekday, int month, int day);

  /// No description provided for @homeScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule'**
  String get homeScheduleTitle;

  /// No description provided for @homeScheduleEveningWalk.
  ///
  /// In en, this message translates to:
  /// **'Evening walk'**
  String get homeScheduleEveningWalk;

  /// No description provided for @homeScheduleWalkDetail.
  ///
  /// In en, this message translates to:
  /// **'Around home · 20 min'**
  String get homeScheduleWalkDetail;

  /// No description provided for @unitKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get unitKcal;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get unitMinutes;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @dietTitle.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get dietTitle;

  /// No description provided for @dietToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dietToday;

  /// No description provided for @dietWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Month {month}, Week {week}'**
  String dietWeekLabel(int month, int week);

  /// No description provided for @dietWeekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dietWeekdayMon;

  /// No description provided for @dietWeekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dietWeekdayTue;

  /// No description provided for @dietWeekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dietWeekdayWed;

  /// No description provided for @dietWeekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dietWeekdayThu;

  /// No description provided for @dietWeekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dietWeekdayFri;

  /// No description provided for @dietWeekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get dietWeekdaySat;

  /// No description provided for @dietWeekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get dietWeekdaySun;

  /// No description provided for @dietNutritionSummary.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Nutrition'**
  String get dietNutritionSummary;

  /// No description provided for @dietCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get dietCalories;

  /// No description provided for @dietSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium'**
  String get dietSodium;

  /// No description provided for @dietSugar.
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get dietSugar;

  /// No description provided for @dietUnitMg.
  ///
  /// In en, this message translates to:
  /// **'mg'**
  String get dietUnitMg;

  /// No description provided for @dietUnitG.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get dietUnitG;

  /// No description provided for @dietAiFeedback.
  ///
  /// In en, this message translates to:
  /// **'AI Feedback'**
  String get dietAiFeedback;

  /// No description provided for @dietTodayMeals.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Meals'**
  String get dietTodayMeals;

  /// No description provided for @dietAddMeal.
  ///
  /// In en, this message translates to:
  /// **'Add Meal'**
  String get dietAddMeal;

  /// No description provided for @dietEmptyLog.
  ///
  /// In en, this message translates to:
  /// **'No meals logged yet.\nAdd your first meal with a photo!'**
  String get dietEmptyLog;

  /// No description provided for @dietPhotoAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Photo Analysis'**
  String get dietPhotoAnalysis;

  /// No description provided for @dietLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your diet.'**
  String get dietLoadError;

  /// No description provided for @dietOtherDateEmpty.
  ///
  /// In en, this message translates to:
  /// **'Records for the selected date aren\'t available yet.\nPlease check your diet on today\'s date.'**
  String get dietOtherDateEmpty;

  /// No description provided for @dietTagSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium {mg}mg'**
  String dietTagSodium(int mg);

  /// No description provided for @dietTagSugar.
  ///
  /// In en, this message translates to:
  /// **'Sugar {g}g'**
  String dietTagSugar(int g);

  /// No description provided for @dietMealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get dietMealBreakfast;

  /// No description provided for @dietMealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get dietMealLunch;

  /// No description provided for @dietMealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dietMealDinner;

  /// No description provided for @dietMealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get dietMealSnack;

  /// No description provided for @dietMealSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'{meal}'**
  String dietMealSheetTitle(String meal);

  /// No description provided for @dietAddSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a Meal'**
  String get dietAddSheetTitle;

  /// No description provided for @dietAddSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Analyze your food from a photo'**
  String get dietAddSheetSubtitle;

  /// No description provided for @dietPickPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a Photo'**
  String get dietPickPhoto;

  /// No description provided for @dietPickPhotoSub.
  ///
  /// In en, this message translates to:
  /// **'Pick a food photo from your gallery'**
  String get dietPickPhotoSub;

  /// No description provided for @dietTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get dietTakePhoto;

  /// No description provided for @dietTakePhotoSub.
  ///
  /// In en, this message translates to:
  /// **'Snap your food with the camera'**
  String get dietTakePhotoSub;

  /// No description provided for @dietPhotoLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the photo. Please try again in a moment.'**
  String get dietPhotoLoadError;

  /// No description provided for @dietAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get dietAnalyzing;

  /// No description provided for @dietAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed'**
  String get dietAnalysisFailed;

  /// No description provided for @dietAnalysisDone.
  ///
  /// In en, this message translates to:
  /// **'Analysis complete!'**
  String get dietAnalysisDone;

  /// No description provided for @dietAiNutritionResult.
  ///
  /// In en, this message translates to:
  /// **'AI Nutrition Result'**
  String get dietAiNutritionResult;

  /// No description provided for @dietAnalyzingBody.
  ///
  /// In en, this message translates to:
  /// **'Analyzing the food in your photo'**
  String get dietAnalyzingBody;

  /// No description provided for @dietAnalysisFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed. Please try again in a moment.'**
  String get dietAnalysisFailedBody;

  /// No description provided for @dietRecognizedFood.
  ///
  /// In en, this message translates to:
  /// **'Recognized Food'**
  String get dietRecognizedFood;

  /// No description provided for @dietNoRecognizedFood.
  ///
  /// In en, this message translates to:
  /// **'No food recognized'**
  String get dietNoRecognizedFood;

  /// No description provided for @dietNutritionResult.
  ///
  /// In en, this message translates to:
  /// **'Nutrition Result'**
  String get dietNutritionResult;

  /// No description provided for @dietSaved.
  ///
  /// In en, this message translates to:
  /// **'Meal saved'**
  String get dietSaved;

  /// No description provided for @dietDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get dietDone;

  /// No description provided for @dietSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please try again in a moment.'**
  String get dietSaveFailed;

  /// No description provided for @dietDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Meal Record'**
  String get dietDeleteTitle;

  /// No description provided for @dietDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this meal record?'**
  String get dietDeleteConfirm;

  /// No description provided for @dietCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dietCancel;

  /// No description provided for @dietDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dietDelete;

  /// No description provided for @dietDeleted.
  ///
  /// In en, this message translates to:
  /// **'Meal deleted'**
  String get dietDeleted;

  /// No description provided for @dietDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Please try again in a moment.'**
  String get dietDeleteFailed;

  /// No description provided for @dietSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dietSave;

  /// No description provided for @dietMealInfo.
  ///
  /// In en, this message translates to:
  /// **'Meal Info'**
  String get dietMealInfo;

  /// No description provided for @dietEatenTime.
  ///
  /// In en, this message translates to:
  /// **'Time Eaten'**
  String get dietEatenTime;

  /// No description provided for @dietEatenFood.
  ///
  /// In en, this message translates to:
  /// **'Food Eaten'**
  String get dietEatenFood;

  /// No description provided for @dietNewFood.
  ///
  /// In en, this message translates to:
  /// **'New food'**
  String get dietNewFood;

  /// No description provided for @dietAddFood.
  ///
  /// In en, this message translates to:
  /// **'+ Add Food'**
  String get dietAddFood;

  /// No description provided for @dietEditFoodHint.
  ///
  /// In en, this message translates to:
  /// **'You can edit the food name and calories'**
  String get dietEditFoodHint;

  /// No description provided for @dietTotalCalories.
  ///
  /// In en, this message translates to:
  /// **'Total Calories'**
  String get dietTotalCalories;

  /// No description provided for @dietNutritionInfo.
  ///
  /// In en, this message translates to:
  /// **'Nutrition Info'**
  String get dietNutritionInfo;

  /// No description provided for @dietEditNutritionHint.
  ///
  /// In en, this message translates to:
  /// **'You can edit the analyzed values directly'**
  String get dietEditNutritionHint;

  /// No description provided for @dietSodiumHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended under 2,000mg/day'**
  String get dietSodiumHint;

  /// No description provided for @dietSugarHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended under 50g/day'**
  String get dietSugarHint;

  /// No description provided for @dietDeleteMeal.
  ///
  /// In en, this message translates to:
  /// **'Delete Meal'**
  String get dietDeleteMeal;

  /// No description provided for @exTypeWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get exTypeWalking;

  /// No description provided for @exTypeCardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get exTypeCardio;

  /// No description provided for @exTypeStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get exTypeStrength;

  /// No description provided for @exTypeYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get exTypeYoga;

  /// No description provided for @exTypeStretching.
  ///
  /// In en, this message translates to:
  /// **'Stretching'**
  String get exTypeStretching;

  /// No description provided for @exTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exTypeOther;

  /// No description provided for @exTypeOtherChip.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get exTypeOtherChip;

  /// No description provided for @exLevelLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get exLevelLight;

  /// No description provided for @exLevelModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get exLevelModerate;

  /// No description provided for @exLevelHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get exLevelHigh;

  /// No description provided for @exExerciseLog.
  ///
  /// In en, this message translates to:
  /// **'Exercise Log'**
  String get exExerciseLog;

  /// No description provided for @exGymTab.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get exGymTab;

  /// No description provided for @exWeekSummary.
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Summary'**
  String get exWeekSummary;

  /// No description provided for @exActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get exActivityTitle;

  /// No description provided for @exThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get exThisWeek;

  /// No description provided for @exAiRoutineToday.
  ///
  /// In en, this message translates to:
  /// **'AI Routine · Today'**
  String get exAiRoutineToday;

  /// No description provided for @exStatTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get exStatTime;

  /// No description provided for @exStatCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get exStatCalories;

  /// No description provided for @exStatStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get exStatStreak;

  /// No description provided for @exUnitCount.
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get exUnitCount;

  /// No description provided for @exUnitStreakDays.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get exUnitStreakDays;

  /// No description provided for @exToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get exToday;

  /// No description provided for @exLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your exercise data.'**
  String get exLoadError;

  /// No description provided for @exEmptyLog.
  ///
  /// In en, this message translates to:
  /// **'No workouts logged this week.\nAdd one to start your log!'**
  String get exEmptyLog;

  /// No description provided for @exAiFeedback.
  ///
  /// In en, this message translates to:
  /// **'AI Feedback'**
  String get exAiFeedback;

  /// No description provided for @exAddExercise.
  ///
  /// In en, this message translates to:
  /// **'Add Exercise'**
  String get exAddExercise;

  /// No description provided for @exRoutineBriskTitle.
  ///
  /// In en, this message translates to:
  /// **'Brisk walking 30 min'**
  String get exRoutineBriskTitle;

  /// No description provided for @exRoutineBriskSub.
  ///
  /// In en, this message translates to:
  /// **'Cardio · Blood pressure'**
  String get exRoutineBriskSub;

  /// No description provided for @exRoutineStretchTitle.
  ///
  /// In en, this message translates to:
  /// **'Lower-body stretch'**
  String get exRoutineStretchTitle;

  /// No description provided for @exRoutineStretchSub.
  ///
  /// In en, this message translates to:
  /// **'Stretching · Flexibility'**
  String get exRoutineStretchSub;

  /// No description provided for @exRoutineStrengthTitle.
  ///
  /// In en, this message translates to:
  /// **'Low-intensity strength'**
  String get exRoutineStrengthTitle;

  /// No description provided for @exRoutineStrengthSub.
  ///
  /// In en, this message translates to:
  /// **'Strength · Endurance'**
  String get exRoutineStrengthSub;

  /// No description provided for @exMissionComplete.
  ///
  /// In en, this message translates to:
  /// **'Mission complete!'**
  String get exMissionComplete;

  /// No description provided for @exMinutesExercise.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min exercise'**
  String exMinutesExercise(int minutes);

  /// No description provided for @exDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String exDurationMinutes(int minutes);

  /// No description provided for @exEditExercise.
  ///
  /// In en, this message translates to:
  /// **'Edit Exercise Record'**
  String get exEditExercise;

  /// No description provided for @exSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get exSave;

  /// No description provided for @exExerciseType.
  ///
  /// In en, this message translates to:
  /// **'Exercise Type'**
  String get exExerciseType;

  /// No description provided for @exExerciseDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get exExerciseDuration;

  /// No description provided for @exExerciseIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get exExerciseIntensity;

  /// No description provided for @exEstimatedCalories.
  ///
  /// In en, this message translates to:
  /// **'Estimated Calories'**
  String get exEstimatedCalories;

  /// No description provided for @exEnterDuration.
  ///
  /// In en, this message translates to:
  /// **'Please enter a duration'**
  String get exEnterDuration;

  /// No description provided for @exCannotEdit.
  ///
  /// In en, this message translates to:
  /// **'This record can\'t be edited'**
  String get exCannotEdit;

  /// No description provided for @exUpdated.
  ///
  /// In en, this message translates to:
  /// **'Exercise record updated'**
  String get exUpdated;

  /// No description provided for @exLogged.
  ///
  /// In en, this message translates to:
  /// **'Exercise logged'**
  String get exLogged;

  /// No description provided for @exSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please try again in a moment'**
  String get exSaveFailed;

  /// No description provided for @exFindGym.
  ///
  /// In en, this message translates to:
  /// **'Find a Gym'**
  String get exFindGym;

  /// No description provided for @exGymSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by gym or area'**
  String get exGymSearchHint;

  /// No description provided for @exNearbyGyms.
  ///
  /// In en, this message translates to:
  /// **'Nearby Gyms · O2O'**
  String get exNearbyGyms;

  /// No description provided for @exAiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'✦ AI analysis'**
  String get exAiAnalysis;

  /// No description provided for @exNoGymMatch.
  ///
  /// In en, this message translates to:
  /// **'No gyms match \'{query}\''**
  String exNoGymMatch(String query);

  /// No description provided for @exGymsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load gyms.'**
  String get exGymsLoadError;

  /// No description provided for @exAiTopPick.
  ///
  /// In en, this message translates to:
  /// **'✦ AI top pick'**
  String get exAiTopPick;

  /// No description provided for @exTrainerChat.
  ///
  /// In en, this message translates to:
  /// **'Trainer Chat'**
  String get exTrainerChat;

  /// No description provided for @exSendHealthSummary.
  ///
  /// In en, this message translates to:
  /// **'Share Health Summary'**
  String get exSendHealthSummary;

  /// No description provided for @exSendHealthSummaryBody.
  ///
  /// In en, this message translates to:
  /// **'Share your recent workouts and health profile summary\nwith the {gym} trainer?'**
  String exSendHealthSummaryBody(String gym);

  /// No description provided for @exCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get exCancel;

  /// No description provided for @exSend.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get exSend;

  /// No description provided for @exHealthSummarySent.
  ///
  /// In en, this message translates to:
  /// **'Shared your health summary with {gym}'**
  String exHealthSummarySent(String gym);

  /// No description provided for @exReasonTrainer.
  ///
  /// In en, this message translates to:
  /// **'Personal trainer {name}{role} on site'**
  String exReasonTrainer(String name, String role);

  /// No description provided for @exReasonHours.
  ///
  /// In en, this message translates to:
  /// **'Open {hours}{weekend}'**
  String exReasonHours(String hours, String weekend);

  /// No description provided for @exGymWeekdayHours.
  ///
  /// In en, this message translates to:
  /// **'Weekdays {hours}'**
  String exGymWeekdayHours(String hours);

  /// No description provided for @exGymWeekendHours.
  ///
  /// In en, this message translates to:
  /// **'Weekends {hours}'**
  String exGymWeekendHours(String hours);

  /// No description provided for @exTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get exTrainer;

  /// No description provided for @exMyGym.
  ///
  /// In en, this message translates to:
  /// **'My Gym'**
  String get exMyGym;

  /// No description provided for @exTrainerDedicated.
  ///
  /// In en, this message translates to:
  /// **'Personal trainer'**
  String get exTrainerDedicated;

  /// No description provided for @exAiSlotTitle.
  ///
  /// In en, this message translates to:
  /// **'✦ AI recommended times'**
  String get exAiSlotTitle;

  /// No description provided for @exTrainerAvailability.
  ///
  /// In en, this message translates to:
  /// **'{trainer}\'s openings'**
  String exTrainerAvailability(String trainer);

  /// No description provided for @exSlotToday19.
  ///
  /// In en, this message translates to:
  /// **'Today 19:00'**
  String get exSlotToday19;

  /// No description provided for @exSlotTomorrow0730.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow 07:30'**
  String get exSlotTomorrow0730;

  /// No description provided for @exSlotTomorrow20.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow 20:00'**
  String get exSlotTomorrow20;

  /// No description provided for @exSlot1Left.
  ///
  /// In en, this message translates to:
  /// **'1 spot left'**
  String get exSlot1Left;

  /// No description provided for @exSlotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get exSlotAvailable;

  /// No description provided for @exSlot2Left.
  ///
  /// In en, this message translates to:
  /// **'2 spots left'**
  String get exSlot2Left;

  /// No description provided for @exReserveConfirmedSlotGym.
  ///
  /// In en, this message translates to:
  /// **'{slot} · {gym} reservation confirmed'**
  String exReserveConfirmedSlotGym(String slot, String gym);

  /// No description provided for @exReserveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm {slot}'**
  String exReserveConfirm(String slot);

  /// No description provided for @exGymInfo.
  ///
  /// In en, this message translates to:
  /// **'Gym Info'**
  String get exGymInfo;

  /// No description provided for @exConsultButton.
  ///
  /// In en, this message translates to:
  /// **'💬 1:1 Consult'**
  String get exConsultButton;

  /// No description provided for @exGymLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the gym.'**
  String get exGymLoadError;

  /// No description provided for @exNoGymTitle.
  ///
  /// In en, this message translates to:
  /// **'No gym registered'**
  String get exNoGymTitle;

  /// No description provided for @exNoGymSub.
  ///
  /// In en, this message translates to:
  /// **'Register a nearby gym with Find a Gym'**
  String get exNoGymSub;

  /// No description provided for @exAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get exAddress;

  /// No description provided for @exHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get exHours;

  /// No description provided for @exPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get exPhone;

  /// No description provided for @exSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get exSpecialty;

  /// No description provided for @exKakaoMapArea.
  ///
  /// In en, this message translates to:
  /// **'Kakao Map area'**
  String get exKakaoMapArea;

  /// No description provided for @exDefaultTrainerName.
  ///
  /// In en, this message translates to:
  /// **'Trainer Kim'**
  String get exDefaultTrainerName;

  /// No description provided for @exDefaultGymName.
  ///
  /// In en, this message translates to:
  /// **'Gangnam Fitness Center'**
  String get exDefaultGymName;

  /// No description provided for @exChatGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, I\'m {trainer}. 😊\nHow can I help you?'**
  String exChatGreeting(String trainer);

  /// No description provided for @exChatChipPt.
  ///
  /// In en, this message translates to:
  /// **'PT consult'**
  String get exChatChipPt;

  /// No description provided for @exChatChipPass.
  ///
  /// In en, this message translates to:
  /// **'Membership inquiry'**
  String get exChatChipPass;

  /// No description provided for @exChatChipVisit.
  ///
  /// In en, this message translates to:
  /// **'Book a visit'**
  String get exChatChipVisit;

  /// No description provided for @exChatReply.
  ///
  /// In en, this message translates to:
  /// **'Got it! Your trainer will reply soon. Please share a convenient time to visit. 🙌'**
  String get exChatReply;

  /// No description provided for @exGymConsultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{gym} · 1:1 Consult'**
  String exGymConsultSubtitle(String gym);

  /// No description provided for @exMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get exMessageHint;

  /// No description provided for @myTabTitle.
  ///
  /// In en, this message translates to:
  /// **'MY'**
  String get myTabTitle;

  /// No description provided for @myDefaultUserName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get myDefaultUserName;

  /// No description provided for @myRank.
  ///
  /// In en, this message translates to:
  /// **'Rank {rank}'**
  String myRank(int rank);

  /// No description provided for @mySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get mySettingsTitle;

  /// No description provided for @myProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfileTitle;

  /// No description provided for @myGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Goals'**
  String get myGoalsTitle;

  /// No description provided for @myNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get myNotifTitle;

  /// No description provided for @mySupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Support'**
  String get mySupportTitle;

  /// No description provided for @myLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get myLogout;

  /// No description provided for @myLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out of your account?'**
  String get myLogoutConfirm;

  /// No description provided for @myCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get myCancel;

  /// No description provided for @mySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mySave;

  /// No description provided for @myProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get myProfileSaved;

  /// No description provided for @myGoalsSaved.
  ///
  /// In en, this message translates to:
  /// **'Health goals saved'**
  String get myGoalsSaved;

  /// No description provided for @mySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please try again in a moment'**
  String get mySaveFailed;

  /// No description provided for @myFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get myFieldName;

  /// No description provided for @myFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get myFieldEmail;

  /// No description provided for @myFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get myFieldPhone;

  /// No description provided for @myFieldBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get myFieldBirth;

  /// No description provided for @myGoalsDesc.
  ///
  /// In en, this message translates to:
  /// **'Summaries and feedback across the app are based on these goals.'**
  String get myGoalsDesc;

  /// No description provided for @myGoalWeight.
  ///
  /// In en, this message translates to:
  /// **'Target weight'**
  String get myGoalWeight;

  /// No description provided for @myGoalBp.
  ///
  /// In en, this message translates to:
  /// **'Target blood pressure (systolic)'**
  String get myGoalBp;

  /// No description provided for @myGoalBloodSugar.
  ///
  /// In en, this message translates to:
  /// **'Target blood sugar'**
  String get myGoalBloodSugar;

  /// No description provided for @myGoalCalories.
  ///
  /// In en, this message translates to:
  /// **'Daily calories'**
  String get myGoalCalories;

  /// No description provided for @myGoalSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium limit'**
  String get myGoalSodium;

  /// No description provided for @myNotifDietLog.
  ///
  /// In en, this message translates to:
  /// **'Diet log reminder'**
  String get myNotifDietLog;

  /// No description provided for @myNotifExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise reminder'**
  String get myNotifExercise;

  /// No description provided for @myNotifTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer message'**
  String get myNotifTrainer;

  /// No description provided for @myNotifAiCoaching.
  ///
  /// In en, this message translates to:
  /// **'AI coaching tips'**
  String get myNotifAiCoaching;

  /// No description provided for @myNotifWeeklyReport.
  ///
  /// In en, this message translates to:
  /// **'Weekly report'**
  String get myNotifWeeklyReport;

  /// No description provided for @mySupportFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get mySupportFaq;

  /// No description provided for @mySupportInquiry.
  ///
  /// In en, this message translates to:
  /// **'1:1 Inquiry'**
  String get mySupportInquiry;

  /// No description provided for @myLegalTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get myLegalTermsTitle;

  /// No description provided for @myLegalPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get myLegalPrivacyTitle;

  /// No description provided for @myLegalTermsBody.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service (Korean original governs).'**
  String get myLegalTermsBody;

  /// No description provided for @myLegalPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy (Korean original governs).'**
  String get myLegalPrivacyBody;

  /// No description provided for @myLegalEffectiveDate.
  ///
  /// In en, this message translates to:
  /// **'Effective Jan 1, 2026'**
  String get myLegalEffectiveDate;

  /// No description provided for @myAppVersion.
  ///
  /// In en, this message translates to:
  /// **'On-Care · Version 1.0.0'**
  String get myAppVersion;

  /// No description provided for @myComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{label} is coming soon'**
  String myComingSoon(String label);

  /// No description provided for @coachHeaderPill.
  ///
  /// In en, this message translates to:
  /// **'AI Health Assistant'**
  String get coachHeaderPill;

  /// No description provided for @coachHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Here are today\'s tailored tips'**
  String get coachHeaderSubtitle;

  /// No description provided for @coachCardDietTag.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get coachCardDietTag;

  /// No description provided for @coachCardDietTitle.
  ///
  /// In en, this message translates to:
  /// **'Try easing back on sodium at dinner.'**
  String get coachCardDietTitle;

  /// No description provided for @coachCardDietBody.
  ///
  /// In en, this message translates to:
  /// **'Grilled dishes or a salad are great.'**
  String get coachCardDietBody;

  /// No description provided for @coachCardExerciseTag.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get coachCardExerciseTag;

  /// No description provided for @coachCardExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'A 20-minute evening walk.'**
  String get coachCardExerciseTitle;

  /// No description provided for @coachCardExerciseBody.
  ///
  /// In en, this message translates to:
  /// **'A light walk after meals helps manage blood sugar.'**
  String get coachCardExerciseBody;

  /// No description provided for @coachCardWaterTag.
  ///
  /// In en, this message translates to:
  /// **'Hydration'**
  String get coachCardWaterTag;

  /// No description provided for @coachCardWaterTitle.
  ///
  /// In en, this message translates to:
  /// **'Drink one more glass of water.'**
  String get coachCardWaterTitle;

  /// No description provided for @coachCardWaterBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been quite active today.'**
  String get coachCardWaterBody;

  /// No description provided for @coachProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s recommendation progress'**
  String get coachProgressLabel;

  /// No description provided for @coachProgressDone.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} done'**
  String coachProgressDone(int done, int total);

  /// No description provided for @coachCtaChat.
  ///
  /// In en, this message translates to:
  /// **'Chat with AI'**
  String get coachCtaChat;

  /// No description provided for @navAddRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a record'**
  String get navAddRecordTitle;

  /// No description provided for @navAddRecordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose diet or exercise'**
  String get navAddRecordSubtitle;

  /// No description provided for @navDietOptionSub.
  ///
  /// In en, this message translates to:
  /// **'Nutrition analysis from a photo'**
  String get navDietOptionSub;

  /// No description provided for @navExerciseOptionSub.
  ///
  /// In en, this message translates to:
  /// **'Log the type and duration'**
  String get navExerciseOptionSub;

  /// No description provided for @aicHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask me anytime'**
  String get aicHeaderSubtitle;

  /// No description provided for @aicDatePillToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get aicDatePillToday;

  /// No description provided for @aicInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the AI anything'**
  String get aicInputHint;

  /// No description provided for @aicQuickRepliesLabel.
  ///
  /// In en, this message translates to:
  /// **'Try asking'**
  String get aicQuickRepliesLabel;

  /// No description provided for @aicQuickReply1.
  ///
  /// In en, this message translates to:
  /// **'Recommend a dinner menu for today'**
  String get aicQuickReply1;

  /// No description provided for @aicQuickReply2.
  ///
  /// In en, this message translates to:
  /// **'How much should I exercise today?'**
  String get aicQuickReply2;

  /// No description provided for @aicQuickReply3.
  ///
  /// In en, this message translates to:
  /// **'How are my blood sugar readings?'**
  String get aicQuickReply3;
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
