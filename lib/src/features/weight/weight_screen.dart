import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';

class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: const [
        SectionHeader(
          title: '체중 관리',
          subtitle: '최근 체중과 사용자정보의 키를 기준으로 BMI를 계산하고, 기간별 체중 변화를 확인합니다.',
        ),
        AppCard(
          child: SizedBox(
            height: 280,
            child: Center(
              child: Text(
                '체중 기록이 없습니다.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ),
        ),
        SizedBox(height: 14),
        AppCard(
          child: SizedBox(
            height: 220,
            child: Center(
              child: Text(
                '그래프를 그릴 체중 기록이 부족합니다.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ),
        ),
        SizedBox(height: 18),
        Text(
          'BMI와 체중 변화 안내는 참고용 정보이며, 의학적 진단이나 치료 결정을 대체하지 않습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
