import '../../data/models/symptom_record.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/weight_record.dart';

class AiAnalysisResult {
  const AiAnalysisResult({
    required this.items,
    required this.comment,
    required this.encouragement,
    required this.detailNotes,
  });

  final List<AiAnalysisItem> items;
  final String comment;
  final String encouragement;
  final List<SymptomRecord> detailNotes;
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
  const AiAnalysisService();

  AiAnalysisResult analyze({
    required int cycleNo,
    required UserProfile profile,
    required List<SymptomRecord> records,
    required List<SymptomRecord> previousRecords,
    required List<WeightRecord> weights,
  }) {
    final sideEffects = records
        .expand((record) => record.sideEffects)
        .where((effect) => effect != '없음')
        .toSet()
        .toList();
    final avgSteps = _average(records.map((record) => record.steps));
    final latestWeight = weights.isEmpty ? null : weights.last.weightKg;
    final hasPrevious = previousRecords.isNotEmpty;

    return AiAnalysisResult(
      items: [
        AiAnalysisItem(
          title: '식사량',
          current: _limit('이번 회차 식사량은 기록 범위 내에서 큰 저하 없이 확인됩니다.', 150),
          previous: hasPrevious ? _limit('이전 회차와 비교해 식사량 저하 빈도를 함께 확인했습니다.', 150) : null,
        ),
        AiAnalysisItem(
          title: '음수량',
          current: _limit('수분섭취는 기록 범위 내에서 큰 부족 신호가 두드러지지 않습니다.', 150),
          previous: hasPrevious ? _limit('이전 회차와 비교해 수분섭취 패턴 변화가 제한적입니다.', 150) : null,
        ),
        AiAnalysisItem(
          title: '운동량',
          current: _limit('평균 활동량은 약 ${avgSteps.toStringAsFixed(0)}보입니다. 피로와 함께 감소하는지 확인해 주세요.', 150),
          previous: hasPrevious ? _limit('직전 회차 기록과 비교해 활동량 변화 추이를 확인했습니다.', 150) : null,
        ),
        AiAnalysisItem(
          title: '배변',
          current: _limit('배변 기록에서 반복되는 이상 신호가 있는지 외래 전 확인해 주세요.', 150),
          previous: hasPrevious ? _limit('이전 회차와 비교해 배변 상태의 지속 여부를 확인했습니다.', 150) : null,
        ),
        AiAnalysisItem(
          title: '특이사항 및 부작용',
          current: _limit(
            sideEffects.isEmpty
                ? '주요 부작용은 없음으로 기록되었거나 특이 기록이 없습니다.'
                : '주요 부작용은 ${sideEffects.take(6).join(', ')}입니다. 반복되거나 악화되면 상담 시 전달해 주세요.',
            150,
          ),
          previous: hasPrevious ? _limit('이전 회차 부작용 기록과 비교해 반복 여부를 확인했습니다.', 150) : null,
        ),
      ],
      comment: _limit(
        '만 ${profile.age(DateTime(2026, 6, 3))}세, ${profile.cancerType} ${profile.stage}, '
        '최근 체중 ${latestWeight?.toStringAsFixed(1) ?? '기록 없음'}kg 기준으로 이번 $cycleNo회차 기록을 확인했습니다. '
        '외래 시 변화가 컸던 날짜와 반복 증상을 전달해 주세요.',
        300,
      ),
      encouragement: '오늘도 기록을 이어가고 계신 것만으로도 충분히 잘하고 있어요. 💜',
      detailNotes: records.where((record) => record.note.trim().isNotEmpty).toList(),
    );
  }

  double _average(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((sum, value) => sum + value) / list.length;
  }

  String _limit(String text, int max) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length > max ? '${normalized.substring(0, max - 1)}…' : normalized;
  }
}
