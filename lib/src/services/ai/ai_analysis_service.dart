import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

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

enum AiAnalysisSource { claude }

class AiAnalysisException implements Exception {
  const AiAnalysisException({
    required this.title,
    required this.message,
    required this.code,
  });

  final String title;
  final String message;
  final String code;

  @override
  String toString() => '$title: $message ($code)';
}

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
          .call(
            _toPayload(
              cycleNo: cycleNo,
              profile: profile,
              records: records,
              previousRecords: previousRecords,
              weights: weights,
            ),
          )
          .timeout(const Duration(seconds: 45));
      return _fromRemoteResponse(_normalizeRemoteMap(response.data), records);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('AI analysis remote call failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      throw _remoteFailure(error);
    }
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
              'diagnosisDate': _dateString(profile.diagnosisDate),
              'metastasis': profile.metastasis,
              'treatmentType': profile.treatmentType,
              'treatmentStartDate': _dateString(profile.treatmentStartDate),
              'heightCm': profile.heightCm,
              'extra': profile.extra,
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
            current: _limit('${item['current'] ?? ''}', 250),
            previous: item['previous'] == null || '${item['previous']}'.isEmpty
                ? null
                : _limit('${item['previous']}', 250),
          ),
        )
        .where((item) => item.title.isNotEmpty && item.current.isNotEmpty)
        .toList();

    if (items.isEmpty) {
      throw const FormatException('Remote analysis result has no items.');
    }

    return AiAnalysisResult(
      items: items,
      comment: _limit('${data['comment'] ?? ''}', 500),
      encouragement: '${data['encouragement'] ?? ''}'.trim().isEmpty
          ? '오늘도 기록을 이어가고 계신 것만으로도 충분히 잘하고 있어요. 💜'
          : _limit('${data['encouragement']}', 120),
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

  AiAnalysisException _remoteFailure(Object error) {
    if (error is FirebaseFunctionsException) {
      return AiAnalysisException(
        title: 'AI 분석을 완료하지 못했어요',
        message: _functionsFailureMessage(error.code),
        code: 'functions/${error.code}',
      );
    }
    if (error is TimeoutException) {
      return const AiAnalysisException(
        title: 'AI 분석 응답이 지연되고 있어요',
        message: '네트워크 상태를 확인한 뒤 잠시 후 다시 시도해 주세요.',
        code: 'timeout',
      );
    }
    if (error is FormatException) {
      return const AiAnalysisException(
        title: 'AI 분석 결과를 읽지 못했어요',
        message: '분석 응답 형식이 올바르지 않습니다. 다시 시도해 주세요.',
        code: 'invalid-response',
      );
    }
    return const AiAnalysisException(
      title: 'AI 분석을 완료하지 못했어요',
      message: '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
      code: 'unknown',
    );
  }

  String _functionsFailureMessage(String code) {
    switch (code) {
      case 'unauthenticated':
        return '로그인 상태를 확인한 뒤 다시 시도해 주세요.';
      case 'permission-denied':
        return 'AI 분석을 사용할 권한을 확인하지 못했습니다.';
      case 'deadline-exceeded':
        return '분석 요청 시간이 길어지고 있습니다. 잠시 후 다시 시도해 주세요.';
      case 'failed-precondition':
        return '분석에 필요한 기록을 확인한 뒤 다시 시도해 주세요.';
      case 'unavailable':
        return 'AI 분석 서버에 잠시 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.';
      case 'internal':
        return 'AI 분석 서버에서 응답을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      default:
        return 'AI 분석 요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }

  Map<String, dynamic> _normalizeRemoteMap(Object? value) {
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(
          key.toString(),
          _normalizeRemoteValue(mapValue),
        ),
      );
    }
    throw const FormatException('Remote analysis result is not a map.');
  }

  Object? _normalizeRemoteValue(Object? value) {
    if (value is Map) return _normalizeRemoteMap(value);
    if (value is List) return value.map(_normalizeRemoteValue).toList();
    return value;
  }
}
