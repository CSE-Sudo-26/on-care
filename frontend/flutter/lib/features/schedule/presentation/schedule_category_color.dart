import 'package:flutter/material.dart';

import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// Single source of truth: schedule category → calendar color. Every event
/// of the same category renders in the same color, regardless of whatever
/// `color_hex` the row happens to carry.
Color scheduleCategoryColor(ScheduleCategory c) => switch (c) {
  ScheduleCategory.hospital => const Color(0xFFDBEAFE), // blue
  ScheduleCategory.exercise => const Color(0xFFDCFCE7), // green
  ScheduleCategory.meal => const Color(0xFFFFEDD5), // orange
  ScheduleCategory.medication => const Color(0xFFEDE9FE), // purple
  ScheduleCategory.other => const Color(0xFFE0F2F7), // accent
};

/// Single source of truth: schedule category → 화면에 그릴 이름.
///
/// enum 값 자체는 서버로 나가는 계약이라 번역하지 않는다. 사람이 읽는 이름만
/// 여기서 로케일을 따른다(#847).
String scheduleCategoryLabel(AppLocalizations l, ScheduleCategory c) =>
    switch (c) {
      ScheduleCategory.hospital => l.scheduleCategoryHospital,
      ScheduleCategory.exercise => l.scheduleCategoryExercise,
      ScheduleCategory.meal => l.scheduleCategoryMeal,
      ScheduleCategory.medication => l.scheduleCategoryMedication,
      ScheduleCategory.other => l.scheduleCategoryOther,
    };
