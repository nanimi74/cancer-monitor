import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/symptom_record.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/weight_record.dart';
import '../../services/ai/ai_analysis_service.dart';

enum _AnalysisStatus { idle, loading, complete }

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    this.hasRequiredInfo = true,
    this.isPreview = false,
    this.profile,
    this.records = const [],
    this.weights = const [],
  });

  final bool hasRequiredInfo;
  final bool isPreview;
  final UserProfile? profile;
  final List<SymptomRecord> records;
  final List<WeightRecord> weights;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int? _selectedCycleNo;
  _AnalysisStatus _status = _AnalysisStatus.idle;
  AiAnalysisResult? _result;
  var _detailsExpanded = false;

  Map<int, List<SymptomRecord>> get _recordsByCycle {
    final grouped = <int, List<SymptomRecord>>{};
    for (final record in widget.records) {
      grouped.putIfAbsent(record.cycleNo, () => []).add(record);
    }
    for (final records in grouped.values) {
      records.sort((a, b) => a.date.compareTo(b.date));
    }
    return grouped;
  }

  @override
  void didUpdateWidget(covariant AnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records != widget.records ||
        oldWidget.profile != widget.profile ||
        oldWidget.weights != widget.weights ||
        oldWidget.hasRequiredInfo != widget.hasRequiredInfo) {
      final cycles = _recordsByCycle.keys.toSet();
      if (_selectedCycleNo != null && !cycles.contains(_selectedCycleNo)) {
        _selectedCycleNo = null;
      }
      _status = _AnalysisStatus.idle;
      _result = null;
      _detailsExpanded = false;
    }
  }

  Future<void> _runAnalysis(int selectedCycleNo) async {
    if (!widget.hasRequiredInfo || widget.isPreview) {
      return;
    }

    setState(() {
      _status = _AnalysisStatus.loading;
      _result = null;
      _detailsExpanded = false;
    });

    final grouped = _recordsByCycle;
    final records = grouped[selectedCycleNo] ?? const <SymptomRecord>[];
    final previousRecords = selectedCycleNo <= 1
        ? const <SymptomRecord>[]
        : grouped[selectedCycleNo - 1] ?? const <SymptomRecord>[];
    AiAnalysisResult result;
    try {
      result = await const AiAnalysisService().analyze(
        cycleNo: selectedCycleNo,
        profile: widget.profile,
        records: records,
        previousRecords: previousRecords,
        weights: widget.weights,
      );
    } on AiAnalysisException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _AnalysisStatus.idle;
        _result = null;
      });
      await _showAnalysisErrorDialog(error);
      return;
    }

    if (!mounted) return;

    setState(() {
      _result = result;
      _status = _AnalysisStatus.complete;
    });
  }

  Future<void> _showAnalysisErrorDialog(AiAnalysisException error) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          error.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.message,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentLine),
              ),
              child: Text(
                '오류 코드: ${error.code}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '확인',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCycle(
    List<int> cycleNos,
    Map<int, List<SymptomRecord>> grouped,
    int? selectedCycleNo,
  ) async {
    if (!widget.hasRequiredInfo || widget.isPreview || cycleNos.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CyclePickerSheet(
        cycleNos: cycleNos,
        grouped: grouped,
        selectedCycleNo: selectedCycleNo,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedCycleNo = selected;
      _status = _AnalysisStatus.idle;
      _result = null;
      _detailsExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _recordsByCycle;
    final cycleNos = grouped.keys.toList()..sort();
    final selectedCycleNo =
        _selectedCycleNo ?? (cycleNos.isEmpty ? null : cycleNos.first);
    final canAnalyze = widget.hasRequiredInfo &&
        !widget.isPreview &&
        selectedCycleNo != null &&
        _status != _AnalysisStatus.loading;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const SectionHeader(
          title: 'AI분석',
          subtitle: '동일 회차의 기록을 요약하고 흐름을 정리합니다.\n회차가 쌓일수록 이전 회차와의 비교를 제공합니다.',
        ),
        if (!widget.hasRequiredInfo) ...[
          const RequiredInfoBanner(),
          const SizedBox(height: 18),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '회차 선택',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _CycleSelectButton(
                label: selectedCycleNo == null
                    ? widget.isPreview
                        ? '둘러보기에서는 분석할 기록이 없습니다.'
                        : '분석할 증상 기록이 없습니다.'
                    : '$selectedCycleNo회차 · ${grouped[selectedCycleNo]?.length ?? 0}일 기록',
                enabled: widget.hasRequiredInfo &&
                    !widget.isPreview &&
                    cycleNos.isNotEmpty,
                onTap: () => _pickCycle(cycleNos, grouped, selectedCycleNo),
              ),
              if (cycleNos.length > 8) ...[
                const SizedBox(height: 7),
                const Text(
                  '회차가 많을 경우 목록을 스크롤해 선택할 수 있습니다.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      canAnalyze ? () => _runAnalysis(selectedCycleNo) : null,
                  child: Text(
                    _status == _AnalysisStatus.loading ? '분석 중' : '분석하기',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_status == _AnalysisStatus.loading) ...[
          const SizedBox(height: 16),
          const _AnalysisLoadingCard(),
        ],
        if (_status == _AnalysisStatus.complete && _result != null) ...[
          const SizedBox(height: 16),
          _AnalysisResultView(
            cycleNo: selectedCycleNo!,
            records: grouped[selectedCycleNo] ?? const [],
            result: _result!,
            detailsExpanded: _detailsExpanded,
            onToggleDetails: () =>
                setState(() => _detailsExpanded = !_detailsExpanded),
          ),
        ],
      ],
    );
  }
}

class _CycleSelectButton extends StatelessWidget {
  const _CycleSelectButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.white : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: enabled ? AppColors.text : AppColors.muted,
                    fontSize: 14,
                    fontWeight: enabled ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: enabled ? AppColors.muted : AppColors.line,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CyclePickerSheet extends StatelessWidget {
  const _CyclePickerSheet({
    required this.cycleNos,
    required this.grouped,
    required this.selectedCycleNo,
  });

  final List<int> cycleNos;
  final Map<int, List<SymptomRecord>> grouped;
  final int? selectedCycleNo;

  @override
  Widget build(BuildContext context) {
    final screenBasedMaxHeight = MediaQuery.sizeOf(context).height * .56;
    final maxHeight = screenBasedMaxHeight > 420 ? 420.0 : screenBasedMaxHeight;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 430, maxHeight: maxHeight),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F1F2937),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '회차 선택',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('닫기'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: cycleNos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final cycleNo = cycleNos[index];
                      final selected = cycleNo == selectedCycleNo;
                      final count = grouped[cycleNo]?.length ?? 0;
                      return _CycleSheetOption(
                        cycleNo: cycleNo,
                        recordCount: count,
                        selected: selected,
                        onTap: () => Navigator.of(context).pop(cycleNo),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CycleSheetOption extends StatelessWidget {
  const _CycleSheetOption({
    required this.cycleNo,
    required this.recordCount,
    required this.selected,
    required this.onTap,
  });

  final int cycleNo;
  final int recordCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? AppColors.accentLine : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$cycleNo회차',
                  style: TextStyle(
                    color: selected ? AppColors.accent : AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$recordCount일 기록',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.accent,
                  size: 19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisLoadingCard extends StatelessWidget {
  const _AnalysisLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      borderColor: AppColors.accentLine,
      child: SizedBox(
        height: 180,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            SizedBox(height: 18),
            Text(
              'AI가 증상 데이터를 분석하고 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisResultView extends StatelessWidget {
  const _AnalysisResultView({
    required this.cycleNo,
    required this.records,
    required this.result,
    required this.detailsExpanded,
    required this.onToggleDetails,
  });

  final int cycleNo;
  final List<SymptomRecord> records;
  final AiAnalysisResult result;
  final bool detailsExpanded;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final sortedRecords = [...records]
      ..sort((a, b) => a.date.compareTo(b.date));
    final firstDate = sortedRecords.isEmpty ? null : sortedRecords.first.date;
    final lastDate = sortedRecords.isEmpty ? null : sortedRecords.last.date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResultTitle(source: result.source),
              const SizedBox(height: 16),
              _SelectedPeriodBox(
                cycleNo: cycleNo,
                firstDate: firstDate,
                lastDate: lastDate,
                recordCount: sortedRecords.length,
              ),
              const SizedBox(height: 16),
              for (final item in result.items) ...[
                _AnalysisItemPanel(item: item),
                const SizedBox(height: 12),
              ],
              _AiCommentPanel(
                comment: result.comment,
                encouragement: result.encouragement,
              ),
              const SizedBox(height: 12),
              const _MedicalDisclaimer(),
              const SizedBox(height: 12),
              _DetailToggle(
                expanded: detailsExpanded,
                onTap: onToggleDetails,
              ),
              if (detailsExpanded) ...[
                const SizedBox(height: 12),
                _DetailNotes(records: result.detailNotes),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultTitle extends StatelessWidget {
  const _ResultTitle({required this.source});

  final AiAnalysisSource source;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SoftIcon(label: 'AI'),
        const SizedBox(width: 8),
        const Text(
          '기록 요약 결과',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (!kReleaseMode) ...[
          const SizedBox(width: 8),
          _AnalysisSourceBadge(source: source),
        ],
      ],
    );
  }
}

class _AnalysisSourceBadge extends StatelessWidget {
  const _AnalysisSourceBadge({required this.source});

  final AiAnalysisSource source;

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      AiAnalysisSource.claude => 'AI 요약',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentLine),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectedPeriodBox extends StatelessWidget {
  const _SelectedPeriodBox({
    required this.cycleNo,
    required this.firstDate,
    required this.lastDate,
    required this.recordCount,
  });

  final int cycleNo;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final int recordCount;

  @override
  Widget build(BuildContext context) {
    final period = firstDate == null || lastDate == null
        ? '-'
        : '${_formatDate(firstDate!)} ~ ${_formatDate(lastDate!)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _SummaryRow(label: '회차', value: '$cycleNo회차'),
            const SizedBox(height: 10),
            _SummaryRow(label: '기록 기간', value: period),
            const SizedBox(height: 10),
            _SummaryRow(label: '총 기록 일수', value: '$recordCount일'),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalysisItemPanel extends StatelessWidget {
  const _AnalysisItemPanel({required this.item});

  final AiAnalysisItem item;

  @override
  Widget build(BuildContext context) {
    final title = _displayTitle(item.title);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panelColor(title),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelLine(title)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_itemIcon(title), style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _InlineAnalysisText(item.current),
            if (item.previous != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 10),
              const _ComparisonLabel(),
              const SizedBox(height: 8),
              _InlineAnalysisText(item.previous!),
            ],
          ],
        ),
      ),
    );
  }

  static String _displayTitle(String title) {
    return title.replaceAll(' 및 부작용', '');
  }

  static Color _panelColor(String title) {
    return switch (title) {
      '식사량' => const Color(0xFFFFFBEB),
      '음수량' => const Color(0xFFEFF6FF),
      '운동량' => const Color(0xFFF0FDF4),
      '배변' => const Color(0xFFFFFBEB),
      _ => const Color(0xFFFFF1F2),
    };
  }

  static Color _panelLine(String title) {
    return switch (title) {
      '식사량' => const Color(0xFFFDE68A),
      '음수량' => const Color(0xFFBFDBFE),
      '운동량' => const Color(0xFFBBF7D0),
      '배변' => const Color(0xFFFDE68A),
      _ => const Color(0xFFFECACA),
    };
  }

  static String _itemIcon(String title) {
    return switch (title) {
      '식사량' => '🍽️',
      '음수량' => '💧',
      '운동량' => '🚶',
      '배변' => '🚽',
      _ => '⚠️',
    };
  }
}

class _ComparisonLabel extends StatelessWidget {
  const _ComparisonLabel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          '이전 비교',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AiCommentPanel extends StatelessWidget {
  const _AiCommentPanel({
    required this.comment,
    required this.encouragement,
  });

  final String comment;
  final String encouragement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentLine),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('💬', style: TextStyle(fontSize: 15)),
                SizedBox(width: 6),
                Text(
                  'AI 코멘트',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RichAnalysisText(
              _inlineAnalysisText(comment),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                height: 1.58,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _RichAnalysisText(
              encouragement,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalDisclaimer extends StatelessWidget {
  const _MedicalDisclaimer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          '기록 요약은 참고용 정보로, 의학적 진단이나 치료 결정을 대체할 수 없습니다. 모든 건강 관련 결정은 반드시 담당 의료진과 상의하시기 바랍니다.',
          style:
              TextStyle(color: Color(0xFF8A5A00), fontSize: 12, height: 1.55),
        ),
      ),
    );
  }
}

class _DetailToggle extends StatelessWidget {
  const _DetailToggle({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          expanded ? '▼ 일자별 상세 증상 기록 접기' : '▶ 일자별 상세 증상 기록 펼치기',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _DetailNotes extends StatelessWidget {
  const _DetailNotes({required this.records});

  final List<SymptomRecord> records;

  @override
  Widget build(BuildContext context) {
    final notes = records
        .where((record) => record.note.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (notes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '입력된 상세증상이 없습니다.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final record in notes) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.note,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                  left: BorderSide(color: AppColors.noteLine, width: 4)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.cycleDay}일차 (${_formatDate(record.date)})',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    record.note.trim(),
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InlineAnalysisText extends StatelessWidget {
  const _InlineAnalysisText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return _RichAnalysisText(
      _inlineAnalysisText(text),
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 13,
        height: 1.58,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

String _inlineAnalysisText(String text) {
  final compacted = text
      .replaceAllMapped(
        RegExp(r'(\d)\.\s+(?=\d)'),
        (match) => '${match.group(1)}.',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return compacted
      .replaceAllMapped(
        RegExp(
          r'(\d+(?:\.\d+)?)(\s*)([~～-])(\s*)(\d+(?:\.\d+)?)(\s*)(ml|mL|ML|L|l|kg|%|보|걸음)',
        ),
        (match) =>
            '${match.group(1)}\u2060${match.group(3)}\u2060${match.group(5)}\u2060${match.group(7)}',
      )
      .replaceAllMapped(
        RegExp(r'(\d+(?:\.\d+)?)(\s*)(ml|mL|ML|L|l|kg|%|보|걸음)'),
        (match) => '${match.group(1)}\u2060${match.group(3)}',
      )
      .replaceAllMapped(
        RegExp(r'(\d)\.(?=\d)'),
        (match) => '${match.group(1)}.\u2060',
      );
}

class _RichAnalysisText extends StatelessWidget {
  const _RichAnalysisText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: _markdownBoldSpans(
          text,
          style,
          style.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      style: style,
    );
  }
}

List<InlineSpan> _markdownBoldSpans(
  String text,
  TextStyle baseStyle,
  TextStyle boldStyle,
) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  var cursor = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.addAll(_protectedAnalysisSpans(
          text.substring(cursor, match.start), baseStyle));
    }
    final boldText = match.group(1);
    if (boldText != null && boldText.isNotEmpty) {
      spans.addAll(_protectedAnalysisSpans(boldText, boldStyle));
    }
    cursor = match.end;
  }

  if (cursor < text.length) {
    spans.addAll(_protectedAnalysisSpans(text.substring(cursor), baseStyle));
  }

  return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
}

List<InlineSpan> _protectedAnalysisSpans(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(
    '\\d+(?:\\.\\u2060?\\d+)?[\\u2060\\s]*(?:ml|mL|ML|L|l|kg|%|보|걸음)?[\\u2060\\s]*[~～-][\\u2060\\s]*\\d+(?:\\.\\u2060?\\d+)?[\\u2060\\s]*(?:ml|mL|ML|L|l|kg|%|보|걸음)|\\d+(?:\\.\\u2060?\\d+)?[\\u2060\\s]*(?:ml|mL|ML|L|l|kg|%|보|걸음)',
  );
  var cursor = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: style));
    }
    final token = match.group(0);
    if (token != null && token.isNotEmpty) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Text(
            token.replaceAll('\u2060', ''),
            softWrap: false,
            style: style,
          ),
        ),
      );
    }
    cursor = match.end;
  }

  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: style));
  }

  return spans;
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
