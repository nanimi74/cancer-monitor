import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../data/models/symptom_record.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/weight_record.dart';

class AiAnalysisResult {
  const AiAnalysisResult({
    required this.items,
    required this.comment,
    required this.encouragement,
    required this.detailNotes,
    required this.source,
  });

  final List<AiAnalysisItem> items;
  final String comment;
  final String encouragement;
  final List<SymptomRecord> detailNotes;
  final AiAnalysisSource source;
}

enum AiAnalysisSource { claude, localFallback }

class AiAnalysisItem {
  const AiAnalysisItem({
    required this.title,
    required this.current,
    this.previous,
  });

  final String title;
  final String current;
  final String? previous;
}

class AiAnalysisService {
  const AiAnalysisService({FirebaseFunctions? functions})
      : _functions = functions;

  final FirebaseFunctions? _functions;

  Future<AiAnalysisResult> analyze({
    required int cycleNo,
    UserProfile? profile,
    required List<SymptomRecord> records,
    required List<SymptomRecord> previousRecords,
    required List<WeightRecord> weights,
  }) async {
    try {
      final callable = (_functions ??
              FirebaseFunctions.instanceFor(region: 'asia-northeast3'))
          .httpsCallable('analyzeCycle');
      final response = await callable
          .call<Map<String, dynamic>>(
            _toPayload(
              cycleNo: cycleNo,
              profile: profile,
              records: records,
              previousRecords: previousRecords,
              weights: weights,
            ),
          )
          .timeout(const Duration(seconds: 45));
      return _fromRemoteResponse(response.data, records);
    } catch (_) {
      return _analyzeLocally(
        cycleNo: cycleNo,
        profile: profile,
        records: records,
        previousRecords: previousRecords,
        weights: weights,
      );
    }
  }

  AiAnalysisResult _analyzeLocally({
    required int cycleNo,
    UserProfile? profile,
    required List<SymptomRecord> records,
    required List<SymptomRecord> previousRecords,
    required List<WeightRecord> weights,
  }) {
    final sideEffects = records
        .expand((record) => record.sideEffects)
        .where((effect) => effect != '없음')
        .toSet()
        .toList();
    final lowMealCount = records
        .where((record) =>
            record.mealAmount == '평소의 절반' ||
            record.mealAmount == '평소의 1/4' ||
            record.mealAmount == '전혀 못 먹음')
        .length;
    final lowWaterCount =
        records.where((record) => record.waterAmount == '500ml 이하').length;
    final bowelIssues = records
        .where((record) =>
            record.bowel == '없음' ||
            (record.stoolStatus.isNotEmpty && record.stoolStatus != '정상'))
        .length;
    final avgSteps = _average(records.map((record) => record.steps));
    final latestWeight = weights.isEmpty ? null : weights.last.weightKg;
    final hasPrevious = previousRecords.isNotEmpty;
    final profileText = profile == null
        ? '이번 회차 기록'
        : '만 ${profile.age(DateTime.now())}세, ${profile.cancerType} ${profile.stage}, 최근 체중 ${latestWeight?.toStringAsFixed(1) ?? '기록 없음'}kg';

    return AiAnalysisResult(
      items: [
        AiAnalysisItem(
          title: '식사량',
          current: _limit(
            lowMealCount == 0
                ? '이번 회차 식사량은 큰 저하 없이 기록되었습니다. 기타 식사와 섭취 다양성도 함께 확인해 주세요.'
                : '이번 회차에 식사량 저하 기록이 $lowMealCount일 확인됩니다. 저하가 반복되면 외래 시 전달해 주세요.',
            150,
          ),
          previous: hasPrevious
              ? _limit('직전 회차와 비교해 식사량 저하 빈도와 회복 흐름을 함께 확인했습니다.', 150)
              : null,
        ),
        AiAnalysisItem(
          title: '음수량',
          current: _limit(
            lowWaterCount == 0
                ? '수분섭취는 기록 범위 내에서 큰 부족 신호가 두드러지지 않습니다.'
                : '500ml 이하 수분섭취가 $lowWaterCount일 기록되었습니다. 설사나 발열이 동반되면 상담 시 공유해 주세요.',
            150,
          ),
          previous: hasPrevious
              ? _limit('직전 회차와 비교해 수분섭취 부족 기록의 반복 여부를 확인했습니다.', 150)
              : null,
        ),
        AiAnalysisItem(
          title: '운동량',
          current: _limit(
              '평균 활동량은 약 ${avgSteps.toStringAsFixed(0)}보입니다. 피로와 함께 감소하는지 확인해 주세요.',
              150),
          previous: hasPrevious
              ? _limit('직전 회차 기록과 비교해 활동량 변화 추이를 확인했습니다.', 150)
              : null,
        ),
        AiAnalysisItem(
          title: '배변',
          current: _limit(
            bowelIssues == 0
                ? '배변 기록에서 뚜렷한 이상 신호는 확인되지 않습니다.'
                : '배변 없음 또는 변 상태 변화가 $bowelIssues일 기록되었습니다. 지속되면 상담 시 전달해 주세요.',
            150,
          ),
          previous: hasPrevious
              ? _limit('직전 회차와 비교해 배변 상태 변화의 지속 여부를 확인했습니다.', 150)
              : null,
        ),
        AiAnalysisItem(
          title: '특이사항 및 부작용',
          current: _limit(
            sideEffects.isEmpty
                ? '주요 부작용은 없음으로 기록되었거나 특이 기록이 없습니다.'
                : '주요 부작용은 ${sideEffects.take(6).join(', ')}입니다. 반복되거나 악화되면 상담 시 전달해 주세요.',
            150,
          ),
          previous: hasPrevious
              ? _limit('이전 회차 부작용 기록과 비교해 반복 여부를 확인했습니다.', 150)
              : null,
        ),
      ],
      comment: _limit(
        '$profileText 기준으로 이번 $cycleNo회차 기록을 확인했습니다. '
        '외래 시 변화가 컸던 날짜와 반복 증상을 전달해 주세요.',
        300,
      ),
      encouragement: '오늘도 기록을 이어가고 계신 것만으로도 충분히 잘하고 있어요. 💜',
      detailNotes:
          records.where((record) => record.note.trim().isNotEmpty).toList(),
      source: AiAnalysisSource.localFallback,
    );
  }

  double _average(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((sum, value) => sum + value) / list.length;
  }

  String _limit(String text, int max) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length > max
        ? '${normalized.substring(0, max - 1)}…'
        : normalized;
  }

  Map<String, dynamic> _toPayload({
    required int cycleNo,
    UserProfile? profile,
    required List<SymptomRecord> records,
    required List<SymptomRecord> previousRecords,
    required List<WeightRecord> weights,
  }) {
    return {
      'cycleNo': cycleNo,
      'profile': profile == null
          ? null
          : {
              'sex': profile.sex,
              'age': profile.age(DateTime.now()),
              'cancerType': profile.cancerType,
              'stage': profile.stage,
              'heightCm': profile.heightCm,
            },
      'weights': weights
          .map(
            (weight) => {
              'date': _dateString(weight.date),
              'weightKg': weight.weightKg,
            },
          )
          .toList(),
      'records': records.map(_recordToPayload).toList(),
      'previousRecords': previousRecords.map(_recordToPayload).toList(),
    };
  }

  Map<String, dynamic> _recordToPayload(SymptomRecord record) {
    return {
      'date': _dateString(record.date),
      'cycleNo': record.cycleNo,
      'cycleDay': record.cycleDay,
      'mealAmount': record.mealAmount,
      'breakfastMemo': record.breakfastMemo,
      'lunchMemo': record.lunchMemo,
      'dinnerMemo': record.dinnerMemo,
      'extraMealMemo': record.extraMealMemo,
      'waterAmount': record.waterAmount,
      'steps': record.steps,
      'stepsSource': record.stepsSource,
      'bowel': record.bowel,
      'stoolStatus': record.stoolStatus,
      'sideEffects': record.sideEffects,
      'note': record.note,
    };
  }

  AiAnalysisResult _fromRemoteResponse(
    Map<String, dynamic> data,
    List<SymptomRecord> records,
  ) {
    final rawItems = (data['items'] as List<dynamic>? ?? const []);
    final items = rawItems
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (item) => AiAnalysisItem(
            title: '${item['title'] ?? ''}',
            current: _limit('${item['current'] ?? ''}', 150),
            previous: item['previous'] == null || '${item['previous']}'.isEmpty
                ? null
                : _limit('${item['previous']}', 150),
          ),
        )
        .where((item) => item.title.isNotEmpty && item.current.isNotEmpty)
        .toList();

    if (items.isEmpty) {
      throw const FormatException('Remote analysis result has no items.');
    }

    return AiAnalysisResult(
      items: items,
      comment: _limit('${data['comment'] ?? ''}', 300),
      encouragement: '${data['encouragement'] ?? ''}'.trim().isEmpty
          ? '오늘도 기록을 이어가고 계신 것만으로도 충분히 잘하고 있어요. 💜'
          : '${data['encouragement']}',
      detailNotes:
          records.where((record) => record.note.trim().isNotEmpty).toList(),
      source: AiAnalysisSource.claude,
    );
  }

  String _dateString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
