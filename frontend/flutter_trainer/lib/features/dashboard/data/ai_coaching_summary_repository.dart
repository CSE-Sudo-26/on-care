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
        headline: '담당 고객이 등록되면 식단·운동·대화 기록을 바탕으로 오늘의 코칭 포인트를 정리합니다.',
        clients: const <AiCoachingClientInsight>[],
        generatedBy: 'rule',
        dataAsOf: DateTime.now(),
        kind: CoachingSummaryKind.noClients,
      );
    }
    final selected = dashboard.attention.take(3).toList(growable: false);
    final insights = selected.map(_insightFor).toList(growable: false);
    return AiCoachingSummary(
      headline: insights.isEmpty
          ? '오늘은 모든 고객의 기록이 목표 범위 안에 있어 현재 강도를 유지해도 좋습니다.'
          : '오늘은 ${insights.first.memberName} 고객을 먼저 확인하고, 식단·컨디션 신호에 맞춰 운동 부하를 조절하세요.',
      clients: insights,
      generatedBy: 'rule',
      dataAsOf: DateTime.now(),
      kind: insights.isEmpty
          ? CoachingSummaryKind.allOnTrack
          : CoachingSummaryKind.details,
      totalClients: dashboard.totalClients,
    );
  }

  AiCoachingClientInsight _insightFor(AttentionClient entry) {
    final client = entry.client;
    final message = client.lastMessage;
    final hasKneeSignal = message.contains('무릎') || message.contains('하체');
    final hasUpperSignal = message.contains('어깨') || message.contains('목');
    final hasFatigueSignal = message.contains('야근') || message.contains('피곤');
    final evidence = <String>[];
    if (message.isNotEmpty && message != '아직 대화가 없어요') {
      evidence.add('최근 대화: “$message”');
    }
    if (client.sodiumOverBudget) {
      evidence.add('오늘 나트륨 ${client.sodiumMg}mg / 기준 ${sodiumTargetMg}mg');
    }
    final recorded = client.weekCompletion.where((value) => value > 0).toList();
    if (recorded.isNotEmpty) {
      final average = (recorded.reduce((a, b) => a + b) / recorded.length)
          .round();
      evidence.add('이번 주 기록일 평균 이행률 $average%');
    }

    late final String status;
    late final String focus;
    late final String caution;
    if (hasKneeSignal) {
      status = '${client.name} 고객의 최근 대화에서 무릎·하체 불편 신호가 확인돼 하체 부하 조절이 필요합니다.';
      focus = '스쿼트·런지 고중량은 줄이고 둔근 활성화, 무릎 가동성, 평지 걷기 중심으로 구성하세요.';
      caution = '세션 전 통증 위치와 가동 범위를 다시 확인하세요.';
    } else if (hasUpperSignal) {
      status = '${client.name} 고객이 어깨·목 불편을 언급해 상체 밀기·당기기 강도를 조절해야 합니다.';
      focus = '상체 고중량은 줄이고 흉추 가동성, 견갑 안정화, 상체 스트레칭 중심으로 구성하세요.';
      caution = '팔을 들 때 불편한 각도를 먼저 확인하세요.';
    } else if (hasFatigueSignal) {
      status = '${client.name} 고객이 야근·피로로 운동 지속에 어려움을 보여 완수 가능한 강도가 우선입니다.';
      focus = '고강도 전신 운동은 줄이고 15~20분 저강도 유산소와 회복 스트레칭 중심으로 구성하세요.';
      caution = '수면과 현재 피로도를 확인한 뒤 강도를 확정하세요.';
    } else if (client.sodiumOverBudget) {
      status = '${client.name} 고객의 오늘 나트륨 섭취가 기준을 넘어 당일 컨디션을 반영한 강도 설정이 필요합니다.';
      focus = '고강도 인터벌보다 중강도 걷기·사이클과 안정적인 전신 근력 볼륨 중심으로 구성하세요.';
      caution = '수분 섭취와 어지럼·부종 여부를 확인하세요.';
    } else {
      status = '${client.name} 고객의 주간 운동 이행률이 낮아 짧게 완수할 수 있는 구성이 필요합니다.';
      focus = '복합 동작 수를 줄이고 20분 전신 서킷과 마무리 스트레칭 중심으로 구성하세요.';
      caution = '이번 주 운동을 방해한 일정·컨디션을 먼저 확인하세요.';
    }
    return AiCoachingClientInsight(
      memberId: client.id,
      memberName: client.name,
      priority: hasKneeSignal || hasUpperSignal
          ? CoachingPriority.high
          : CoachingPriority.medium,
      statusSummary: status,
      evidence: evidence.take(3).toList(growable: false),
      exerciseFocus: focus,
      caution: caution,
    );
  }
}

final aiCoachingSummaryRepositoryProvider =
    Provider<AiCoachingSummaryRepository>((ref) {
      if (ref.watch(appConfigProvider).useMockApi) {
        return const DemoAiCoachingSummaryRepository();
      }
      return DioAiCoachingSummaryRepository(ref.watch(dioProvider));
    });
