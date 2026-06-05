import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/repositories/sample_repository.dart';
import '../../services/ai/ai_analysis_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _repository = const SampleRepository();
  final _analysisService = const AiAnalysisService();
  int _selectedCycle = 2;
  bool _isLoading = false;
  AiAnalysisResult? _result;
  bool _detailExpanded = false;

  Future<void> _analyze() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _detailExpanded = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final records = _repository.symptoms.where((record) => record.cycleNo == _selectedCycle).toList();
    final previous = _repository.symptoms.where((record) => record.cycleNo == _selectedCycle - 1).toList();
    setState(() {
      _isLoading = false;
      _result = _analysisService.analyze(
        cycleNo: _selectedCycle,
        profile: _repository.profile,
        records: records,
        previousRecords: previous,
        weights: _repository.weights,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cycles = _repository.symptoms.map((record) => record.cycleNo).toSet().toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        const SectionHeader(
          title: 'AI분석',
          subtitle: '동일 항암 회차의 기록을 요약하고 분석합니다. 회차가 쌓일수록 이전 회차와의 비교 분석을 제공합니다.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('항암 회차 선택', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _selectedCycle,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: cycles
                    .map((cycle) => DropdownMenuItem(
                          value: cycle,
                          child: Text('$cycle회차 (${_repository.symptoms.where((record) => record.cycleNo == cycle).length}일 기록)'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedCycle = value;
                    _result = null;
                    _detailExpanded = false;
                  });
                },
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _analyze,
                child: const Text('분석하기'),
              ),
            ],
          ),
        ),
        if (_isLoading) ...[
          const SizedBox(height: 14),
          const AppCard(
            child: SizedBox(
              height: 220,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 18),
                  Text('AI가 증상 데이터를 분석하고 있습니다...'),
                ],
              ),
            ),
          ),
        ],
        if (_result case final result?) ...[
          const SizedBox(height: 14),
          _AnalysisResultView(
            result: result,
            detailExpanded: _detailExpanded,
            onToggleDetail: () => setState(() => _detailExpanded = !_detailExpanded),
          ),
        ],
      ],
    );
  }
}

class _AnalysisResultView extends StatelessWidget {
  const _AnalysisResultView({
    required this.result,
    required this.detailExpanded,
    required this.onToggleDetail,
  });

  final AiAnalysisResult result;
  final bool detailExpanded;
  final VoidCallback onToggleDetail;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.accentLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🤖 AI 분석 결과', style: Theme.of(context).textTheme.titleMedium),
          const Divider(height: 26),
          ...result.items.map((item) => _AnalysisItemCard(item: item)),
          const SizedBox(height: 14),
          Text('💬 AI 코멘트 (참고용)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          AppCard(
            backgroundColor: const Color(0xFFFFF7E6),
            borderColor: const Color(0xFFFFD98F),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemText(result.comment)),
                const SizedBox(height: 12),
                const Divider(),
                Text(result.encouragement, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const AppCard(
            backgroundColor: AppColors.goldSoft,
            borderColor: Color(0xFFEFD18E),
            child: Text('⚠️ 중요 안내\n${AppConstants.aiDisclaimer}'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onToggleDetail,
            child: Text(detailExpanded ? '▼ 일자별 상세 증상 기록 접기' : '▶ 일자별 상세 증상 기록 펼치기'),
          ),
          if (detailExpanded) ...[
            const SizedBox(height: 10),
            if (result.detailNotes.isEmpty)
              const Text('입력된 상세증상이 없습니다.', style: TextStyle(color: AppColors.muted))
            else
              ...result.detailNotes.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    backgroundColor: AppColors.note,
                    borderColor: AppColors.noteLine,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${record.cycleDay}일차 (${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')})',
                            style: const TextStyle(color: Color(0xFF9A4412), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(record.note, style: const TextStyle(color: Color(0xFF8A3B12))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String itemText(String text) => text;
}

class _AnalysisItemCard extends StatelessWidget {
  const _AnalysisItemCard({required this.item});

  final AiAnalysisItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .68),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.current, style: const TextStyle(color: Colors.white)),
                if (item.previous != null) ...[
                  const Divider(color: Colors.white54, height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('📊 이전 비교', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Text(item.previous!, style: const TextStyle(color: Colors.white)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
