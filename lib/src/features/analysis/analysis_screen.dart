import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              const Text(
                '항암 회차 선택',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                items: const [],
                onChanged: null,
                decoration: const InputDecoration(
                  hintText: '분석할 증상 기록이 없습니다.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              const ElevatedButton(
                onPressed: null,
                child: Text('분석하기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const AppCard(
          child: SizedBox(
            height: 150,
            child: Center(
              child: Text(
                '증상 기록을 입력하면 AI분석을 진행할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
