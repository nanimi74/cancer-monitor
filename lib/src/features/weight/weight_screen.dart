import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/repositories/sample_repository.dart';

class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const repository = SampleRepository();
    final profile = repository.profile;
    final weights = repository.weights;
    final latest = weights.last;
    final heightM = profile.heightCm / 100;
    final bmi = latest.weightKg / (heightM * heightM);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        const SectionHeader(
          title: '체중 관리',
          subtitle: '최근 체중과 사용자정보의 키를 기준으로 BMI를 계산하고, 기간별 체중 변화를 확인합니다.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('현재 BMI ${bmi.toStringAsFixed(1)} · ✅ 정상', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('BMI가 정상이더라도 체중 변화, 식사량, 수분섭취를 함께 확인해 주세요.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              Text('최근 체중 ${latest.weightKg.toStringAsFixed(1)}kg · 마지막 입력일 2026-06-02', style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const AppCard(
          backgroundColor: AppColors.dangerSoft,
          borderColor: Color(0xFFFFD0C9),
          child: Text('🚨 체중 변화 상담 권고\nBMI 20 미만에서 최근 9일 2.1% 감소가 확인됩니다. 의료진과 상담해 주세요.'),
        ),
        const SizedBox(height: 14),
        const AppCard(
          child: SizedBox(
            height: 280,
            child: Center(child: Text('체중 캘린더 / 그래프 영역')),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'BMI와 체중 변화 안내는 참고용 정보이며, 의학적 진단이나 치료 결정을 대체하지 않습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
