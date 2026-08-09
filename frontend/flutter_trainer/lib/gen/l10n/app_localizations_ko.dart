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

  @override
  String get authTagline => '고객 관리를 위한 트레이너 전용 앱';

  @override
  String get authEmail => '이메일';

  @override
  String get authPassword => '비밀번호';

  @override
  String get authSignIn => '로그인';

  @override
  String get authNoAccount => '계정이 없으신가요?';

  @override
  String get authSignUp => '회원가입';

  @override
  String get authBrowseDemo => '로그인 없이 데모 둘러보기';

  @override
  String get authOr => '또는';

  @override
  String get authContinueKakao => '카카오로 시작하기';

  @override
  String get authContinueGoogle => '구글로 시작하기';

  @override
  String get authSignUpSubtitle => 'On-Care 계정을 만들어 고객 관리를 시작하세요';

  @override
  String get authName => '이름';

  @override
  String get authPasswordHint => '비밀번호 (8자 이상)';

  @override
  String get authPasswordConfirm => '비밀번호 확인';

  @override
  String get authInviteCode => '헬스장 초대 코드';

  @override
  String get authInviteCodeHelp => '소속 헬스장에서 발급받은 코드를 입력해 주세요.';

  @override
  String get authSignUpAndStart => '가입하고 시작하기';

  @override
  String get authHasAccount => '이미 계정이 있으신가요?';

  @override
  String get authErrEmptyCredentials => '이메일과 비밀번호를 입력해 주세요';

  @override
  String get authErrSocialFailed => '소셜 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get authErrSignInFailed => '로그인에 실패했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get authErrPasswordTooShort => '비밀번호는 8자 이상이어야 해요';

  @override
  String get authErrPasswordMismatch => '비밀번호가 일치하지 않아요';

  @override
  String get authErrInviteCodeRequired => '헬스장에서 받은 초대 코드를 입력해 주세요';

  @override
  String get authErrSignUpFailed => '회원가입에 실패했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get dashTitle => '대시보드';

  @override
  String get dashAddSchedule => '일정 추가';

  @override
  String get dashCreateAiRoutine => 'AI 루틴 만들기';

  @override
  String get dashLoadFailed => '대시보드를 불러오지 못했어요';

  @override
  String get dashTodayReservations => '오늘 예약';

  @override
  String get dashUnitCount => '건';

  @override
  String get dashUnitPeople => '명';

  @override
  String get dashSeeInSchedule => '스케줄에서 보기';

  @override
  String get dashMyClients => '담당 고객';

  @override
  String dashDormantClients(int count) {
    return '휴면 $count명';
  }

  @override
  String get dashAllActive => '전원 활성';

  @override
  String get dashNeedsReply => '답장 필요';

  @override
  String dashWaitingClients(int count) {
    return '고객 $count명 대기 중';
  }

  @override
  String get dashAllReplied => '모두 답장했어요';

  @override
  String get dashAttentionClients => '주의 고객';

  @override
  String get dashNoIssues => '이상 없음';

  @override
  String get dashCheckSodiumCompletion => '나트륨·이행률 확인';

  @override
  String get dashWeeklyCompletion => '주간 세션 이행률';

  @override
  String dashAveragePercent(int percent) {
    return '평균 $percent%';
  }

  @override
  String get dashNoRecordsThisWeek => '아직 이번 주 기록이 없어요';

  @override
  String get dashAiSummaryTitle => 'AI 코칭 요약';

  @override
  String get dashToday => '오늘';

  @override
  String get dashAiNoClients =>
      '아직 담당 고객이 없어요. 고객을 등록하면 식단·운동 데이터를 모아 코칭 포인트를 짚어 드릴게요.';

  @override
  String dashAiUnread(int count) {
    return '고객 $count명이 답장을 기다리고 있어요. 먼저 대화를 확인하고 오늘 루틴을 조정해 보세요.';
  }

  @override
  String dashAiSodium(int total, int over) {
    return '이번 주 담당 고객 $total명 중 $over명이 나트륨 목표를 넘겼어요. 저염 식단과 유산소 중심 루틴을 제안해 보세요.';
  }

  @override
  String dashAiLowCompletion(int count, int threshold) {
    return '$count명의 주간 이행률이 $threshold% 아래예요. 강도를 낮춘 루틴으로 다시 습관을 잡아 주세요.';
  }

  @override
  String dashAiAllOnTrack(int total) {
    return '담당 고객 $total명 모두 목표 범위 안이에요. 지금 강도를 유지하면서 다음 주 목표를 올려 보세요.';
  }

  @override
  String get dashAttentionTitle => '확인 필요 고객';

  @override
  String dashMoreCount(int count) {
    return '+$count명';
  }

  @override
  String get dashNoAttention => '지금 챙길 고객이 없어요';

  @override
  String get dashTodaySchedule => '오늘의 일정';

  @override
  String get dashSeeAll => '전체 보기';

  @override
  String get dashScheduleLoadFailed => '일정을 불러오지 못했어요';

  @override
  String get dashNoScheduleToday => '오늘 등록된 일정이 없어요';

  @override
  String get dashEmptySlot => '빈 시간';

  @override
  String get weekdayMon => '월';

  @override
  String get weekdayTue => '화';

  @override
  String get weekdayWed => '수';

  @override
  String get weekdayThu => '목';

  @override
  String get weekdayFri => '금';

  @override
  String get weekdaySat => '토';

  @override
  String get weekdaySun => '일';

  @override
  String get clientsLoadFailed => '고객 정보를 불러오지 못했어요';

  @override
  String clientsCountSummary(int total, int active) {
    return '$total명 · 활성 $active명';
  }

  @override
  String get clientsNew => '신규 고객';

  @override
  String get clientsTitle => '고객';

  @override
  String get clientsPickHint => '왼쪽에서 고객을 선택하면\n대화·식단·운동 기록이 여기에 열려요';

  @override
  String get clientsEmpty => '아직 담당 고객이 없어요';

  @override
  String clientsEmptyForFilter(String filter) {
    return '$filter에 해당하는 고객이 없어요';
  }

  @override
  String clientsFilterSummary(String filter, int shown, int total) {
    return '$filter · $shown/$total명';
  }

  @override
  String get clientsSeeAll => '전체 보기';

  @override
  String get clientsNameRequired => '이름을 입력해 주세요';

  @override
  String get clientsAddFailed => '등록에 실패했어요. 다시 시도해 주세요';

  @override
  String get clientsDuplicateName => '이미 같은 이름의 고객이 있어요';

  @override
  String get clientsAddTitle => '신규 고객 등록';

  @override
  String get clientsNameLabel => '고객 이름';

  @override
  String get clientsGoalLabel => '목표 (예: 체중 감량 · 근력 향상)';

  @override
  String get clientsAddAction => '등록하기';

  @override
  String get clientTabDiet => '식단';

  @override
  String get clientTabWorkout => '운동';

  @override
  String get clientNotFound => '고객을 찾을 수 없어요';

  @override
  String get clientBackToList => '고객 목록으로';

  @override
  String get clientList => '고객 목록';

  @override
  String get metricCalories => '칼로리';

  @override
  String get metricSodium => '나트륨';

  @override
  String get metricSugar => '당류';

  @override
  String get clientWeeklyReport => '주간 리포트';

  @override
  String get clientAskAi => 'AI에게 묻기';

  @override
  String get clientActive => '활성';

  @override
  String get clientDormant => '휴면';

  @override
  String get clientClosePanel => '패널 닫기';

  @override
  String get clientChat => '채팅';

  @override
  String clientChatWithUnread(String name, int count) {
    return '$name님과 채팅, 안 읽은 메시지 $count개';
  }

  @override
  String clientChatWith(String name) {
    return '$name님과 채팅';
  }

  @override
  String get chatTooLong => '메시지가 너무 길어요 (최대 2000자)';

  @override
  String get chatSendFailed => '메시지 전송에 실패했어요. 다시 시도해 주세요';

  @override
  String get chatLoadFailed => '대화를 불러오지 못했어요';

  @override
  String chatDemoAnalyzed(String name) {
    return 'AI가 $name님의 식단·운동 데이터를 분석했어요';
  }

  @override
  String get chatDemoReportSent => '트레이너님께 요약 리포트가 전송됐어요';

  @override
  String chatDemoRoutineSent(String name) {
    return 'AI 분석 기반 루틴이 $name님에게 전송됐어요';
  }

  @override
  String get chatDemoNotified => '고객 앱에 알림이 전달됐어요';

  @override
  String get chatInputHint => '메시지 입력...';

  @override
  String get coachSheetThisClient => '이 회원';

  @override
  String get coachSheetLoadFailed => 'AI 코칭을 불러오지 못했어요';

  @override
  String coachSheetTitle(String name) {
    return '$name 코칭 상담';
  }

  @override
  String get coachSheetSubtitle => '이 회원의 식단·운동 기록을 근거로 답해요.';

  @override
  String get coachSheetHint => '예) 나트륨이 계속 높은데 어떤 식단을 권할까요?';

  @override
  String get coachSheetSources => '근거';

  @override
  String get coachSheetAsk => '물어보기';

  @override
  String get coachSheetAskAgain => '다시 묻기';

  @override
  String get consultTitle => '상담 요청';

  @override
  String consultPendingCount(int count) {
    return '대기 중 $count건';
  }

  @override
  String get consultNoPending => '대기 중인 요청이 없어요';

  @override
  String get consultShowAll => '전체 보기';

  @override
  String get consultShowPending => '대기 중만';

  @override
  String get consultLoadFailed => '상담 요청을 불러오지 못했어요';

  @override
  String get consultRetryLater => '잠시 후 다시 시도해 주세요';

  @override
  String get consultEmptyPending => '대기 중인 상담 요청이 없어요';

  @override
  String get consultEmptyHistory => '상담 요청 이력이 없어요';

  @override
  String get consultEmptyHint => '회원이 헬스장이나 나를 지정해 상담을 신청하면 여기에 표시돼요';

  @override
  String get consultActionFailed => '상담을 처리하지 못했어요';

  @override
  String consultApproved(String name) {
    return '$name 회원을 담당 고객으로 등록했어요';
  }

  @override
  String get consultRejected => '상담 요청을 반려했어요';

  @override
  String get consultTargetGym => '헬스장 문의';

  @override
  String get consultTargetTrainer => '트레이너 지정';

  @override
  String get consultExerciseGoal => '운동 목표';

  @override
  String get consultHealthPurpose => '건강관리 목적';

  @override
  String get consultPreferredTime => '희망 일시';

  @override
  String get consultGym => '문의 헬스장';

  @override
  String get consultReject => '거절';

  @override
  String get consultApprove => '승인';

  @override
  String get consultRejectTitle => '상담 요청 반려';

  @override
  String get consultRejectNotice => '입력한 사유는 회원에게 알림으로 전달돼요.';

  @override
  String get consultRejectHint => '예) 이번 달은 정원이 찼어요';

  @override
  String get consultRejectAction => '반려하기';

  @override
  String get consultStatusApproved => '담당 고객으로 등록됨';

  @override
  String get workoutRecords => '운동 기록';

  @override
  String get workoutLoadFailed => '운동 기록을 불러오지 못했어요';

  @override
  String get workoutEmpty => '아직 운동 기록이 없어요';

  @override
  String get routinesAssigned => '배정된 루틴';

  @override
  String get routineNew => '새 루틴';

  @override
  String get routinesLoadFailed => '루틴을 불러오지 못했어요';

  @override
  String get routinesEmpty => '아직 이 고객에게 배정된 루틴이 없어요';

  @override
  String minutesShort(int minutes) {
    return '$minutes분';
  }

  @override
  String get ptProgramHistory => 'PT 프로그램 이력';

  @override
  String get scheduleLoadFailed => '일정을 불러오지 못했어요';

  @override
  String get ptSessionsEmpty => '등록된 PT 세션이 없어요';

  @override
  String get labelToday => '오늘';

  @override
  String sessionTypeAndDuration(String type, int minutes) {
    return '$type · $minutes분';
  }

  @override
  String get programNone => '등록된 프로그램 없음';

  @override
  String get weekCompletionRate => '이번 주 완료율';

  @override
  String get legendDone => '완료';

  @override
  String get legendPartial => '부분';

  @override
  String get legendMissed => '미완료';

  @override
  String get clientFeedback => '고객 피드백';

  @override
  String get trainerNote => '트레이너 메모';

  @override
  String get dietLoadFailed => '식단을 불러오지 못했어요';

  @override
  String get dietTodaySummary => '오늘 영양 요약';

  @override
  String get dietSodiumTrend => '최근 7일 나트륨 추이';

  @override
  String dietAverageMg(int value) {
    return '평균 ${value}mg';
  }

  @override
  String dietSodiumOverDays(int days, int target) {
    return '지난 7일 중 $days일 목표(${target}mg)를 초과했어요.';
  }

  @override
  String dietSodiumAllWithin(int target) {
    return '지난 7일 모두 목표(${target}mg) 이내예요. 좋아요!';
  }

  @override
  String dietSodiumValue(int value) {
    return '나트륨 ${value}mg';
  }

  @override
  String get dietAiAnalysis => 'AI 분석';

  @override
  String dietAiOverSodium(int over) {
    return '나트륨이 목표치를 ${over}mg 초과했어요. 오늘 운동 루틴에 유산소를 추가하면 도움이 돼요.';
  }

  @override
  String get dietAiBalanced => '오늘 식단은 균형이 잘 맞아요. 현재 루틴을 유지하세요.';

  @override
  String get consultStatusRejected => '반려됨';

  @override
  String consultStatusRejectedWithNote(String note) {
    return '반려됨 · $note';
  }

  @override
  String get dateToday => '오늘';

  @override
  String get dateTomorrow => '내일';

  @override
  String get dateYesterday => '어제';

  @override
  String dateMonthDayWeekday(int month, int day, String weekday) {
    return '$month월 $day일 ($weekday)';
  }

  @override
  String datePrefixed(String prefix, String date) {
    return '$prefix · $date';
  }

  @override
  String dateMonthDay(int month, int day) {
    return '$month월 $day일';
  }

  @override
  String dateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get reportsTitle => '리포트';

  @override
  String reportsSubtitle(String week) {
    return '$week 주차 · 운영 지표와 고객 리포트';
  }

  @override
  String get reportsPrevWeek => '이전 주';

  @override
  String get reportsNextWeek => '다음 주';

  @override
  String get reportsLoadFailed => '리포트를 불러오지 못했어요';

  @override
  String get reportsNoClients => '담당 고객이 없어 리포트를 만들 수 없어요';

  @override
  String get reportsWeekly => '주간 리포트';

  @override
  String get reportsSendFailed => '리포트 전송에 실패했어요. 다시 시도해 주세요';

  @override
  String reportsSent(String name) {
    return '$name님에게 리포트를 보냈어요';
  }

  @override
  String get reportsScheduleWarning => '이번 주 일정을 불러오지 못해 세션 수가 비어 있을 수 있어요';

  @override
  String get reportsSessionsThisWeek => '이번 주 세션';

  @override
  String get unitTimes => '회';

  @override
  String get unitDays => '일';

  @override
  String reportsCompletionRate(int rate) {
    return '완료율 $rate%';
  }

  @override
  String get reportsProgramReady => '프로그램 준비';

  @override
  String get reportsSessionsWithRoutine => '루틴이 붙은 세션';

  @override
  String get reportsActiveClients => '활성 고객';

  @override
  String get reportsPickClient => '고객 선택';

  @override
  String reportsClientWeekly(String name) {
    return '$name님 주간 리포트';
  }

  @override
  String get reportsPtSessions => 'PT 세션';

  @override
  String get reportsCompletionAvg => '운동 이행률';

  @override
  String get reportsSodiumOver => '나트륨 초과';

  @override
  String get reportsCompletionByDay => '요일별 운동 이행률';

  @override
  String get reportsNoLastWeekDaily => '지난 주 요일별 기록은 아직 없어요';

  @override
  String get reportsNoWorkoutsThisWeek => '이번 주 운동 기록이 없어요';

  @override
  String get reportsSodiumTrend => '나트륨 추이';

  @override
  String get reportsNoLastWeekSodium => '지난 주 나트륨 추이는 아직 없어요';

  @override
  String get reportsSendStateSent => '전송됨';

  @override
  String get reportsSendStateSending => '전송 중…';

  @override
  String get reportsSendAction => '고객에게 전송';

  @override
  String reportBodyTitle(String range) {
    return '📊 $range 주간 리포트';
  }

  @override
  String reportBodySessions(int done, int booked) {
    return 'PT 세션 $done/$booked회 완료';
  }

  @override
  String reportBodyCompletion(int avg) {
    return '운동 이행률 평균 $avg%';
  }

  @override
  String reportBodySodium(int avg, int days) {
    return '나트륨 평균 ${avg}mg · 목표 초과 $days일';
  }

  @override
  String get reportBodyPraise => '이번 주 정말 잘하셨어요. 다음 주도 이 페이스 유지해요!';

  @override
  String get reportBodyEncourage => '다음 주에는 조금만 더 챙겨봐요. 제가 루틴을 조정해 둘게요.';
}
