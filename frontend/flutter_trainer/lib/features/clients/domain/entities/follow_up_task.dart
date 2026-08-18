import 'package:oncare_trainer/core/utils/date_format.dart';

/// 할 일이 가리키는 업무 갈래 — 눌렀을 때 어디로 갈지를 정한다.
///
/// 새 deep-link 체계가 아니라 **기존 route 를 고르는 값**이다. 서버도 같은 목록을
/// CHECK 제약으로 못 박고 있으므로(`ck_trainer_follow_up_task_context`) 여기서
/// 늘릴 때는 백엔드와 함께 늘린다.
enum FollowUpContext {
  /// 특정 화면이 없는 일반 후속 관리. 고객 상세 기본 화면으로 간다.
  general,
  diet,
  exercise,
  message,
  program,
  schedule;

  /// 서버 계약값(`context_type`).
  String get wire => name;

  /// 앱이 모르는 값은 [general] 로 떨어뜨린다 — 이동할 곳이 없다고 목록 전체를
  /// 실패시키는 것보다, 고객 상세로라도 보내는 편이 낫다.
  static FollowUpContext fromWire(String? value) =>
      FollowUpContext.values.firstWhere(
        (context) => context.wire == value,
        orElse: () => FollowUpContext.general,
      );
}

/// 후속 관리 할 일의 상태. 완료는 되돌리지 않으므로 두 값이면 충분하다.
enum FollowUpStatus {
  pending,
  completed;

  String get wire => name;

  static FollowUpStatus fromWire(String? value) =>
      value == 'completed' ? FollowUpStatus.completed : FollowUpStatus.pending;
}

/// 트레이너가 한 고객에 대해 남긴 후속 관리 할 일. 회원에게는 보이지 않는다.
///
/// 메모([TrainerMemo])와 나누는 까닭은 답하는 질문이 다르기 때문이다 — 메모는
/// "이 고객에 대해 무엇을 알아 두었나", 할 일은 "언제까지 무엇을 해야 하나"다.
class FollowUpTask {
  const FollowUpTask({
    required this.id,
    required this.memberId,
    required this.title,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.memberName = '',
    this.status = FollowUpStatus.pending,
    this.context = FollowUpContext.general,
    this.completedAt,
  });

  final String id;
  final String memberId;

  /// 대시보드가 "누구의 할 일인가"를 함께 보여 준다. 서버가 채워 주므로 화면이
  /// 할 일마다 고객을 다시 조회하지 않는다.
  final String memberName;

  final String title;

  /// 확인 예정일. **날짜만** 의미가 있어 시각은 0시로 자른다 —
  /// `dueDate.isBefore(todayKst())` 같은 비교가 시각 때문에 어긋나지 않는다.
  final DateTime dueDate;

  final FollowUpStatus status;
  final FollowUpContext context;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 완료 처리 시각. 미완료는 null 이라 상태와 시각이 어긋날 수 없다.
  final DateTime? completedAt;

  bool get isCompleted => status == FollowUpStatus.completed;

  /// 예정일이 [today] 보다 이전인가 — 기한이 지난 항목.
  ///
  /// 지난 항목을 화면에서 따로 세우기 위한 값이다. 놓치지 않으려고 만든 기능이
  /// 하루 지났다고 조용해지면 안 된다.
  bool isOverdue(DateTime today) => dueDate.isBefore(_dateOnly(today));

  factory FollowUpTask.fromJson(Map<String, Object?> json) => FollowUpTask(
    id: json['id']! as String,
    memberId: json['member_id']! as String,
    memberName: json['member_name'] as String? ?? '',
    title: json['title'] as String? ?? '',
    dueDate: parseDueDate(json['due_date']! as String),
    status: FollowUpStatus.fromWire(json['status'] as String?),
    context: FollowUpContext.fromWire(json['context_type'] as String?),
    createdAt: DateTime.parse(json['created_at']! as String),
    updatedAt: DateTime.parse(
      json['updated_at'] as String? ?? json['created_at']! as String,
    ),
    completedAt: switch (json['completed_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'member_id': memberId,
    'member_name': memberName,
    'title': title,
    'due_date': ymd(dueDate),
    'status': status.wire,
    'context_type': context.wire,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  FollowUpTask copyWith({
    String? title,
    DateTime? dueDate,
    FollowUpStatus? status,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) => FollowUpTask(
    id: id,
    memberId: memberId,
    memberName: memberName,
    title: title ?? this.title,
    dueDate: dueDate ?? this.dueDate,
    status: status ?? this.status,
    context: context,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt ?? this.completedAt,
  );
}

/// `YYYY-MM-DD` → 날짜만 담은 [DateTime]. 서버의 `due_date` 표기와 짝이다.
DateTime parseDueDate(String value) => _dateOnly(DateTime.parse(value));

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
