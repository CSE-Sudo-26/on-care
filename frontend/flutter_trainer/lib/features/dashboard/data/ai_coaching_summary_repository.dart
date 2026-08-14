import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/dashboard/domain/ai_coaching_summary.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart'
    show sodiumTargetMg;

abstract interface class AiCoachingSummaryRepository {
  Future<AiCoachingSummary> fetch(DashboardSummary dashboard);
}

class DioAiCoachingSummaryRepository implements AiCoachingSummaryRepository {
  const DioAiCoachingSummaryRepository(this._dio);

  final Dio _dio;

  @override
  Future<AiCoachingSummary> fetch(DashboardSummary dashboard) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/trainer/dashboard/coaching-summary',
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Missing coaching summary.');
      }
      return AiCoachingSummary.fromJson(data);
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }
}

/// 네트워크가 없는 데모에서도 실 API와 같은 고객별 상세 계약을 보여 준다.
class DemoAiCoachingSummaryRepository implements AiCoachingSummaryRepository {
  const DemoAiCoachingSummaryRepository();

  @override
  Future<AiCoachingSummary> fetch(DashboardSummary dashboard) async {
    if (dashboard.totalClients == 0) {
      return AiCoachingSummary(
        headline: '',
        clients: const <AiCoachingClientInsight>[],
        generatedBy: 'rule',
        dataAsOf: DateTime.now(),
        kind: CoachingSummaryKind.noClients,
      );
    }
    final selected = dashboard.attention.take(3).toList(growable: false);
    final insights = selected.map(_insightFor).toList(growable: false);
    return AiCoachingSummary(
      headline: '',
      clients: insights,
      generatedBy: 'rule',
      dataAsOf: DateTime.now(),
      kind: insights.isEmpty
          ? CoachingSummaryKind.allOnTrack
          : CoachingSummaryKind.attention,
      totalClients: dashboard.totalClients,
    );
  }

  AiCoachingClientInsight _insightFor(AttentionClient entry) {
    final client = entry.client;
    final message = client.lastMessage;
    final hasKneeSignal = _hasBodyDiscomfort(message, const <String>[
      '무릎',
      '하체',
      '다리',
    ]);
    final hasUpperSignal = _hasBodyDiscomfort(message, const <String>[
      '어깨',
      '목',
      '승모',
    ]);
    final hasFatigueSignal = message.contains('야근') || message.contains('피곤');
    final recorded = client.weekCompletion.where((value) => value > 0).toList();
    final average = recorded.isEmpty
        ? null
        : (recorded.reduce((a, b) => a + b) / recorded.length).round();
    final signal = hasKneeSignal
        ? RuleCoachingSignal.knee
        : hasUpperSignal
        ? RuleCoachingSignal.upperBody
        : hasFatigueSignal
        ? RuleCoachingSignal.fatigue
        : client.sodiumOverBudget
        ? RuleCoachingSignal.sodium
        : switch (entry.primary) {
            ClientAlert.sodiumOver => RuleCoachingSignal.sodium,
            ClientAlert.lowCompletion => RuleCoachingSignal.lowCompletion,
            ClientAlert.unanswered => RuleCoachingSignal.unanswered,
          };
    return AiCoachingClientInsight(
      memberId: client.id,
      memberName: client.name,
      priority: hasKneeSignal || hasUpperSignal
          ? CoachingPriority.high
          : CoachingPriority.medium,
      statusSummary: '',
      evidence: const <String>[],
      exerciseFocus: '',
      caution: '',
      ruleData: RuleCoachingData(
        signal: signal,
        recentMessage: message.isNotEmpty && message != '아직 대화가 없어요'
            ? message
            : null,
        sodiumMg: client.sodiumOverBudget ? client.sodiumMg : null,
        sodiumTargetMg: client.sodiumOverBudget ? sodiumTargetMg : null,
        completionAverage: average,
      ),
    );
  }
}

bool _hasBodyDiscomfort(String message, List<String> bodyParts) {
  const discomfortWords = <String>['아파', '통증', '불편', '당겨', '뻐근', '시큰', '쑤셔'];
  return bodyParts.any(message.contains) &&
      discomfortWords.any(message.contains);
}

final aiCoachingSummaryRepositoryProvider =
    Provider<AiCoachingSummaryRepository>((ref) {
      if (ref.watch(appConfigProvider).useMockApi) {
        return const DemoAiCoachingSummaryRepository();
      }
      return DioAiCoachingSummaryRepository(ref.watch(dioProvider));
    });
