import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({
    super.key,
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;

  static const terms = LegalScreen(
    title: '서비스 이용약관',
    intro: '본 약관은 한결 서비스 이용 조건과 사용자 및 서비스 제공자의 기본 책임 범위를 안내합니다.',
    sections: [
      LegalSection(
        title: '1. 서비스 목적',
        body:
            '본 서비스는 사용자가 복약, 체중, 식사, 수분섭취, 활동량, 컨디션 변화를 기록하고 필요한 내용을 정리할 수 있도록 돕는 기록 관리 서비스입니다.',
      ),
      LegalSection(
        title: '2. 회원 이용',
        body:
            '기록 저장, 복약 알림, AI 분석 등 주요 기능은 회원 로그인 후 이용할 수 있습니다. 둘러보기 모드는 앱 화면 구조 확인용이며 실제 기록 저장이나 권한 요청을 수행하지 않습니다.',
      ),
      LegalSection(
        title: '3. 사용자 기록 책임',
        body:
            '사용자는 본인의 정보를 정확히 입력해야 하며, 타인의 정보나 허위 정보를 입력해서는 안 됩니다. 입력한 기록이 부정확할 경우 분석 결과와 안내 내용도 제한적일 수 있습니다.',
      ),
      LegalSection(
        title: '4. 기록 요약과 건강 관련 안내',
        body:
            'AI 분석과 체중 변화 안내는 사용자가 입력한 기록을 정리해 보여주는 참고용 정보입니다. 의학적 진단, 처방, 치료 변경, 응급 판단을 대체하지 않습니다. 건강과 관련된 중요한 결정은 반드시 담당 의료진 또는 전문가와 상의해야 합니다.',
      ),
      LegalSection(
        title: '5. 알림과 걸음수 연동',
        body:
            '복약 알림과 걸음수 연동은 기기 상태, 운영체제 권한, 네트워크 상태에 따라 누락되거나 지연될 수 있습니다. 알림 수신과 걸음수 연동 여부는 사용자가 앱 또는 운영체제 설정에서 변경할 수 있습니다.',
      ),
      LegalSection(
        title: '6. 서비스 제한 및 중단',
        body:
            '서비스 안정성 개선, 보안 점검, 외부 인프라 장애 등 필요한 경우 서비스의 일부 또는 전부가 변경되거나 일시 중단될 수 있습니다.',
      ),
      LegalSection(
        title: '7. 탈퇴와 데이터 삭제',
        body:
            '사용자는 언제든지 회원탈퇴 또는 데이터 삭제를 요청할 수 있습니다. 관련 법령상 보관이 필요한 정보를 제외한 앱 내 기록은 삭제 절차에 따라 처리됩니다.',
      ),
      LegalSection(
        title: '8. 문의',
        body: '서비스 이용, 약관, 개인정보 처리와 관련한 문의는 앱의 문의하기 메뉴를 통해 접수할 수 있습니다.',
      ),
    ],
  );

  static const privacy = LegalScreen(
    title: '개인정보처리방침',
    intro: '한결 서비스는 복약, 체중, 컨디션, 생활 기록을 저장하고 정리하기 위해 필요한 최소한의 정보를 처리합니다.',
    sections: [
      LegalSection(
        title: '1. 처리하는 정보',
        bullets: [
          '회원 및 인증 정보: 이메일, 로그인 제공자, Firebase UID',
          '사용자 정보: 성별, 생년월일, 관리 항목, 단계, 기준일, 진행 상태, 관리 방식, 시작일, 키, 기타정보',
          '기록 정보: 복용 약물, 복약 알림 시간, 체중, BMI 계산값, 회차/진행일차, 식사량과 식사 메모, 음수량, 걸음수, 배변 여부와 상태, 컨디션 변화, 주요 컨디션 메모',
          '권한 정보: 알림 권한 상태, 걸음수 연동 권한 상태',
        ],
      ),
      LegalSection(
        title: '2. 이용 목적',
        body:
            '수집한 정보는 회원 인증, 기록 저장과 조회, 복약 알림, 체중 변화 확인, 컨디션 기록 관리, 회차별 AI 분석, 상담 전 기록 정리, 문의 응대와 서비스 안정성 개선을 위해 사용합니다. 광고, 마케팅, 사용자 추적, 정보 판매 목적으로 사용하지 않습니다.',
      ),
      LegalSection(
        title: '3. 알림 권한',
        body:
            '알림 권한은 복약 시간, 기록 안내 등 사용자가 설정한 알림을 보내기 위해 사용됩니다. 알림 권한을 해제하면 앱 내부 알림 기능이 제한될 수 있으며, 권한 상태는 마이페이지에서 확인하거나 운영체제 설정에서 변경할 수 있습니다.',
      ),
      LegalSection(
        title: '4. 걸음수 연동',
        body:
            '걸음수 연동은 사용자가 마이페이지에서 직접 켤 때만 권한을 요청합니다. iOS에서는 HealthKit, Android에서는 Health Connect를 통해 휴대폰의 걸음수를 불러와 기록의 운동량 입력에 사용합니다. 걸음수 데이터는 광고, 마케팅, 사용자 추적 목적으로 사용하지 않으며, 사용자는 언제든 설정에서 연동을 끌 수 있습니다.',
      ),
      LegalSection(
        title: '5. AI 분석 및 기록 요약',
        body:
            'AI 분석은 사용자가 AI분석 화면에서 분석을 요청할 때만 실행됩니다. 앱은 외부 AI 처리자를 직접 호출하지 않고 서버를 경유해 분석을 요청하며, 기록 요약에 필요한 최소 정보만 전송합니다. 이름, 이메일, Firebase UID, 로그인 제공자 정보는 AI 분석 요청에 포함하지 않습니다.\n\nAI 분석은 사용자가 입력한 기록을 요약하고 흐름을 정리하기 위한 기능입니다. 기록만으로 충분히 판단하기 어려운 경우 원인을 단정하지 않고 제한적으로 안내합니다.\n\nAI 분석 결과는 참고용 정보이며 의학적 진단, 처방, 치료 변경, 응급 판단을 대체하지 않습니다. 건강과 관련된 중요한 결정은 담당 의료진 또는 전문가와 상의해야 합니다.',
      ),
      LegalSection(
        title: '6. 제3자 제공 및 처리 위탁',
        body:
            '본 앱은 서비스 제공을 위해 인증, 데이터 저장, 서버 처리, AI 분석 등 외부 서비스를 사용할 수 있습니다. 외부 서비스에는 기능 제공에 필요한 최소 정보만 전달하며, 법령에 따른 경우를 제외하고 사용자의 동의 없이 건강정보를 판매하거나 광고 목적으로 제공하지 않습니다.',
      ),
      LegalSection(
        title: '7. 국외 처리 가능성',
        body:
            '외부 서비스 제공자의 서버 위치에 따라 정보가 국외에서 처리될 수 있습니다. 국외 처리 항목은 서비스 제공, 인증, 데이터 저장, AI 분석에 필요한 정보로 제한되며, 운영 리전과 보관 기간을 기준으로 앱 내 고지를 최신 상태로 유지합니다.',
      ),
      LegalSection(
        title: '8. 보관 및 삭제',
        body:
            '회원 정보와 기록은 회원이 서비스를 이용하는 기간 동안 보관합니다. 사용자가 기록을 삭제하거나 회원탈퇴를 요청하면 관련 계정과 앱 내 기록 삭제를 처리합니다. 단, 관계 법령 준수, 보안 사고 대응, 분쟁 해결을 위해 필요한 최소 정보는 정해진 기간 동안 보관될 수 있습니다.',
      ),
      LegalSection(
        title: '9. 이용자 권리',
        body:
            '사용자는 앱에서 본인의 정보를 확인, 수정, 삭제할 수 있으며 알림 권한, 걸음수 연동 권한, AI 분석 이용을 언제든 중단할 수 있습니다. 개인정보 관련 문의와 삭제 요청은 앱 내 문의하기 또는 개인정보 보호 문의처로 요청할 수 있습니다.',
      ),
      LegalSection(
        title: '10. 아동 이용',
        body:
            '본 앱은 본인의 기록 관리가 필요한 사용자와 보호자가 이용할 수 있습니다. 만 14세 미만 아동의 개인정보를 처리하는 경우 법정대리인의 동의가 필요하며, 법정대리인은 아동의 개인정보 열람, 수정, 삭제, 처리 정지를 요청할 수 있습니다.',
      ),
      LegalSection(
        title: '11. 문의',
        body:
            '개인정보 처리와 관련한 문의는 앱의 문의하기 메뉴 또는 ${AppConstants.privacyEmail}으로 접수할 수 있습니다.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: sections.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return AppCard(
              backgroundColor: AppColors.accentSoft,
              borderColor: AppColors.accentLine,
              child: Text(
                intro,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF4B3D7F),
                      height: 1.6,
                    ),
              ),
            );
          }
          return _PolicySectionCard(section: sections[index - 1]);
        },
      ),
    );
  }
}

class LegalSection {
  const LegalSection({
    required this.title,
    this.body,
    this.bullets = const [],
  });

  final String title;
  final String? body;
  final List<String> bullets;
}

class _PolicySectionCard extends StatelessWidget {
  const _PolicySectionCard({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: textTheme.titleMedium),
          if (section.body != null) ...[
            const SizedBox(height: 8),
            Text(
              section.body!,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF687385),
                height: 1.65,
              ),
            ),
          ],
          if (section.bullets.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...section.bullets.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: SizedBox(
                        width: 4,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF687385),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
