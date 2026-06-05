import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/repositories/sample_repository.dart';

class MedicationScreen extends StatelessWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final medications = const SampleRepository().medications;
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
        ...medications.map((medication) {
          final enabledCount = medication.reminders.where((item) => item.enabled).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(medication.name, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      _ReminderBadge(enabled: enabledCount > 0),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${medication.frequency} · ${medication.reminders.map((item) => '${item.label} ${item.time}').join(', ')} · ${medication.dose}'
                    '${medication.memo.isEmpty ? '' : ' · ${medication.memo}'}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: enabled ? AppColors.accentSoft : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
            size: 15,
            color: enabled ? AppColors.accent : AppColors.muted,
          ),
          const SizedBox(width: 4),
          Text(
            enabled ? '알림 켜짐' : '알림 꺼짐',
            style: TextStyle(
              color: enabled ? AppColors.accent : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
