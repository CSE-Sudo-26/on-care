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
  String get navNotifications => '알림';

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

  @override
  String get schedTitle => '스케줄';

  @override
  String get schedSent => '전송됨';

  @override
  String get schedDeleteTitle => '일정 삭제';

  @override
  String schedDeleteConfirm(String time, String name) {
    return '$time $name님 세션을 삭제할까요?';
  }

  @override
  String get schedDeleteFailed => '일정 삭제에 실패했어요. 다시 시도해 주세요';

  @override
  String get schedCompleteFailed => '완료 처리에 실패했어요. 다시 시도해 주세요';

  @override
  String get schedViewDay => '일';

  @override
  String get schedViewWeek => '주';

  @override
  String get schedSlots => '예약 슬롯';

  @override
  String get schedNewSession => '새 일정';

  @override
  String get schedLoadFailed => '스케줄을 불러오지 못했어요';

  @override
  String get schedEmptyDay => '이 날짜에는 일정이 없어요.\n아래에서 새 일정을 추가해 보세요.';

  @override
  String get schedCompleteTitle => '세션 완료 처리';

  @override
  String schedCompleteBody(String time, String name) {
    return '$time $name님 세션을 완료로 표시하고 운동기록에 남길게요.';
  }

  @override
  String get schedNoteOptional => '트레이너 메모 (선택)';

  @override
  String get schedCompleteAction => '완료 처리';

  @override
  String get schedNewClient => '신규 고객';

  @override
  String get schedSaveFailed => '일정 저장에 실패했어요. 다시 시도해 주세요';

  @override
  String get schedAddTitle => '새 일정 추가';

  @override
  String get schedEditTitle => '일정 수정';

  @override
  String get schedFieldClient => '고객';

  @override
  String get schedFieldType => '유형';

  @override
  String get schedFieldTime => '시간';

  @override
  String get schedHourSuffix => '시';

  @override
  String get schedMinuteSuffix => '분';

  @override
  String get schedFieldDuration => '소요 시간';

  @override
  String get schedNote => '트레이너 메모';

  @override
  String get schedNoteHint => '수업 준비사항이나 고객 특이사항을 입력하세요';

  @override
  String get schedAddAction => '추가하기';

  @override
  String get schedSaveAction => '저장하기';

  @override
  String get progInvalid => '운동 이름과 세트 수를 확인해 주세요';

  @override
  String get progSaveFailed => '프로그램 저장에 실패했어요. 다시 시도해 주세요';

  @override
  String get progEditTitle => '프로그램 수정';

  @override
  String get progAddExercise => '운동 추가';

  @override
  String get progNoteHint => '프로그램 진행 시 참고할 내용을 입력하세요';

  @override
  String get progSaving => '저장 중...';

  @override
  String get progSaveAction => '프로그램 저장';

  @override
  String get progExerciseName => '운동 이름';

  @override
  String get progDeleteExercise => '운동 삭제';

  @override
  String get progSets => '세트';

  @override
  String get progReps => '횟수/시간';

  @override
  String get progWeight => '중량';

  @override
  String get progOptional => '선택';

  @override
  String progSetsByReps(int sets, String reps) {
    return '$sets세트 × $reps';
  }

  @override
  String get progEmpty => '아직 계획된 프로그램이 없어요';

  @override
  String get progEmptyHint => 'AI 루틴 탭에서 프로그램을 만들어 보내거나, 채팅으로 미리 조율해 보세요.';

  @override
  String get schedEmptySlotShort => '비어 있음';

  @override
  String get schedSentToClient => '고객 앱으로 전송 완료!';

  @override
  String schedSentTo(String name) {
    return '$name님에게 전송됨';
  }

  @override
  String schedSentProgramTo(String name, String date) {
    return '$name님에게 $date PT 프로그램 전송';
  }

  @override
  String get slotCapacityInvalid => '정원은 1명 이상 100명 이하로 입력해 주세요.';

  @override
  String get slotPastTime => '현재보다 이후 시간만 예약 슬롯으로 만들 수 있어요.';

  @override
  String get slotOpened => '예약 슬롯을 열었습니다.';

  @override
  String get slotEditTitle => '예약 슬롯 수정';

  @override
  String get slotStartTime => '시작 시간';

  @override
  String get slotCapacity => '정원';

  @override
  String slotBookedNow(int count) {
    return '현재 예약 $count명';
  }

  @override
  String get slotUpdated => '예약 슬롯을 수정했습니다.';

  @override
  String get slotCloseTitle => '예약 슬롯 닫기';

  @override
  String slotCloseBody(int count) {
    return '이미 예약된 $count건의 일정은 유지되고, 신규 예약만 중단됩니다.';
  }

  @override
  String get slotClosed => '신규 예약을 닫았습니다.';

  @override
  String get slotActionFailed => '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get slotManageTitle => '예약 슬롯 관리';

  @override
  String slotIntro(String date) {
    return '$date에 회원이 예약할 시간을 엽니다.';
  }

  @override
  String get slotOpenAction => '열기';

  @override
  String get slotReload => '다시 불러오기';

  @override
  String get slotEmpty => '이 날짜에 열린 예약 슬롯이 없습니다.';

  @override
  String slotClosedSummary(int booked) {
    return '예약 닫힘 · 예약 $booked명';
  }

  @override
  String slotOpenSummary(int booked, int remaining) {
    return '예약 $booked명 · 잔여 $remaining명';
  }

  @override
  String get slotCloseAction => '예약 닫기';

  @override
  String get myCareerInvalid => '경력은 0~80 사이의 연수로 입력해 주세요.';

  @override
  String get myProfileSaveFailed => '프로필을 저장하지 못했습니다.';

  @override
  String get myGymChangeFailed => '소속 헬스장 변경에 실패했습니다. 나머지 프로필 정보는 저장됐어요.';

  @override
  String get myTabProfile => '내 정보';

  @override
  String get myTabSettings => '설정';

  @override
  String get mySaving => '저장 중';

  @override
  String get myEditProfile => '프로필 수정';

  @override
  String get mySaved => '변경사항이 저장됐어요';

  @override
  String get myCertifications => '자격증 · 인증';

  @override
  String get myMonthStats => '이번 달 통계';

  @override
  String get myGym => '소속 헬스장';

  @override
  String get myNotifications => '알림';

  @override
  String get myNotifNewMessage => '새 메시지 알림';

  @override
  String get myNotifNewMessageHint => '고객이 메시지를 보내면 사이드바 뱃지로 알려드려요';

  @override
  String get myNotifSessionReminder => '수업 시작 전 알림';

  @override
  String get myNotifSessionReminderHint => '예정된 세션이 다가오면 대시보드에서 강조해요';

  @override
  String get myReminderLead => '알림 시점';

  @override
  String myMinutesBefore(int minutes) {
    return '$minutes분 전';
  }

  @override
  String get myAccount => '계정';

  @override
  String get myChangePassword => '비밀번호 변경';

  @override
  String get myChangePasswordHint => '현재 비밀번호를 확인한 뒤 교체해요';

  @override
  String get myChangePasswordDemo => '데모 모드에는 계정이 없어 변경할 수 없어요';

  @override
  String get myLoginAccount => '로그인 계정';

  @override
  String get myAppInfo => '앱 정보';

  @override
  String get myService => '서비스';

  @override
  String get myVersion => '버전';

  @override
  String get myContact => '문의';

  @override
  String get myPasswordChanged => '비밀번호를 변경했어요';

  @override
  String myCareerYears(String career) {
    return '경력 $career';
  }

  @override
  String get myFieldName => '이름 (계정 정보)';

  @override
  String get myFieldEmail => '이메일 (계정 정보)';

  @override
  String get myFieldPhone => '연락처';

  @override
  String get myFieldSpecialty => '전문 분야';

  @override
  String get myFieldCareer => '경력';

  @override
  String get myFieldIntro => '소개';

  @override
  String get myAddCertification => '자격증 추가...';

  @override
  String get myAdd => '추가';

  @override
  String get myStatClients => '담당 고객';

  @override
  String get myStatSessionsDone => '완료 세션';

  @override
  String get myStatRoutinesSent => '루틴 전송';

  @override
  String get myGymName => '헬스장 이름';

  @override
  String get myGymAddress => '주소';

  @override
  String get myGymHours => '운영 시간';

  @override
  String get myGymPhone => '연락처';

  @override
  String get myGymOpen => '영업 중';

  @override
  String get myGymListFailed => '헬스장 목록을 불러오지 못했습니다.';

  @override
  String get myNoGym => '소속 없음';

  @override
  String get mySignOut => '로그아웃';

  @override
  String get myPwCurrentRequired => '현재 비밀번호를 입력해 주세요';

  @override
  String myPwTooShort(int min) {
    return '새 비밀번호는 $min자 이상이어야 해요';
  }

  @override
  String get myPwMismatch => '새 비밀번호가 서로 달라요';

  @override
  String get myPwChangeFailed => '비밀번호를 변경할 수 없어요';

  @override
  String get myPwChangeRetry => '변경에 실패했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get myPwCurrent => '현재 비밀번호';

  @override
  String myPwNew(int min) {
    return '새 비밀번호 ($min자 이상)';
  }

  @override
  String get myPwConfirm => '새 비밀번호 확인';

  @override
  String get myPwChanging => '변경 중…';

  @override
  String get myPwChangeAction => '변경하기';

  @override
  String get myProfileEmpty => '프로필 응답이 비어 있습니다.';

  @override
  String get myInputInvalid => '입력값을 확인해 주세요.';

  @override
  String get myGymConflict => '현재 소속 상태와 충돌합니다.';

  @override
  String get myGymNotFound => '헬스장을 찾을 수 없습니다.';

  @override
  String get myPwDemoUnavailable => '데모 모드에서는 비밀번호를 변경할 수 없어요';

  @override
  String get mySettingsSaveFailed => '설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요';

  @override
  String myYearsSuffix(int years) {
    return '$years년';
  }

  @override
  String get routineTypeWalking => '걷기';

  @override
  String get routineTypeCardio => '유산소';

  @override
  String get routineTypeStrength => '근력';

  @override
  String get routineTypeYoga => '요가';

  @override
  String get routineTypeStretching => '스트레칭';

  @override
  String get routineTypeOther => '기타';

  @override
  String get routineFieldType => '운동 유형';

  @override
  String get routineFieldMinutes => '운동 시간';

  @override
  String get routineFieldIntensity => '운동 강도';

  @override
  String get intensityLight => '가벼움';

  @override
  String get intensityModerate => '보통';

  @override
  String get intensityHigh => '높음';

  @override
  String get coachTitle => 'AI 코칭';

  @override
  String get coachSubtitle => '식단 · 건강 데이터 기반 루틴 생성';

  @override
  String get coachSendDone => '전송 완료';

  @override
  String get coachSendNoResponse =>
      '응답을 받지 못했어요. 고객의 받은 루틴을 확인한 뒤 필요한 경우에만 다시 보내주세요';

  @override
  String get coachSendFailed => '전송에 실패했어요. 다시 시도해 주세요';

  @override
  String get coachCustomRoutine => 'AI 맞춤 루틴';

  @override
  String get coachNeedOneExercise => '운동을 하나 이상 추가해 주세요';

  @override
  String get coachScheduleFailed => '스케줄 등록에 실패했어요. 다시 시도해 주세요';

  @override
  String get coachNoClients => '등록된 고객이 없어요';

  @override
  String get coachTodayDiet => '오늘 식단 요약';

  @override
  String get coachRecommended => 'AI 추천 루틴';

  @override
  String get coachBackToList => '추천 목록으로';

  @override
  String get coachReviewed => 'AI 생성 후 트레이너 검토 완료';

  @override
  String get coachTrainerAdded => '트레이너 추가';

  @override
  String get coachClientNotified => '고객 앱에 알림이 전송됐어요';

  @override
  String coachRegisteredOn(String date) {
    return '$date 스케줄에 등록됨';
  }

  @override
  String coachRegisterOn(String date) {
    return '$date PT 스케줄에 등록';
  }

  @override
  String get labelTomorrow => '내일';

  @override
  String coachFindInSchedule(String date) {
    return '스케줄 탭에서 $date 세션의 프로그램으로 확인할 수 있어요';
  }

  @override
  String get coachVerdictSodium => 'AI 판단: 나트륨 초과 → 유산소 강화 권장';

  @override
  String get coachVerdictBalanced => 'AI 판단: 식단 균형 양호 → 근력 중심 루틴 유지';

  @override
  String get coachRequestCustom => 'AI에게 맞춤 루틴 요청하기';

  @override
  String coachRequestBlurb(String name) {
    return '$name님의 데이터를 분석해 회복형·강화형 후보를 만들고 이 화면에서 비교·수정할 수 있어요.';
  }

  @override
  String get coachTapToEdit => '탭하여 수정';

  @override
  String get coachAddExerciseManually => '＋ 운동 직접 추가';

  @override
  String get coachExerciseNameHint => '운동 이름 (예: 레그프레스 3세트)';

  @override
  String coachSentToClient(String name) {
    return '$name님에게 전송 완료!';
  }

  @override
  String coachReviewAndSend(String name) {
    return '검토 완료 · $name님에게 전송';
  }

  @override
  String get coachTemplates => '프로그램 템플릿';

  @override
  String coachTemplateSummary(int count, int minutes) {
    return '$count개 · $minutes분';
  }

  @override
  String get coachSentHistory => '전송 이력';

  @override
  String get coachHistoryFailed => '이력을 불러오지 못했어요';

  @override
  String get coachHistoryEmpty => '아직 보낸 프로그램이 없어요';

  @override
  String get coachHomework => '숙제';

  @override
  String coachRoutineSummary(String name, int minutes) {
    return '$name · $minutes분';
  }

  @override
  String get coachTrainer => '트레이너';

  @override
  String coachSessionExercises(String type, int count) {
    return '$type · 운동 $count개';
  }

  @override
  String get aiReasonSodium => '오늘 나트륨이 목표를 초과해 저강도 유산소 비중을 높이는 것이 좋아요.';

  @override
  String get aiReasonBalanced => '오늘 식단 균형이 안정적이라 기존 운동 강도를 유지해도 좋아요.';

  @override
  String aiReasonGoal(String goal, String last) {
    return '$goal 목표와 최근 $last 기록을 고려했어요.';
  }

  @override
  String get aiTagRecommended => '추천';

  @override
  String get aiTagExisting => '기존 AI 추천';

  @override
  String get aiTagCustom => '맞춤';

  @override
  String get aiExistingBlurb => '고객의 최근 식단과 운동 기록을 반영한 기존 추천이에요.';

  @override
  String get aiOptionRecovery => '회복안';

  @override
  String get aiOptionPush => '강화안';

  @override
  String get aiOptionExisting => '기존안';

  @override
  String get aiGenerateFailed => 'AI 생성에 실패했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get aiExerciseNameRequired => '운동 이름을 입력해 주세요';

  @override
  String get aiKeepOneExercise => '운동을 하나 이상 남겨 주세요';

  @override
  String aiRoutineSent(String name) {
    return '$name님에게 루틴을 전송했어요';
  }

  @override
  String aiExerciseWithMinutes(String name, int minutes) {
    return '$name $minutes분';
  }

  @override
  String aiCustomRoutineNamed(String option) {
    return 'AI 맞춤 루틴 ($option)';
  }

  @override
  String get aiAnalysing => 'AI가 분석 중…';

  @override
  String get aiGenerateCandidates => '맞춤 루틴 후보 생성';

  @override
  String get aiReviewDone => '검토 완료';

  @override
  String aiRoutineFor(String name) {
    return 'AI 루틴 · $name';
  }

  @override
  String get aiAnalysedData => '고객 데이터를 분석했어요';

  @override
  String get aiGoal => '목표';

  @override
  String get aiTodaySodium => '오늘 나트륨';

  @override
  String get aiOverTarget => ' · 목표 초과';

  @override
  String aiBasisCompletion(String goal, int rate) {
    return '$goal · 완료율 $rate% 기준';
  }

  @override
  String get aiBasisRuleBased => ' · 규칙 기반 생성';

  @override
  String aiTotalMinutesIntensity(int total, String intensity) {
    return '총 $total분 · 강도 $intensity';
  }

  @override
  String aiExerciseBullet(String name, int minutes) {
    return '· $name · $minutes분 ';
  }

  @override
  String aiEditOption(String option) {
    return '$option 수정';
  }

  @override
  String get aiEditBlurb => '기존 AI 추천과 같은 방식으로 운동명·시간·구성을 수정할 수 있어요.';

  @override
  String get aiAddExerciseManually => '운동 직접 등록';

  @override
  String get aiExerciseNameExample => '예: 레그프레스 3세트';

  @override
  String get aiRegister => '등록';

  @override
  String get aiNoteForClient => '고객에게 함께 전달할 내용';

  @override
  String aiReviewedSuggestion(String option) {
    return '검토 완료 · AI 추천 루틴 ($option)';
  }

  @override
  String get aiEditsApplied => '선택하고 수정한 내용이 최종 추천 목록에 반영됐어요.';

  @override
  String aiGoToChat(String name) {
    return '$name님 채팅으로 이동';
  }

  @override
  String get aiSending => '전송 중…';

  @override
  String get aiSendToClient => '고객에게 전송';

  @override
  String get aiGoToChatHint => '아래 버튼에서 고객 채팅으로 이동해 바로 안내할 수 있어요.';

  @override
  String get aiStepConditions => '조건 설정';

  @override
  String get aiStepReview => '후보 검토';

  @override
  String get aiStepDone => '추천 완료';

  @override
  String get aiStepperLabel => '맞춤 루틴 생성 진행 단계';

  @override
  String coachTemplateSummaryWithGoal(String goal, int count, int minutes) {
    return '$goal · $count개 · $minutes분';
  }

  @override
  String get aiWithinTarget => ' · 적정';

  @override
  String get aiRecentRoutine => '최근 루틴';

  @override
  String get aiTrainerNoteEditable => '트레이너 메모 · 수정 가능';

  @override
  String get aiNotePlaceholderHint =>
      '회색 제안 문구는 입력 전 참고용이며, 직접 입력한 메모만 저장·전송돼요.';

  @override
  String get aiGenerateConditions => '생성 조건';

  @override
  String get aiCompareCandidates => '맞춤 루틴 후보를 비교해 보세요';

  @override
  String get goalWeightLoss => '체중 감량';

  @override
  String get goalStrength => '근력 향상';

  @override
  String get goalFitness => '체력 증진';

  @override
  String get goalPosture => '자세 교정';

  @override
  String get goalHealth => '건강 관리';

  @override
  String get goalOther => '기타';

  @override
  String get purposeWeight => '체중 관리';

  @override
  String get purposeChronic => '만성질환 관리';

  @override
  String get purposeRehab => '재활';

  @override
  String get purposeGeneral => '전반적 건강';

  @override
  String get purposeNone => '해당 없음';

  @override
  String get purposeOther => '기타';

  @override
  String get slotMorning => '오전';

  @override
  String get slotAfternoon => '오후';

  @override
  String get slotEvening => '저녁';

  @override
  String get slotFlexible => '조율 가능';

  @override
  String get unknownMember => '알 수 없는 회원';

  @override
  String get filterAll => '전체';

  @override
  String get alertSodiumOver => '나트륨 초과';

  @override
  String get alertLowCompletion => '이행률 저조';

  @override
  String get alertAwaitingReply => '답장 대기';

  @override
  String get clientLastRoutine => '마지막 루틴';

  @override
  String metricOverBy(String unit) {
    return '$unit 초과';
  }

  @override
  String get clientNoGoal => '목표 설정 전';

  @override
  String get clientNoChat => '아직 대화가 없어요';

  @override
  String get chatJustNow => '방금';

  @override
  String get chartNotEnoughData => '데이터가 아직 부족해요';

  @override
  String get reportEmptyResponse => '리포트 응답이 비어 있어요';

  @override
  String get authErrInvalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다.';

  @override
  String get authErrEmailTaken => '이미 가입된 이메일입니다.';

  @override
  String get authErrInviteCodeInvalid => '사용할 수 없는 초대 코드예요. 헬스장에 확인해 주세요.';

  @override
  String get authErrSessionExpired => '세션이 만료됐어요. 다시 로그인해 주세요.';

  @override
  String get authErrNoSocialToken => '소셜 로그인 토큰이 없어요';

  @override
  String get authErrNetwork => '네트워크 연결을 확인해 주세요.';

  @override
  String get authErrGeneric => '로그인 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get authErrEmptyResponse => '응답이 비어 있어요.';

  @override
  String get coachDemoUnavailable => '데모 모드에서는 AI 코칭을 사용할 수 없어요';

  @override
  String get coachNotMyClient => '담당 고객이 아니에요';

  @override
  String get coachAskFailed => '질문을 보낼 수 없어요';

  @override
  String get consultDemoUnavailable => '데모 모드에서는 상담을 처리할 수 없어요';

  @override
  String get slotCapacityRange => '정원은 1명 이상 100명 이하이어야 합니다.';

  @override
  String get slotFutureOnly => '현재보다 이후 시간만 예약 슬롯으로 설정할 수 있습니다.';

  @override
  String get slotNotFound => '예약 슬롯을 찾을 수 없습니다.';

  @override
  String get slotCapacityBelowBooked => '이미 예약된 인원보다 정원을 줄일 수 없습니다.';

  @override
  String get authErrNotTrainer => '트레이너 계정으로 로그인해 주세요.';

  @override
  String aiBasisGoalCompletion(String goal, int rate) {
    return '$goal · 완료율 $rate% 기준';
  }

  @override
  String aiTotalAndIntensity(int total, String intensity) {
    return '총 $total분 · 강도 $intensity';
  }

  @override
  String aiBulletExercise(String name, int minutes) {
    return '· $name · $minutes분 ';
  }

  @override
  String schedHourLabel(String hour) {
    return '$hour시';
  }

  @override
  String schedMinuteLabel(String minute) {
    return '$minute분';
  }

  @override
  String get progDefaultReps => '10회';

  @override
  String get appTitleSpaced => 'On - Care 트레이너';
}
