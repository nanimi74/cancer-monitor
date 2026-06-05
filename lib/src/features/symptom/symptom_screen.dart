import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/repositories/sample_repository.dart';

class SymptomScreen extends StatelessWidget {
  const SymptomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final symptoms = const SampleRepository().symptoms;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        const SectionHeader(
          title: '증상 관리',
          subtitle: '항암 회차, 식사량, 음수량, 운동량, 배변, 주요 부작용을 기록합니다.',
        ),
        AppCard(
          child: SizedBox(
            height: 360,
            child: Center(
              child: Text(
                '2026년 6월 증상 캘린더\n${symptoms.map((item) => '${item.cycleNo}-${item.cycleDay}').join(' · ')}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...symptoms.map((record) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('2026년 06월 ${record.date.day.toString().padLeft(2, '0')}일', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Text('항암 치료 정보 ${record.cycleNo}차 · ${record.cycleDay}일차', style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Text('주요 부작용 ${record.sideEffects.join(', ')}'),
                  const SizedBox(height: 8),
                  Text(record.note.isEmpty ? '입력된 주요증상이 없습니다.' : record.note, style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
