import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/repositories/sample_repository.dart';
import '../legal/legal_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = const SampleRepository().profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        const SectionHeader(
          title: '마이페이지',
          subtitle: '서비스 이용과 AI 분석에 필요한 정보를 관리합니다.',
        ),
        AppCard(
          backgroundColor: AppColors.accentSoft,
          borderColor: AppColors.accentLine,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('사용자 정보 요약', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _SummaryRow(label: '성별/연령', value: '${profile.sex} · 만 ${profile.age(DateTime(2026, 6, 3))}세'),
              _SummaryRow(label: '암종/병기', value: '${profile.cancerType} · ${profile.stage}'),
              _SummaryRow(label: '키', value: '${profile.heightCm.toStringAsFixed(0)}cm'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _MenuTile(title: '사용자정보', subtitle: '성별, 생년월일, 질병 정보, 키'),
        const _MenuTile(title: '주의정보', subtitle: '알레르기, 기저질환, 복용 주의 약물'),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              const _ToggleRow(title: '알림 권한', subtitle: '앱의 알림 권한을 허용하거나 해제합니다.'),
              const Divider(),
              const _ToggleRow(
                title: '걸음수 연동',
                subtitle: 'iOS HealthKit 또는 Android Health Connect의 걸음수를 불러옵니다.',
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('서비스 이용약관'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LegalScreen.terms),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('개인정보처리방침'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LegalScreen.privacy),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '앱 버전 ${AppConstants.appVersion}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 86, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatefulWidget {
  const _ToggleRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  var enabled = false;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      value: enabled,
      onChanged: (value) => setState(() => enabled = value),
    );
  }
}
