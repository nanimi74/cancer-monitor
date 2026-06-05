import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';

class MedicationScreen extends StatelessWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        const SectionHeader(
          title: '약물 관리',
          subtitle: '복용 중인 약물과 복수 알림 시간을 관리합니다.',
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('약물 등록'),
        ),
        const SizedBox(height: 14),
        const AppCard(
          child: SizedBox(
            height: 132,
            child: Center(
              child: Text(
                '등록된 약물이 없습니다.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
