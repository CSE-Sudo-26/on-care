// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'On-Care';

  @override
  String get navDashboard => '홈';

  @override
  String get navDiet => '식단';

  @override
  String get navExercise => '운동';

  @override
  String get navMyHealth => 'MY';

  @override
  String get pageDashboardTitle => '홈';

  @override
  String get pageDietTitle => '식단';

  @override
  String get pageExerciseTitle => '운동';

  @override
  String get pageMyHealthTitle => 'My';

  @override
  String get pageAiCoachTitle => 'AI 코치';

  @override
  String get pageNotificationTitle => '알림';

  @override
  String get pagePlaceTitle => '장소';

  @override
  String get pageSignInTitle => '로그인';

  @override
  String get actionOpenAiCoach => 'AI 코치 열기';

  @override
  String get actionFindPlace => '장소 찾기';

  @override
  String get actionSignInPlaceholder => '로그인 (placeholder)';

  @override
  String get actionRetry => '다시 시도';

  @override
  String get placeholderDashboard => '대시보드 (placeholder)';

  @override
  String get placeholderDiet => '식단 기록 (placeholder)';

  @override
  String get placeholderExercise => '운동 (placeholder)';

  @override
  String get placeholderMyHealth => '내 건강 (placeholder)';

  @override
  String get placeholderAiCoach => 'AI 코치 (placeholder, mock 응답)';

  @override
  String get placeholderNotification => '알림 (placeholder)';

  @override
  String get placeholderPlace => '장소 (placeholder, Stage 4에서 Google Maps)';

  @override
  String get placeholderSignIn => '로그인 (placeholder, Stage 4에서 소셜 SDK)';

  @override
  String get errorNetwork => '네트워크 문제';

  @override
  String get errorUnauthorized => '로그인이 필요합니다';

  @override
  String get errorNotFound => '찾을 수 없습니다';

  @override
  String get errorServer => '서버 오류';

  @override
  String get errorCancelled => '취소됨';

  @override
  String get errorUnknown => '알 수 없는 오류';

  @override
  String get dashboardSectionToday => '오늘의 요약';

  @override
  String get dashboardMetricCalories => '칼로리';

  @override
  String get dashboardMetricExercise => '운동';

  @override
  String get dashboardMetricWeight => '체중';

  @override
  String get dashboardChartWeightWeek => '주간 체중';

  @override
  String dashboardCaloriesProgress(int pct, int goal) {
    return '$pct% / $goal';
  }

  @override
  String dashboardWeightDelta(String sign, String delta) {
    return '$sign$delta (지난주 대비)';
  }

  @override
  String homeGreeting(String name) {
    return '$name님, 오늘도 가볍게 시작해요 👋';
  }

  @override
  String get homeGreetingGeneric => '오늘도 가볍게 시작해요 👋';

  @override
  String get homeCoachingPill => '✦ AI 코칭';

  @override
  String get homeCoachingTitle => '오늘의 맞춤 조언';

  @override
  String get homeCoachingBody => '저녁은 나트륨을 줄이고\n20분 정도 걸어보세요';

  @override
  String get homeCoachingReady => 'AI가 오늘 3개의 맞춤 조언을 준비했어요';

  @override
  String get homeDietSodiumAlert => '나트륨 초과 감지됨';

  @override
  String get homeMacroCarbs => '탄수화물';

  @override
  String get homeMacroProtein => '단백질';

  @override
  String get homeMacroFat => '지방';

  @override
  String get homeDietRecBadge => '✦ AI 추천 저녁 식단';

  @override
  String get homeMealChickenSalad => '닭가슴살 샐러드';

  @override
  String get homeDietRecRice => '현미밥 반 공기';

  @override
  String get homeDietLogButton => '식단 기록 →';

  @override
  String get homeExerciseRoutineProgress => 'AI 추천 루틴 1/3 완료';

  @override
  String homeExerciseBurnGoal(String unit, int goal) {
    return '$unit 소모 · 목표 $goal';
  }

  @override
  String get homeExerciseBrisk => '빠르게 걷기';

  @override
  String get homeExerciseLegStretch => '하체 스트레칭';

  @override
  String get homeExerciseRecBadge => '✦ AI 추천 남은 루틴';

  @override
  String get homeExerciseRecStretch => '하체 스트레칭 10분';

  @override
  String get homeExerciseRecStrength => '저강도 근력 15분';

  @override
  String get homeExerciseLogButton => '운동 기록 →';

  @override
  String get homeSummaryToday => '오늘 종합';

  @override
  String get homeVsGoal => '목표 대비';

  @override
  String get homeNutritionTitle => '영양 현황';

  @override
  String get homeAiAnalysisPill => '✦ AI 분석';

  @override
  String get homeNutritionSubtitle => '주간 누적 추이 · 지난주 대비';

  @override
  String get homeDetails => '자세히';

  @override
  String get homeThisWeekAvg => '이번주 평균';

  @override
  String get homeLastWeekAvg => '지난주 평균';

  @override
  String get homeGoal => '목표';

  @override
  String get homeVsLastWeek => '지난주 대비';

  @override
  String homeSodiumInsight(String trend, String alert) {
    return '나트륨 섭취가 $trend 추세예요. 소금 사용량을 줄이고, $alert을 켜볼까요?';
  }

  @override
  String get homeSodiumInsightTrend => '2주 연속 증가';

  @override
  String get homeSodiumInsightAlert => '고염분 식단 알림';

  @override
  String get homeAiPill => '✦ AI';

  @override
  String get homeLegendThisWeek => '이번 주';

  @override
  String get homeLegendLastWeek => '지난 주';

  @override
  String get homeLegendToday => '오늘';

  @override
  String get homeMealReasonSodium => '나트륨 조절에 좋아요';

  @override
  String get homeMealTagLowSodium => '저나트륨';

  @override
  String get homeMealBrownRiceBox => '현미 도시락';

  @override
  String get homeMealReasonGlucose => '혈당 안정에 도움돼요';

  @override
  String get homeMealTagLowGi => '저GI';

  @override
  String get homeMealSalmon => '연어 구이 + 나물';

  @override
  String get homeMealReasonOmega => '오메가3 + 식이섬유';

  @override
  String get homeMealTagHighProtein => '고단백';

  @override
  String get homeMealTofu => '두부 채소 볶음';

  @override
  String get homeMealReasonLowCal => '칼로리 낮고 포만감↑';

  @override
  String get homeMealTagLowCal => '저칼로리';

  @override
  String get homeRecMealsTitle => '이번 주 AI 추천 식단';

  @override
  String get homeViewAll => '전체 보기';

  @override
  String homeScheduleDate(String weekday, int month, int day) {
    return '$month월 $day일 $weekday요일';
  }

  @override
  String get homeScheduleTitle => '오늘의 일정';

  @override
  String get homeScheduleEveningWalk => '저녁 산책';

  @override
  String get homeScheduleWalkDetail => '집 주변 · 20분';

  @override
  String get unitKcal => 'kcal';

  @override
  String get unitMinutes => '분';

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

    return '$countString분';
  }

  @override
  String get unitKg => 'kg';

  @override
  String get dietTitle => '식단';

  @override
  String get dietToday => '오늘로';

  @override
  String dietWeekLabel(int month, int week) {
    return '$month월 $week주차';
  }

  @override
  String get dietWeekdayMon => '월';

  @override
  String get dietWeekdayTue => '화';

  @override
  String get dietWeekdayWed => '수';

  @override
  String get dietWeekdayThu => '목';

  @override
  String get dietWeekdayFri => '금';

  @override
  String get dietWeekdaySat => '토';

  @override
  String get dietWeekdaySun => '일';

  @override
  String get dietNutritionSummary => '오늘의 영양 요약';

  @override
  String get dietCalories => '칼로리';

  @override
  String get dietSodium => '나트륨';

  @override
  String get dietSugar => '당류';

  @override
  String get dietUnitMg => 'mg';

  @override
  String get dietUnitG => 'g';

  @override
  String get dietAiFeedback => 'AI 피드백';

  @override
  String get dietTodayMeals => '오늘의 식단';

  @override
  String get dietAddMeal => '식단 추가';

  @override
  String get dietEmptyLog => '아직 기록된 식단이 없어요.\n사진으로 첫 끼니를 추가해 보세요!';

  @override
  String get dietPhotoAnalysis => '사진 분석';

  @override
  String get dietLoadError => '식단 정보를 불러오지 못했어요.';

  @override
  String get dietOtherDateEmpty =>
      '선택한 날짜의 기록은 아직 볼 수 없어요.\n오늘 날짜에서 식단을 확인해 주세요.';

  @override
  String dietTagSodium(int mg) {
    return '나트륨 ${mg}mg';
  }

  @override
  String dietTagSugar(int g) {
    return '당류 ${g}g';
  }

  @override
  String get dietMealBreakfast => '아침';

  @override
  String get dietMealLunch => '점심';

  @override
  String get dietMealDinner => '저녁';

  @override
  String get dietMealSnack => '간식';

  @override
  String dietMealSheetTitle(String meal) {
    return '$meal 식단';
  }

  @override
  String get dietAddSheetTitle => '식단 추가하기';

  @override
  String get dietAddSheetSubtitle => '사진으로 음식을 분석해요';

  @override
  String get dietPickPhoto => '사진 선택하기';

  @override
  String get dietPickPhotoSub => '갤러리에서 음식 사진 선택';

  @override
  String get dietTakePhoto => '사진 찍기';

  @override
  String get dietTakePhotoSub => '카메라로 음식 촬영';

  @override
  String get dietPhotoLoadError => '사진을 불러오지 못했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get dietAnalyzing => '분석 중…';

  @override
  String get dietAnalysisFailed => '분석 실패';

  @override
  String get dietAnalysisDone => '분석 완료!';

  @override
  String get dietAiNutritionResult => 'AI 영양 분석 결과';

  @override
  String get dietAnalyzingBody => '사진 속 음식을 분석하고 있어요';

  @override
  String get dietAnalysisFailedBody => '분석에 실패했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get dietRecognizedFood => '인식된 음식';

  @override
  String get dietNoRecognizedFood => '인식된 음식이 없어요';

  @override
  String get dietNutritionResult => '영양 분석 결과';

  @override
  String get dietSaved => '식단이 저장되었어요';

  @override
  String get dietDone => '완료';

  @override
  String get dietSaveFailed => '저장에 실패했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get dietDeleteTitle => '식단 기록 삭제';

  @override
  String get dietDeleteConfirm => '이 식단 기록을 삭제할까요?';

  @override
  String get dietCancel => '취소';

  @override
  String get dietDelete => '삭제';

  @override
  String get dietDeleted => '식단이 삭제되었어요';

  @override
  String get dietDeleteFailed => '삭제에 실패했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get dietSave => '저장';

  @override
  String get dietMealInfo => '식사 정보';

  @override
  String get dietEatenTime => '먹은 시간';

  @override
  String get dietEatenFood => '먹은 음식';

  @override
  String get dietNewFood => '새 음식';

  @override
  String get dietAddFood => '+ 음식 추가';

  @override
  String get dietEditFoodHint => '음식명과 칼로리를 수정할 수 있어요';

  @override
  String get dietTotalCalories => '총 칼로리';

  @override
  String get dietNutritionInfo => '영양 정보';

  @override
  String get dietEditNutritionHint => '분석된 값을 직접 수정할 수 있어요';

  @override
  String get dietSodiumHint => '하루 권장 2,000mg 이하';

  @override
  String get dietSugarHint => '하루 권장 50g 이하';

  @override
  String get dietDeleteMeal => '식단 삭제';

  @override
  String get exTypeWalking => '걷기';

  @override
  String get exTypeCardio => '유산소';

  @override
  String get exTypeStrength => '근력';

  @override
  String get exTypeYoga => '요가';

  @override
  String get exTypeStretching => '스트레칭';

  @override
  String get exTypeOther => '운동';

  @override
  String get exTypeOtherChip => '기타';

  @override
  String get exLevelLight => '가벼움';

  @override
  String get exLevelModerate => '보통';

  @override
  String get exLevelHigh => '높음';

  @override
  String get exExerciseLog => '운동 기록';

  @override
  String get exGymTab => '헬스장';

  @override
  String get exWeekSummary => '이번 주 운동 요약';

  @override
  String get exActivityTitle => '운동 현황';

  @override
  String get exThisWeek => '이번 주';

  @override
  String get exAiRoutineToday => 'AI 맞춤 루틴 · 오늘';

  @override
  String get exStatTime => '시간';

  @override
  String get exStatCalories => '칼로리';

  @override
  String get exStatStreak => '연속';

  @override
  String get exUnitCount => '회';

  @override
  String get exUnitStreakDays => '일 연속';

  @override
  String get exToday => '오늘';

  @override
  String get exLoadError => '운동 정보를 불러오지 못했어요.';

  @override
  String get exEmptyLog => '이번 주 운동 기록이 없어요.\n운동을 추가해 기록을 남겨 보세요!';

  @override
  String get exAiFeedback => 'AI 피드백';

  @override
  String get exAddExercise => '운동 추가';

  @override
  String get exRoutineBriskTitle => '빠르게 걷기 30분';

  @override
  String get exRoutineBriskSub => '유산소 · 혈압 관리';

  @override
  String get exRoutineStretchTitle => '하체 스트레칭';

  @override
  String get exRoutineStretchSub => '스트레칭 · 유연성';

  @override
  String get exRoutineStrengthTitle => '저강도 근력';

  @override
  String get exRoutineStrengthSub => '근력 · 근지구력';

  @override
  String get exMissionComplete => '미션 완료!';

  @override
  String exMinutesExercise(int minutes) {
    return '$minutes분 운동';
  }

  @override
  String exDurationMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String get exEditExercise => '운동 기록 수정';

  @override
  String get exSave => '저장';

  @override
  String get exExerciseType => '운동 종류';

  @override
  String get exExerciseDuration => '운동 시간';

  @override
  String get exExerciseIntensity => '운동 강도';

  @override
  String get exEstimatedCalories => '예상 소모 칼로리';

  @override
  String get exEnterDuration => '운동 시간을 입력해주세요';

  @override
  String get exCannotEdit => '이 기록은 수정할 수 없어요';

  @override
  String get exUpdated => '운동 기록이 수정됐어요';

  @override
  String get exLogged => '운동이 기록됐어요';

  @override
  String get exSaveFailed => '저장에 실패했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get exFindGym => '헬스장 찾기';

  @override
  String get exGymSearchHint => '헬스장, 지역으로 검색';

  @override
  String get exNearbyGyms => '주변 헬스장 · O2O 연동';

  @override
  String get exAiAnalysis => '✦ AI 분석';

  @override
  String exNoGymMatch(String query) {
    return '\'$query\'에 맞는 헬스장이 없어요';
  }

  @override
  String get exGymsLoadError => '헬스장을 불러오지 못했어요.';

  @override
  String get exAiTopPick => '✦ AI 추천 1순위';

  @override
  String get exTrainerChat => '트레이너 채팅';

  @override
  String get exSendHealthSummary => '건강 요약 전달';

  @override
  String exSendHealthSummaryBody(String gym) {
    return '최근 운동 기록과 건강 프로필 요약을\n$gym 트레이너에게 전달할까요?';
  }

  @override
  String get exCancel => '취소';

  @override
  String get exSend => '전달하기';

  @override
  String exHealthSummarySent(String gym) {
    return '$gym에 건강 요약을 전달했어요';
  }

  @override
  String exReasonTrainer(String name, String role) {
    return '전담 트레이너 $name$role 상주';
  }

  @override
  String exReasonHours(String hours, String weekend) {
    return '$hours$weekend 운영';
  }

  @override
  String exGymWeekdayHours(String hours) {
    return '평일 $hours';
  }

  @override
  String exGymWeekendHours(String hours) {
    return '주말 $hours';
  }

  @override
  String get exTrainer => '트레이너';

  @override
  String get exMyGym => '내 헬스장';

  @override
  String get exTrainerDedicated => '전담 트레이너';

  @override
  String get exAiSlotTitle => '✦ AI 추천 예약 시간';

  @override
  String exTrainerAvailability(String trainer) {
    return '$trainer 빈 시간';
  }

  @override
  String get exSlotToday19 => '오늘 19:00';

  @override
  String get exSlotTomorrow0730 => '내일 07:30';

  @override
  String get exSlotTomorrow20 => '내일 20:00';

  @override
  String get exSlot1Left => '잔여 1자리';

  @override
  String get exSlotAvailable => '여유 있음';

  @override
  String get exSlot2Left => '잔여 2자리';

  @override
  String exReserveConfirmedSlotGym(String slot, String gym) {
    return '$slot · $gym 예약이 확정됐어요';
  }

  @override
  String exReserveConfirm(String slot) {
    return '$slot 예약 확정';
  }

  @override
  String get exGymInfo => '헬스장 정보';

  @override
  String get exConsultButton => '💬 1:1 상담';

  @override
  String get exGymLoadError => '헬스장 정보를 불러오지 못했어요.';

  @override
  String get exNoGymTitle => '등록된 헬스장이 없어요';

  @override
  String get exNoGymSub => '헬스장 찾기로 주변 헬스장을 등록해 보세요';

  @override
  String get exAddress => '주소';

  @override
  String get exHours => '운영시간';

  @override
  String get exPhone => '전화';

  @override
  String get exSpecialty => '전문 분야';

  @override
  String get exKakaoMapArea => '카카오맵 영역';

  @override
  String get exDefaultTrainerName => '김트레이너';

  @override
  String get exDefaultGymName => '강남 피트니스 센터';

  @override
  String exChatGreeting(String trainer) {
    return '안녕하세요, $trainer입니다. 😊\n무엇을 도와드릴까요?';
  }

  @override
  String get exChatChipPt => 'PT 상담';

  @override
  String get exChatChipPass => '이용권 문의';

  @override
  String get exChatChipVisit => '방문 예약';

  @override
  String get exChatReply => '네, 확인했어요! 담당 트레이너가 곧 답변드릴게요. 편한 방문 시간도 알려주세요. 🙌';

  @override
  String exGymConsultSubtitle(String gym) {
    return '$gym · 1:1 상담';
  }

  @override
  String get exMessageHint => '메시지를 입력하세요';

  @override
  String get myTabTitle => 'MY';

  @override
  String get myDefaultUserName => '사용자';

  @override
  String myRank(int rank) {
    return '$rank위 랭킹';
  }

  @override
  String get mySettingsTitle => '설정';

  @override
  String get myProfileTitle => '내 프로필';

  @override
  String get myGoalsTitle => '건강 목표';

  @override
  String get myNotifTitle => '알림 설정';

  @override
  String get mySupportTitle => '고객 지원';

  @override
  String get myLogout => '로그아웃';

  @override
  String get myLogoutConfirm => '로그아웃 하시겠어요?';

  @override
  String get myCancel => '취소';

  @override
  String get mySave => '저장';

  @override
  String get myProfileSaved => '프로필이 저장되었어요';

  @override
  String get myGoalsSaved => '건강 목표가 저장되었어요';

  @override
  String get mySaveFailed => '저장에 실패했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get myFieldName => '이름';

  @override
  String get myFieldEmail => '이메일';

  @override
  String get myFieldPhone => '전화번호';

  @override
  String get myFieldBirth => '생년월일';

  @override
  String get myGoalsDesc => '앱 곳곳의 요약·피드백이 이 목표를 기준으로 계산돼요.';

  @override
  String get myGoalWeight => '목표 체중';

  @override
  String get myGoalBp => '목표 혈압 (수축기)';

  @override
  String get myGoalBloodSugar => '목표 혈당';

  @override
  String get myGoalCalories => '일일 칼로리';

  @override
  String get myGoalSodium => '나트륨 제한';

  @override
  String get myNotifDietLog => '식단 기록 알림';

  @override
  String get myNotifExercise => '운동 리마인더';

  @override
  String get myNotifTrainer => '트레이너 메시지';

  @override
  String get myNotifAiCoaching => 'AI 코칭 조언';

  @override
  String get myNotifWeeklyReport => '주간 리포트';

  @override
  String get mySupportFaq => '자주 묻는 질문';

  @override
  String get mySupportInquiry => '1:1 문의';

  @override
  String get myLegalTermsTitle => '이용약관';

  @override
  String get myLegalPrivacyTitle => '개인정보 처리방침';

  @override
  String get myLegalTermsBody =>
      '제1조 (목적)\n이 약관은 On-Care(이하 \"회사\")가 제공하는 건강 관리 서비스(이하 \"서비스\")의 이용과 관련하여 회사와 회원 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n제2조 (약관의 효력 및 변경)\n① 이 약관은 서비스를 이용하는 모든 회원에게 효력이 발생합니다.\n② 회사는 관련 법령을 위반하지 않는 범위에서 이 약관을 변경할 수 있으며, 변경 시 적용일자와 변경 사유를 명시하여 서비스 내에 공지합니다.\n\n제3조 (서비스의 제공)\n회사는 식단 기록, 운동 기록, 건강 지표 관리, AI 코칭 등 회원의 건강 관리를 돕는 기능을 제공합니다. 서비스의 구체적인 내용은 회사의 정책에 따라 변경될 수 있습니다.\n\n제4조 (회원의 의무)\n회원은 본인의 건강 정보를 정확하게 입력하여야 하며, 서비스가 제공하는 정보는 의학적 진단이나 치료를 대체하지 않습니다. 건강상 문제가 있는 경우 반드시 전문 의료기관의 진료를 받으시기 바랍니다.\n\n제5조 (책임의 제한)\n회사는 회원이 서비스를 통해 얻은 정보에 기반하여 내린 판단과 그 결과에 대하여 법령이 허용하는 범위 내에서 책임을 부담하지 않습니다.\n\n부칙\n이 약관은 2026년 1월 1일부터 시행합니다.';

  @override
  String get myLegalPrivacyBody =>
      'On-Care(이하 \"회사\")는 「개인정보 보호법」 등 관련 법령을 준수하며, 회원의 개인정보를 소중히 보호합니다.\n\n1. 수집하는 개인정보 항목\n회사는 회원가입 및 서비스 제공을 위하여 이름, 이메일, 전화번호, 생년월일과 함께 식단·운동·건강 지표 등 건강 관련 정보를 수집합니다.\n\n2. 개인정보의 수집 및 이용 목적\n수집한 개인정보는 회원 식별, 건강 관리 기능 제공, 맞춤형 AI 코칭, 서비스 개선 및 고객 문의 응대의 목적으로만 이용됩니다.\n\n3. 개인정보의 보유 및 이용 기간\n회원의 개인정보는 원칙적으로 회원 탈퇴 시 지체 없이 파기합니다. 다만 관련 법령에 따라 보존할 필요가 있는 경우 해당 기간 동안 안전하게 보관합니다.\n\n4. 개인정보의 제3자 제공\n회사는 회원의 동의 없이 개인정보를 외부에 제공하지 않습니다. 다만 법령에 특별한 규정이 있는 경우는 예외로 합니다.\n\n5. 이용자의 권리\n회원은 언제든지 자신의 개인정보를 조회·수정하거나 처리 정지 및 삭제를 요청할 수 있습니다.\n\n6. 개인정보 보호책임자\n개인정보와 관련한 문의는 고객 지원(support@oncare.com)으로 연락하실 수 있습니다.\n\n시행일: 2026년 1월 1일';

  @override
  String get myLegalEffectiveDate => '시행일 2026. 01. 01.';

  @override
  String get myAppVersion => 'On-Care · 버전 1.0.0';

  @override
  String myComingSoon(String label) {
    return '$label 기능은 준비 중이에요';
  }

  @override
  String get coachHeaderPill => 'AI 건강 도우미';

  @override
  String get coachHeaderSubtitle => '오늘의 맞춤 조언을 모아봤어요';

  @override
  String get coachCardDietTag => '식단';

  @override
  String get coachCardDietTitle => '저녁은 나트륨을 조금 줄여보세요.';

  @override
  String get coachCardDietBody => '구이나 샐러드가 좋아요.';

  @override
  String get coachCardExerciseTag => '운동';

  @override
  String get coachCardExerciseTitle => '저녁 산책 20분.';

  @override
  String get coachCardExerciseBody => '식후 가벼운 산책은 혈당 관리에 도움이 돼요.';

  @override
  String get coachCardWaterTag => '수분';

  @override
  String get coachCardWaterTitle => '물 한 잔 더 마시기.';

  @override
  String get coachCardWaterBody => '오늘 활동량이 많았어요.';

  @override
  String get coachProgressLabel => '오늘의 추천 진행도';

  @override
  String coachProgressDone(int done, int total) {
    return '$done/$total 완료';
  }

  @override
  String get coachCtaChat => 'AI와 대화하기';

  @override
  String get navAddRecordTitle => '새 기록 추가';

  @override
  String get navAddRecordSubtitle => '식단 또는 운동을 선택해 주세요';

  @override
  String get navDietOptionSub => '사진으로 영양 분석';

  @override
  String get navExerciseOptionSub => '종류와 시간 기록';

  @override
  String get aicHeaderSubtitle => '언제든 물어보세요';

  @override
  String get aicDatePillToday => '오늘';

  @override
  String get aicInputHint => 'AI에게 무엇이든 물어보세요';

  @override
  String get aicQuickRepliesLabel => '이런 걸 물어보세요';

  @override
  String get aicQuickReply1 => '오늘 저녁 메뉴 추천해줘';

  @override
  String get aicQuickReply2 => '오늘 운동은 얼마나 하면 좋을까?';

  @override
  String get aicQuickReply3 => '내 혈당 기록은 괜찮아?';
}
