import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_card.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  static const terms = LegalScreen(
    title: '서비스 이용약관',
    body: '본 서비스는 항암치료 기록 관리와 외래 상담 준비를 돕기 위한 모바일 앱입니다.\n\n'
        '사용자는 본인의 정보를 정확히 입력해야 하며, 앱에서 제공하는 AI 분석과 체중 변화 안내는 참고용 정보입니다. '
        '본 서비스는 의학적 진단, 처방, 치료 변경, 응급 판단을 대체하지 않습니다.\n\n'
        '복약 알림과 걸음수 연동은 기기 상태, 네트워크, 권한 설정에 따라 누락될 수 있습니다. '
        '모든 증상과 건강 관련 결정은 담당 의료진과 상의하시기 바랍니다.\n\n'
        'AI 분석 기능은 Claude API 등 외부 AI 처리자를 서버 경유로 사용할 수 있습니다. '
        'AI 분석에 동의하지 않는 경우 해당 기능을 사용할 수 없습니다.\n\n'
        '회원탈퇴 시 계정과 앱 내 기록 삭제를 요청할 수 있습니다.',
  );

  static const privacy = LegalScreen(
    title: '개인정보처리방침',
    body: '본 앱은 항암치료 기록 관리를 위해 회원정보, 사용자정보, 약물, 체중, 증상, 알림 권한, 걸음수 연동 권한 정보를 처리합니다.\n\n'
        '걸음수 연동은 iOS HealthKit 또는 Android Health Connect 권한을 사용하며, 사용자가 설정 화면에서 연동을 켤 때만 권한을 요청합니다.\n\n'
        'AI 분석은 Claude API(Anthropic)를 서버 경유로 호출하여 사용자 정보와 건강 기록을 참고용으로 요약합니다. '
        '분석 요청에는 연령, 성별, 암종/병기, 키, 체중, 증상, 식사, 수분, 걸음수, 배변, 부작용, 주요증상 텍스트 등 분석에 필요한 최소 건강정보만 포함합니다. '
        '이름, 이메일, Firebase UID, 로그인 제공자 정보는 Claude API 요청에 포함하지 않습니다.\n\n'
        'Claude API 등 외부 AI 처리자의 데이터 보관 기간, 모델 학습 사용 여부, 국외 이전 여부는 실제 운영 계약과 최신 정책에 따라 별도 고지합니다. '
        '사용자는 AI 분석 안내에 동의하지 않으면 AI 분석 기능을 이용하지 않을 수 있습니다.\n\n'
        'AI 분석은 의학적 진단이나 치료 결정을 대체하지 않습니다.\n\n'
        '문의: ${AppConstants.privacyEmail}',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppCard(
            child: Text(body),
          ),
        ],
      ),
    );
  }
}
