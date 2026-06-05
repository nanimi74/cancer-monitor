import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';

class SymptomScreen extends StatelessWidget {
  const SymptomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        const SectionHeader(
          title: '증상 관리',
          subtitle: '항암 회차, 식사량, 음수량, 운동량, 배변, 주요 부작용을 기록합니다.',
        ),
        const AppCard(
          child: SizedBox(
            height: 360,
            child: Center(
              child: Text(
                '증상 기록이 없습니다.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () {},
          child: const Text('증상 기록하기'),
        ),
      ],
    );
  }
}
