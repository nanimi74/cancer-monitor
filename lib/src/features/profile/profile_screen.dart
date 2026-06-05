import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../legal/legal_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.hasRequiredInfo = true,
    this.isPreview = false,
  });

  final bool hasRequiredInfo;
  final bool isPreview;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late _ProfileInfo? _profileInfo =
      widget.hasRequiredInfo ? _ProfileInfo.sample() : null;
  late _CautionInfo? _cautionInfo =
      widget.hasRequiredInfo ? _CautionInfo.sample() : null;
  var _notificationEnabled = true;
  var _stepSyncEnabled = false;

  bool get _hasRequiredInfo => _profileInfo != null && _cautionInfo != null;

  Future<void> _openProfileInfo() async {
    final result = await Navigator.of(context).push<_ProfileInfo>(
      MaterialPageRoute(
        builder: (_) => _ProfileInfoPage(initialValue: _profileInfo),
      ),
    );
    if (result != null) {
      setState(() => _profileInfo = result);
    }
  }

  Future<void> _openCautionInfo() async {
    final result = await Navigator.of(context).push<_CautionInfo>(
      MaterialPageRoute(
        builder: (_) => _CautionInfoPage(initialValue: _cautionInfo),
      ),
    );
    if (result != null) {
      setState(() => _cautionInfo = result);
    }
  }

  Future<void> _setStepSync(bool value) async {
    if (!value) {
      setState(() => _stepSyncEnabled = false);
      return;
    }
    if (widget.isPreview) {
      _showMessage('둘러보기에서는 권한 요청을 진행하지 않습니다.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('걸음수 연동 권한'),
        content: const Text(
          '휴대폰의 걸음수를 불러와 증상관리에 사용합니다. 걸음수 연동을 켜시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('켜기'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _stepSyncEnabled = confirmed ?? false);
    _showMessage(
        _stepSyncEnabled ? '걸음수 연동 권한이 허용되었습니다.' : '걸음수 연동 권한 요청이 취소되었습니다.');
  }

  Future<void> _confirmWithdrawal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '회원탈퇴 시 계정과 앱에 저장된 기록이 삭제되며 복구할 수 없습니다. 정말 탈퇴하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _showMessage('회원탈퇴 요청이 접수되었습니다.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const SectionHeader(
          title: '마이페이지',
          subtitle: '서비스 이용과 AI 분석에 필요한 정보를 관리합니다.',
        ),
        if (_hasRequiredInfo)
          _ProfileSummaryCard(profile: _profileInfo!)
        else
          const RequiredInfoBanner(),
        const SizedBox(height: 14),
        _MenuTile(
          tileKey: const ValueKey('profile-info-menu'),
          title: '사용자 정보',
          subtitle: '성별, 생년월일, 질병 및 치료 정보',
          requiredMark: true,
          onTap: _openProfileInfo,
        ),
        _MenuTile(
          tileKey: const ValueKey('caution-info-menu'),
          title: '주의 정보',
          subtitle: '알레르기, 기저질환, 복용 주의 약물',
          requiredMark: true,
          onTap: _openCautionInfo,
        ),
        _ToggleCard(
          title: '알림 권한',
          subtitle: '앱의 알림 권한을 허용하거나 해제합니다.',
          value: _notificationEnabled,
          onChanged: (value) {
            setState(() => _notificationEnabled = value);
            _showMessage(value ? '알림 권한 허용 상태입니다.' : '알림 권한이 해제되었습니다.');
          },
        ),
        _ToggleCard(
          title: '걸음수 연동 권한',
          subtitle: '휴대폰의 걸음수를 불러와 증상관리에 사용합니다.',
          value: _stepSyncEnabled,
          onChanged: _setStepSync,
        ),
        _MenuTile(
          title: '문의하기',
          subtitle: '서비스 이용 중 궁금한 점을 보냅니다.',
          onTap: () => _showMessage('문의하기 화면은 다음 단계에서 연결됩니다.'),
        ),
        _MenuTile(
          title: '서비스 이용약관',
          subtitle: '서비스 이용 조건과 책임 범위를 확인합니다.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LegalScreen.terms),
          ),
        ),
        _MenuTile(
          title: '개인정보처리방침',
          subtitle: '수집 항목과 이용 목적을 확인합니다.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LegalScreen.privacy),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showMessage('로그아웃되었습니다.'),
                child: const Text('로그아웃'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _confirmWithdrawal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  side: const BorderSide(color: AppColors.line),
                ),
                child: const Text('회원탈퇴'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '앱 버전 ${AppConstants.appVersion}',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profile});

  final _ProfileInfo profile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.accentSoft,
      borderColor: AppColors.accentLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '사용자 정보 요약',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.8,
            children: [
              _SummaryItem(
                  label: '성별/연령', value: '${profile.sex} · 만 ${profile.age}세'),
              _SummaryItem(
                label: '암종/병기',
                value: '${profile.cancerType} · ${profile.stage}',
              ),
              _SummaryItem(label: '치료', value: profile.treatmentType),
              _SummaryItem(
                  label: '키',
                  value: '${profile.heightCm.toStringAsFixed(0)}cm'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        border: Border.all(color: AppColors.accentLine),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.requiredMark = false,
    this.tileKey,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool requiredMark;
  final Key? tileKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        key: tileKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (requiredMark) ...[
                          const CircleAvatar(
                            radius: 3,
                            backgroundColor: AppColors.accent,
                          ),
                          const SizedBox(width: 7),
                        ],
                        Text(
                          title,
                          style: _profileTileTitleStyle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: _profileTileSubtitleSize,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

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
                  Text(title, style: _profileTileTitleStyle),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: _profileTileSubtitleSize,
                    ),
                  ),
                ],
              ),
            ),
            _ProfileSwitch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

const double _profileTileSubtitleSize = 12;

const TextStyle _profileTileTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

class _ProfileSwitch extends StatelessWidget {
  const _ProfileSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.accent : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.text.withValues(alpha: .18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoPage extends StatefulWidget {
  const _ProfileInfoPage({this.initialValue});

  final _ProfileInfo? initialValue;

  @override
  State<_ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<_ProfileInfoPage> {
  final _formKey = GlobalKey<FormState>();
  late String _sex = widget.initialValue?.sex ?? '';
  late DateTime? _birthDate = widget.initialValue?.birthDate;
  late DateTime? _diagnosisDate = widget.initialValue?.diagnosisDate;
  late DateTime? _treatmentStartDate = widget.initialValue?.treatmentStartDate;
  late String _metastasis = widget.initialValue?.metastasis ?? '';
  late final _cancerType =
      TextEditingController(text: widget.initialValue?.cancerType ?? '');
  late final _stage =
      TextEditingController(text: widget.initialValue?.stage ?? '');
  late final _treatmentType =
      TextEditingController(text: widget.initialValue?.treatmentType ?? '');
  late final _height = TextEditingController(
      text: widget.initialValue?.heightCm.toStringAsFixed(0) ?? '');
  late final _extra =
      TextEditingController(text: widget.initialValue?.extra ?? '');

  @override
  void dispose() {
    _cancerType.dispose();
    _stage.dispose();
    _treatmentType.dispose();
    _height.dispose();
    _extra.dispose();
    super.dispose();
  }

  Future<void> _selectOption({
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final option in options)
                ListTile(
                  title: Text(option),
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
    if (result != null) onSelected(result);
  }

  Future<void> _pickDate({
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(2026, 6, 5),
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.accent,
                surface: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  void _save() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid ||
        _sex.isEmpty ||
        _birthDate == null ||
        _diagnosisDate == null ||
        _metastasis.isEmpty ||
        _treatmentStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 정보를 모두 입력해 주세요.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _ProfileInfo(
        sex: _sex,
        birthDate: _birthDate!,
        cancerType: _cancerType.text.trim(),
        stage: _stage.text.trim(),
        diagnosisDate: _diagnosisDate!,
        metastasis: _metastasis,
        treatmentType: _treatmentType.text.trim(),
        treatmentStartDate: _treatmentStartDate!,
        heightCm: double.parse(_height.text),
        extra: _extra.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FormPageScaffold(
      title: '사용자 정보',
      action: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _PickerField(
                label: '성별',
                value: _sex,
                onTap: () {
                  _selectOption(
                    title: '성별',
                    options: const ['여성', '남성', '기타'],
                    onSelected: (value) => setState(() => _sex = value),
                  );
                }),
            _PickerField(
              label: '생년월일',
              value: _formatDate(_birthDate),
              onTap: () => _pickDate(
                value: _birthDate,
                lastDate: DateTime(2026, 6, 5),
                onPicked: (value) => setState(() => _birthDate = value),
              ),
            ),
            _TextInput(label: '암종', controller: _cancerType),
            _TextInput(label: '병기', controller: _stage),
            _PickerField(
              label: '진단일',
              value: _formatDate(_diagnosisDate),
              onTap: () => _pickDate(
                value: _diagnosisDate,
                onPicked: (value) => setState(() => _diagnosisDate = value),
              ),
            ),
            _PickerField(
                label: '전이 여부',
                value: _metastasis,
                onTap: () {
                  _selectOption(
                    title: '전이 여부',
                    options: const ['없음', '있음', '확인 필요'],
                    onSelected: (value) => setState(() => _metastasis = value),
                  );
                }),
            _TextInput(label: '항암치료 종류', controller: _treatmentType),
            _PickerField(
              label: '치료 시작일',
              value: _formatDate(_treatmentStartDate),
              onTap: () => _pickDate(
                value: _treatmentStartDate,
                onPicked: (value) =>
                    setState(() => _treatmentStartDate = value),
              ),
            ),
            _TextInput(
              label: '키(cm)',
              controller: _height,
              keyboardType: TextInputType.number,
            ),
            _TextInput(
              label: '기타정보',
              controller: _extra,
              required: false,
              maxLength: 200,
              maxLines: 4,
              hintText: '환자에 대해 알아야 하는 정보나 분석 시 참고할 만한 내용을 모두 입력해 주세요.',
            ),
          ],
        ),
      ),
    );
  }
}

class _CautionInfoPage extends StatefulWidget {
  const _CautionInfoPage({this.initialValue});

  final _CautionInfo? initialValue;

  @override
  State<_CautionInfoPage> createState() => _CautionInfoPageState();
}

class _CautionInfoPageState extends State<_CautionInfoPage> {
  final _formKey = GlobalKey<FormState>();
  late final _allergy =
      TextEditingController(text: widget.initialValue?.allergy ?? '');
  late final _conditions =
      TextEditingController(text: widget.initialValue?.conditions ?? '');
  late final _precautions =
      TextEditingController(text: widget.initialValue?.precautions ?? '');

  @override
  void dispose() {
    _allergy.dispose();
    _conditions.dispose();
    _precautions.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _CautionInfo(
        allergy: _allergy.text.trim(),
        conditions: _conditions.text.trim(),
        precautions: _precautions.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FormPageScaffold(
      title: '주의 정보',
      action: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextInput(label: '알레르기', controller: _allergy),
            _TextInput(label: '기저질환', controller: _conditions),
            _TextInput(label: '복용 금기 또는 주의 약물', controller: _precautions),
          ],
        ),
      ),
    );
  }
}

class _FormPageScaffold extends StatelessWidget {
  const _FormPageScaffold({
    required this.title,
    required this.child,
    required this.action,
  });

  final String title;
  final Widget child;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전',
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
              children: [child],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 10, 24, 18),
        child: ElevatedButton(onPressed: action, child: const Text('저장')),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: InputDecorator(
          decoration:
              const InputDecoration(suffixIcon: Icon(Icons.expand_more)),
          child: Text(value.isEmpty ? '선택' : value),
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.label,
    required this.controller,
    this.required = true,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      required: required,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hintText),
        validator: (value) {
          if (!required) return null;
          if (value == null || value.trim().isEmpty) return '필수 입력값입니다.';
          if (keyboardType == TextInputType.number &&
              double.tryParse(value) == null) {
            return '숫자로 입력해 주세요.';
          }
          return null;
        },
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.label,
    required this.child,
    this.required = true,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ProfileInfo {
  const _ProfileInfo({
    required this.sex,
    required this.birthDate,
    required this.cancerType,
    required this.stage,
    required this.diagnosisDate,
    required this.metastasis,
    required this.treatmentType,
    required this.treatmentStartDate,
    required this.heightCm,
    this.extra = '',
  });

  factory _ProfileInfo.sample() => _ProfileInfo(
        sex: '여성',
        birthDate: DateTime(1974, 3, 12),
        cancerType: '유방암',
        stage: '2기',
        diagnosisDate: DateTime(2026, 1, 15),
        metastasis: '없음',
        treatmentType: '주사 항암',
        treatmentStartDate: DateTime(2026, 4, 1),
        heightCm: 162,
        extra: '',
      );

  final String sex;
  final DateTime birthDate;
  final String cancerType;
  final String stage;
  final DateTime diagnosisDate;
  final String metastasis;
  final String treatmentType;
  final DateTime treatmentStartDate;
  final double heightCm;
  final String extra;

  int get age {
    final today = DateTime(2026, 6, 5);
    var value = today.year - birthDate.year;
    final birthdayPassed = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!birthdayPassed) value -= 1;
    return value;
  }
}

class _CautionInfo {
  const _CautionInfo({
    required this.allergy,
    required this.conditions,
    required this.precautions,
  });

  factory _CautionInfo.sample() => const _CautionInfo(
        allergy: '없음',
        conditions: '고혈압',
        precautions: '없음',
      );

  final String allergy;
  final String conditions;
  final String precautions;
}

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
