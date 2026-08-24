import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/portrait_date_picker.dart';
import 'package:oncare_trainer/core/utils/request_id.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_recurrence.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_repeat_preview.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/time_range_picker_dialog.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/number_stepper.dart';

/// Bottom sheet for booking or editing a session: client, type, time
/// (15-minute steps), and duration.
class SessionSheet extends ConsumerStatefulWidget {
  const SessionSheet({
    required this.clientNames,
    required this.date,
    required this.existing,
    this.inline = false,
    this.onSaved,
    this.onCancel,
    super.key,
  });

  final List<String> clientNames;

  /// The browsed calendar day new sessions are booked on (`YYYY-MM-DD`).
  final String date;

  final ScheduleSession? existing;
  final bool inline;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  @override
  ConsumerState<SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends ConsumerState<SessionSheet> {
  static const List<String> _types = SessionType.all;

  /// 고객·유형·날짜·시간 값 글씨를 한 크기로 맞춘다 — 필드마다 굵기·크기가
  /// 다르면 같은 층위의 정보가 아닌 것처럼 읽힌다.
  static const TextStyle _fieldValueStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.foreground,
  );

  late String _client;
  late String _type;
  late DateTime _date;
  late int _hour;
  late int _minute;
  late int _endHour;
  late int _endMinute;
  bool _saving = false;
  late final TextEditingController _note;

  // ---- 반복(#870) — 새 일정에서만 쓴다. 수정은 그 회차 하나의 일이다. ----

  /// 반복 요일(ISO: 월=1 … 일=7). 비어 있으면 `반복 없음`이다.
  final Set<int> _repeatDays = <int>{};

  /// 종료 기준을 횟수로 잡는가(아니면 종료일). 둘을 동시에 두지 않는 까닭은
  /// 어느 쪽이 이겼는지 화면과 서버의 해석이 갈리기 때문이다.
  bool _endsByCount = true;
  int _repeatCount = 8;
  DateTime? _repeatUntil;

  /// 저장 시도가 찾아낸 겹치는 회차. 비어 있지 않으면 아무것도 만들어지지 않았다.
  List<ScheduleSession> _conflicts = const <ScheduleSession>[];

  // Option lists always CONTAIN the edited session's own values. Falling
  // back to a default instead would silently rewrite the session on an
  // otherwise no-op save — e.g. a 상담 booked for a prospect who is not
  // on the roster would be reassigned to the first client, and a 50-minute
  // session would become 60 (review PR 218).
  late List<String> _clientOptions;
  late List<String> _typeOptions;

  /// [base] plus [current] when it isn't already offered.
  static List<T> _withCurrent<T>(List<T> base, T? current) {
    if (current == null || base.contains(current)) return List<T>.of(base);
    return <T>[...base, current];
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _note = TextEditingController(text: e?.note ?? '');

    _client = e?.clientName.isNotEmpty ?? false
        ? e!.clientName
        : widget.clientNames.first;
    _clientOptions = _withCurrent(widget.clientNames, _client);

    _type = e != null && e.type.isNotEmpty ? e.type : _types.first;
    _typeOptions = _withCurrent(_types, _type);

    _date = DateTime.parse(e?.date ?? widget.date);

    final parts = e?.time.split(':');
    _hour = parts != null ? int.tryParse(parts[0]) ?? 10 : 10;
    _minute = parts != null && parts.length > 1
        ? int.tryParse(parts[1]) ?? 0
        : 0;

    // 종료 시간은 시작 시간 + 소요 시간에서 거꾸로 구한다 — 기존 세션은
    // 소요 시간(`durationMinutes`)만 들고 있어 화면에 보일 종료 시간이
    // 저장돼 있지 않다(#1090).
    final endTotal = _hour * 60 + _minute + (e?.durationMinutes ?? 60);
    _endHour = endTotal ~/ 60;
    _endMinute = endTotal % 60;
  }

  Future<void> _pickTimeRange() async {
    final picked = await showScheduleTimeRangePicker(
      context: context,
      start: TimeOfDay(hour: _hour, minute: _minute),
      end: TimeOfDay(hour: _endHour, minute: _endMinute),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _hour = picked.start.hour;
      _minute = picked.start.minute;
      _endHour = picked.end.hour;
      _endMinute = picked.end.minute;
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _time =>
      '${_hour.toString().padLeft(2, '0')}:'
      '${_minute.toString().padLeft(2, '0')}';

  String get _endTime =>
      '${_endHour.toString().padLeft(2, '0')}:'
      '${_endMinute.toString().padLeft(2, '0')}';

  int get _startTotalMinutes => _hour * 60 + _minute;
  int get _endTotalMinutes => _endHour * 60 + _endMinute;

  /// 지금 화면이 나타내는 반복 규칙.
  WeeklyRecurrence get _rule => WeeklyRecurrence(
    weekdays: _repeatDays,
    count: _endsByCount ? _repeatCount : null,
    until: _endsByCount ? null : _repeatUntil,
  );

  /// 저장하면 만들어질 날짜들. 서버와 같은 규칙을 쓰므로(`seriesOccurrences`)
  /// 화면이 보여 준 회차 수와 실제로 만들어지는 수가 어긋나지 않는다.
  List<DateTime> get _occurrences => seriesOccurrences(_date, _rule);

  /// 반복 등록 시도 하나의 멱등키. 재시도에 같은 값을 다시 보내야 회차가 두 벌
  /// 생기지 않는다 — 시트를 여는 동안 고정한다.
  late final String _requestId = newClientRequestId();

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final int duration = _endTotalMinutes - _startTotalMinutes;
    if (duration <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.schedEndBeforeStart)));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(scheduleRepositoryProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final e = widget.existing;
      if (e == null && _repeatDays.isNotEmpty) {
        final start = _date;
        final rule = _rule;
        // 만들기 전에 충돌을 먼저 본다. 서버도 같은 검사로 409 를 주지만, 화면이
        // 겹친 회차를 짚어 주려면 목록이 필요하다(#870).
        final preview = await repo.previewRecurring(
          start: start,
          time: _time,
          rule: rule,
        );
        if (preview.conflicts.isNotEmpty) {
          if (mounted) {
            setState(() {
              _saving = false;
              _conflicts = preview.conflicts;
            });
          }
          return;
        }
        await repo.addRecurringSessions(
          start: start,
          time: _time,
          rule: rule,
          clientName: _client,
          type: _type,
          durationMinutes: duration,
          note: _note.text.trim(),
          clientRequestId: _requestId,
        );
      } else if (e == null) {
        await repo.addSession(
          date: ymd(_date),
          clientName: _client,
          time: _time,
          type: _type,
          durationMinutes: duration,
          note: _note.text.trim(),
        );
      } else {
        await repo.updateSession(
          e.id,
          clientName: _client,
          time: _time,
          type: _type,
          durationMinutes: duration,
          note: _note.text.trim(),
        );
      }
    } on ScheduleSeriesConflictError catch (error) {
      // 서버가 막은 경우(미리보기 뒤에 다른 일정이 생겼을 때)도 같은 자리에
      // 같은 목록을 보여 준다.
      if (mounted) {
        setState(() {
          _saving = false;
          _conflicts = error.conflicts;
        });
      }
      return;
    } catch (_) {
      // Surface the failure and keep the sheet open so the input isn't
      // lost (review PR 218).
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.schedSaveFailed)));
      return;
    }
    if (mounted) setState(() => _saving = false);
    if (!mounted) return;
    if (widget.inline) {
      widget.onSaved?.call();
    } else {
      navigator.pop();
    }
  }

  Future<void> _pickUntil() async {
    final start = _date;
    final picked = await showPortraitDatePicker(
      context: context,
      initialDate: _repeatUntil ?? start.add(const Duration(days: 56)),
      // 시작일 이전으로는 갈 수 없다 — 그러면 회차가 하나도 없다.
      firstDate: start,
      lastDate: start.add(const Duration(days: 7 * maxSeriesOccurrences)),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _repeatUntil = DateTime(picked.year, picked.month, picked.day),
    );
  }

  /// 새 일정의 날짜를 고른다 — 기본값은 시트를 연 시점의 선택된 날짜다.
  /// 지난 기록을 남기려는 경우도 있어(#870 반복과 달리) 과거 날짜도 막지 않는다.
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final first = _date.isBefore(todayOnly) ? _date : todayOnly;
    final picked = await showPortraitDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first.subtract(const Duration(days: 365)),
      lastDate: todayOnly.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      // 반복 요일이 시작일 하나만 켠 상태였다면 새 시작일을 따라간다 — 날짜를
      // 옮겼는데 이전 요일에 켜진 채로 남으면 미리보기가 옮긴 날을 담지 못한다.
      if (_repeatDays.length == 1) {
        _repeatDays
          ..clear()
          ..add(_date.weekday);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      decoration: widget.inline
          ? BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.all(AppRadius.lg),
              border: Border.all(color: AppColors.borderStrong),
            )
          : null,
      child: Padding(
        // Keep the sheet above the keyboard/safe area.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        // 반복 옵션이 붙으면서 시트가 낮은 창에서 넘쳤다(#870). 세로로 흐르게
        // 두어, 화면 높이가 얼마든 아래의 저장 버튼까지 닿을 수 있게 한다 —
        // 넘침은 이 저장소에서 실패로 잡는 회귀다(#849).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.existing == null ? l.schedAddTitle : l.schedEditTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // 고객·유형은 같은 층위의 선택이라 한 줄에 묶는다 — 세로로
              // 나란한 두 드롭다운이 각자 한 줄을 다 쓸 이유가 없다(#1090).
              Row(
                children: <Widget>[
                  Expanded(
                    child: _pillField(
                      label: l.schedFieldClient,
                      child: DropdownButton<String>(
                        value: _client,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: <DropdownMenuItem<String>>[
                          for (final name in _clientOptions)
                            DropdownMenuItem<String>(
                              value: name,
                              child: Text(name, style: _fieldValueStyle),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _client = v ?? _client),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _pillField(
                      label: l.schedFieldType,
                      child: DropdownButton<String>(
                        value: _type,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: <DropdownMenuItem<String>>[
                          for (final t in _typeOptions)
                            // 값은 계약값 그대로, 보이는 문구만 로케일에서
                            // 가져온다.
                            DropdownMenuItem<String>(
                              value: t,
                              child: Text(
                                sessionTypeLabel(l, t),
                                style: _fieldValueStyle,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? _type),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // 소요 시간 대신 시작·종료 시간을 직접 고른다 — 시간표에
              // 뜨는 것도, 예약 슬롯이 세션을 만들 때 넘기는 것도 결국
              // "언제부터 언제까지"라 그 형태로 바로 고르는 편이 낫다(#1090).
              // 시작·종료를 한 번에 고르는 모달을 연다(#1229, #1250).
              //
              // 날짜는 새 일정에만 고를 수 있다 — 이미 잡힌 회차의 날짜를
              // 옮기는 일은 저장소가 지원하지 않는다(수정은 그 회차의 시간·
              // 고객·유형만 바꾼다).
              if (widget.existing == null)
                Row(
                  children: <Widget>[
                    Expanded(child: _dateField(l)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _timeField(l)),
                  ],
                )
              else
                _timeField(l),
              // 반복은 새 일정에만 있다(#870). 이미 잡힌 회차를 고치는 일은 그
              // 회차 하나의 일이고, 여기서 규칙을 다시 받으면 나머지 회차까지
              // 건드리는 것처럼 읽힌다.
              if (widget.existing == null) ...<Widget>[
                _sheetField(
                  label: l.schedRepeat,
                  stacked: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // `반복 없음` 이 기본값이다 — 따로 고를 버튼을 두지 않고
                      // `매주` 하나를 껐다 켰다 하는 토글로 둔다. 켜면 남는
                      // 폭에 요일 7칸이 같은 줄로 붙는다 — 반복 요일만을 위한
                      // 새 줄·라벨을 따로 두지 않는다.
                      Row(
                        children: <Widget>[
                          _segment(
                            key: const ValueKey<String>('repeat-weekly'),
                            label: l.schedRepeatWeekly,
                            selected: _repeatDays.isNotEmpty,
                            onTap: () => setState(() {
                              if (_repeatDays.isNotEmpty) {
                                _repeatDays.clear();
                              } else {
                                // 켜는 순간의 기본값은 **시작일의 요일**이다.
                                // 빈 상태로 켜면 "매주" 를 골랐는데 아무 회차도
                                // 없는 화면이 된다.
                                _repeatDays.add(_date.weekday);
                              }
                            }),
                          ),
                          if (_repeatDays.isNotEmpty) ...<Widget>[
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  for (
                                    var day = 1;
                                    day <= 7;
                                    day++
                                  ) ...<Widget>[
                                    if (day != 1)
                                      const SizedBox(width: AppSpacing.xxs),
                                    Expanded(
                                      child: _segment(
                                        key: ValueKey<String>(
                                          'repeat-day-$day',
                                        ),
                                        label: weekdayNames(l)[day - 1],
                                        selected: _repeatDays.contains(day),
                                        dense: true,
                                        onTap: () => setState(() {
                                          if (_repeatDays.contains(day)) {
                                            if (_repeatDays.length > 1) {
                                              // 마지막 요일까지 끄면 `매주` 인데
                                              // 회차가 없는 상태가 된다 — 끄려면
                                              // `매주` 를 다시 눌러 반복 자체를
                                              // 끈다.
                                              _repeatDays.remove(day);
                                            }
                                          } else {
                                            _repeatDays.add(day);
                                          }
                                        }),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_repeatDays.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        // `종료` 는 실제로는 횟수·종료일 중 하나를 고르는
                        // 드롭다운이다 — 고객 탭 `성별` 필드와 같은, 앱 전역
                        // 테두리 있는 선택 UI로 통일한다.
                        DropdownButtonFormField<bool>(
                          key: const ValueKey<String>('repeat-end-mode'),
                          initialValue: _endsByCount,
                          decoration: InputDecoration(
                            labelText: l.schedRepeatEnd,
                            isDense: true,
                          ),
                          items: <DropdownMenuItem<bool>>[
                            DropdownMenuItem<bool>(
                              value: true,
                              child: Text(l.schedRepeatEndByCount),
                            ),
                            DropdownMenuItem<bool>(
                              value: false,
                              child: Text(l.schedRepeatEndByDate),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _endsByCount = v ?? _endsByCount;
                            if (!_endsByCount) {
                              _repeatUntil ??= _date.add(
                                const Duration(days: 56),
                              );
                            }
                          }),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // 횟수는 프리셋 목록 대신 숫자 키보드로 바로 입력한다.
                        // 종료일은 필드를 누르면 바로 날짜 선택기가 뜬다.
                        if (_endsByCount)
                          NumberStepper(
                            key: const ValueKey<String>('repeat-count'),
                            value: _repeatCount.toDouble(),
                            min: 1,
                            max: maxSeriesOccurrences.toDouble(),
                            suffix: l.schedRepeatCountUnit,
                            onChanged: (v) =>
                                setState(() => _repeatCount = v.round()),
                          )
                        else
                          GestureDetector(
                            key: const ValueKey<String>('repeat-until'),
                            onTap: _pickUntil,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.inputBackground,
                                borderRadius: BorderRadius.all(AppRadius.sm),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      _repeatUntil == null
                                          ? '-'
                                          : ymd(_repeatUntil!),
                                      style: _fieldValueStyle,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.event_outlined,
                                    size: 18,
                                    color: AppColors.subtleForeground,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        // 저장 전에 회차를 보여 준다 — 잘못 고른 요일을 되돌리는
                        // 비용은 한 건씩 지우는 일이다.
                        SessionRepeatPreview(dates: _occurrences),
                        if (_conflicts.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          SessionRepeatConflicts(
                            total: _occurrences.length,
                            conflicts: _conflicts,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
              if (widget.existing == null)
                _sheetField(
                  label: l.schedNote,
                  stacked: true,
                  child: TextField(
                    key: const ValueKey<String>('schedule-trainer-note'),
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l.schedNoteHint,
                      // 테마 기본 힌트 크기가 옆 `메모` 라벨(13)보다 커서 이
                      // 시트에서만 튀어 보였다 — 그 크기에 맞춘다(#1247).
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  if (widget.inline) ...<Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _saving ? null : widget.onCancel,
                          child: Text(l.actionCancel),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.all(AppRadius.lg),
                      child: InkWell(
                        onTap: _saving ? null : _save,
                        borderRadius: const BorderRadius.all(AppRadius.lg),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          child: Text(
                            widget.existing == null
                                ? l.schedAddAction
                                : l.schedSaveAction,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 시작·종료 시간 필드 — 눌러서 한 번에 고르는 모달을 연다(#1229, #1250).
  Widget _timeField(AppLocalizations l) {
    return GestureDetector(
      key: const ValueKey<String>('session-time-range-field'),
      onTap: _pickTimeRange,
      child: _pillField(
        label: l.schedFieldTime,
        child: SizedBox(
          height: 44,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.schedTimeRange(_time, _endTime),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const Icon(
                Icons.schedule_outlined,
                size: 18,
                color: AppColors.subtleForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 새 일정의 날짜 필드 — 기본값은 시트를 연 시점의 선택된 날짜이고, 눌러서
  /// 다른 날짜로 바꿀 수 있다.
  Widget _dateField(AppLocalizations l) {
    return GestureDetector(
      key: const ValueKey<String>('session-date-field'),
      onTap: _pickDate,
      child: _pillField(
        label: l.schedFieldDate,
        child: SizedBox(
          height: 44,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.dateMonthDayWeekday(
                    _date.month,
                    _date.day,
                    weekdayNames(l)[_date.weekday - 1],
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.subtleForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField({
    required String label,
    required Widget child,
    bool stacked = false,
  }) {
    const labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.subtleForeground,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: labelStyle),
                const SizedBox(height: AppSpacing.xs),
                child,
              ],
            )
          : Row(
              children: <Widget>[
                SizedBox(width: 88, child: Text(label, style: labelStyle)),
                Expanded(child: child),
              ],
            ),
    );
  }

  /// 위에 작은 라벨, 아래 옅은 채움(inputBackground) 카드 — 예약 슬롯
  /// 시트가 쓰는 것과 같은 언어다(#1090). 짙은 `OutlinedButton` 윤곽선
  /// 대신 이 카드로 통일해, 한 시트 안에서 필드마다 다른 무게로 서던
  /// 것을 정리한다.
  Widget _pillField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: const BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.all(AppRadius.sm),
          ),
          child: child,
        ),
      ],
    );
  }

  /// 테두리 없는 필 모양 토글 — 채움색으로만 선택 상태를 말한다. 다른 화면의
  /// 칩(메시지 필터 등)과 같은 언어다. Material 기본 `ChoiceChip`/`FilterChip`
  /// 은 옅은 회색 대신 짙은 윤곽선을 그려 이 앱 다른 곳과 튀었다.
  Widget _segment({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool dense = false,
  }) {
    return Material(
      key: key,
      color: selected ? AppColors.accentSurface : AppColors.inputBackground,
      borderRadius: const BorderRadius.all(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? AppSpacing.xxs : AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: dense ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
