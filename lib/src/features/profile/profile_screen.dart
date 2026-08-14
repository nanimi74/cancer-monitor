import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/user_profile.dart';
import '../../services/auth/auth_service.dart';
import '../../services/health/step_sync_service.dart';
import '../../services/notifications/notification_permission_service.dart';
import '../legal/legal_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.hasRequiredInfo = true,
    this.isPreview = false,
    this.onExitPreview,
    this.onSignOut,
    this.onDeleteAccount,
    this.notificationPermissionService,
    this.stepSyncService,
    this.notificationEnabled = false,
    this.stepSyncEnabled = false,
    this.hasOtherActiveStepDevice = false,
    this.initialProfile,
    this.onNotificationPermissionChanged,
    this.onStepSyncChanged,
    this.onRequiredInfoChanged,
    this.onHeightChanged,
    this.onProfileChanged,
  });

  final bool hasRequiredInfo;
  final bool isPreview;
  final VoidCallback? onExitPreview;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onDeleteAccount;
  final NotificationPermissionService? notificationPermissionService;
  final StepSyncService? stepSyncService;
  final bool notificationEnabled;
  final bool stepSyncEnabled;
  final bool hasOtherActiveStepDevice;
  final UserProfile? initialProfile;
  final ValueChanged<bool>? onNotificationPermissionChanged;
  final ValueChanged<bool>? onStepSyncChanged;
  final ValueChanged<bool>? onRequiredInfoChanged;
  final ValueChanged<double?>? onHeightChanged;
  final ValueChanged<UserProfile?>? onProfileChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late _ProfileInfo? _profileInfo = widget.initialProfile == null
      ? null
      : _ProfileInfo.fromUserProfile(widget.initialProfile!);
  late var _notificationEnabled = widget.notificationEnabled;
  late var _stepSyncEnabled = widget.stepSyncEnabled;
  var _accountActionInProgress = false;
  var _notificationPermissionInProgress = false;
  var _stepSyncPermissionInProgress = false;
  late final NotificationPermissionService _notificationPermissionService =
      widget.notificationPermissionService ??
          LocalNotificationPermissionService();
  late final StepSyncService _stepSyncService =
      widget.stepSyncService ?? PlatformStepSyncService();

  bool get _hasRequiredInfo => _profileInfo != null;
  bool get _isIOS => Theme.of(context).platform == TargetPlatform.iOS;
  String get _stepSyncProviderName =>
      stepSyncProviderName(Theme.of(context).platform);

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notificationEnabled != widget.notificationEnabled) {
      _notificationEnabled = widget.notificationEnabled;
    }
    _stepSyncEnabled = widget.stepSyncEnabled;
    if (oldWidget.initialProfile != widget.initialProfile) {
      _profileInfo = widget.initialProfile == null
          ? null
          : _ProfileInfo.fromUserProfile(widget.initialProfile!);
    }
  }

  Future<void> _openProfileInfo() async {
    if (widget.isPreview) {
      _showMessage('회원만 이용할 수 있습니다.');
      return;
    }
    final result = await Navigator.of(context).push<_ProfileInfo>(
      MaterialPageRoute(
        builder: (_) => _ProfileInfoPage(initialValue: _profileInfo),
      ),
    );
    if (result != null) {
      setState(() => _profileInfo = result);
      widget.onRequiredInfoChanged?.call(true);
      widget.onHeightChanged?.call(result.heightCm);
      widget.onProfileChanged?.call(result.toUserProfile());
    }
  }

  Future<void> _setStepSync(bool value) async {
    if (_stepSyncPermissionInProgress) return;
    if (!value) {
      setState(() => _stepSyncEnabled = false);
      widget.onStepSyncChanged?.call(false);
      _showMessage('걸음수 연동 권한이 해제되었습니다.');
      return;
    }
    if (widget.isPreview) {
      _showMessage('둘러보기에서는 권한 요청을 진행하지 않습니다.');
      return;
    }
    if (widget.hasOtherActiveStepDevice) {
      final deviceChangeConfirmed =
          await _confirmStepSyncChange(replacingDevice: true);
      if (!mounted) return;
      if (deviceChangeConfirmed != true) {
        _showMessage('걸음수 연동 권한 요청이 취소되었습니다.');
        return;
      }
    }
    final permissionConfirmed = _isIOS
        ? await _showHealthKitStepSyncNotice()
        : await _confirmStepSyncChange(replacingDevice: false);
    if (!mounted) return;
    if (permissionConfirmed != true) {
      _showMessage('걸음수 연동 권한 요청이 취소되었습니다.');
      return;
    }

    setState(() => _stepSyncPermissionInProgress = true);
    try {
      final granted = await _stepSyncService.requestPermission();
      if (!mounted) return;
      if (granted && await _stepSyncService.readTodaySteps() == null) {
        throw const StepSyncPermissionException(
          '걸음수 읽기 권한을 확인할 수 없습니다.',
        );
      }
      if (!mounted) return;
      setState(() => _stepSyncEnabled = granted);
      widget.onStepSyncChanged?.call(granted);
      _showMessage(
        granted
            ? '걸음수 연동 권한이 허용되었습니다.'
            : '걸음수 연동 권한이 허용되지 않았습니다. 직접 입력을 사용할 수 있습니다.',
      );
    } on StepSyncPermissionException catch (error) {
      if (!mounted) return;
      setState(() => _stepSyncEnabled = false);
      widget.onStepSyncChanged?.call(false);
      await _showStepSyncSettingsSheet(error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stepSyncEnabled = false);
      widget.onStepSyncChanged?.call(false);
      await _showStepSyncSettingsSheet(
        StepSyncPermissionException(
          '$_stepSyncProviderName에서 한결의 걸음수 읽기만 허용해 주세요.',
        ),
      );
    } finally {
      if (mounted) setState(() => _stepSyncPermissionInProgress = false);
    }
  }

  Future<bool?> _confirmStepSyncChange({required bool replacingDevice}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(replacingDevice ? '걸음수 연동 기기 변경' : '걸음수 연동 권한'),
        content: Text(
          replacingDevice
              ? '다른 기기에서 걸음 수를 연동 중입니다. 이 기기로 변경할까요?'
              : '$_stepSyncProviderName의 걸음수만 불러와 증상 기록의 운동량을 자동 입력합니다. 걸음수 연동을 켜시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(replacingDevice ? '변경' : '켜기'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showHealthKitStepSyncNotice() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('걸음수 연동'),
        content: const Text(
          '활동량 변화를 기록하기 위해\nHealthKit에서 걸음 수만 읽습니다.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('걸음수 연동'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStepSyncSettingsSheet(
    StepSyncPermissionException error,
  ) async {
    if (!mounted) return;
    final needsInstall =
        error.issue == StepSyncPermissionIssue.healthConnectRequired;
    final providerName = _stepSyncProviderName;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F1F2937),
                      blurRadius: 36,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      needsInstall ? '$providerName가 필요해요' : '걸음수 권한이 필요해요',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      needsInstall
                          ? '설치 또는 업데이트 후 다시 시도해 주세요.'
                          : '$providerName에서 한결의 걸음수 읽기만 허용해 주세요.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final opened =
                            await _stepSyncService.openPermissionSettings();
                        if (!mounted || opened) return;
                        _showMessage('걸음수 연동을 활성화할 수 없습니다. 수동 입력을 사용해 주세요.');
                      },
                      child: Text(needsInstall ? '설치/업데이트' : '설정 열기'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('나중에 하기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _setNotificationPermission(bool value) async {
    if (_notificationPermissionInProgress) return;
    if (!value) {
      setState(() => _notificationEnabled = false);
      widget.onNotificationPermissionChanged?.call(false);
      _showMessage('알림 권한이 해제되었습니다.');
      return;
    }
    if (widget.isPreview) {
      _showMessage('둘러보기에서는 권한 요청을 진행하지 않습니다.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 권한'),
        content: const Text(
          '복약 알림과 앱 안내를 받기 위해 알림 권한이 필요합니다. 알림 권한을 허용하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('허용'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      _showMessage('알림 권한 요청이 취소되었습니다.');
      return;
    }

    setState(() => _notificationPermissionInProgress = true);
    try {
      final granted = await _notificationPermissionService.requestPermission();
      if (!mounted) return;
      setState(() => _notificationEnabled = granted);
      widget.onNotificationPermissionChanged?.call(granted);
      _showMessage(
        granted ? '알림 권한이 허용되었습니다.' : '알림 권한이 허용되지 않았습니다. 기기 설정을 확인해 주세요.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationEnabled = false);
      _showMessage('알림 권한 요청 중 문제가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _notificationPermissionInProgress = false);
    }
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
      await _runAccountAction(
        action: widget.onDeleteAccount,
        fallbackMessage: '회원탈퇴 기능을 연결할 수 없습니다.',
      );
    }
  }

  Future<void> _handleSignOut() async {
    await _runAccountAction(
      action: widget.onSignOut,
      fallbackMessage: '로그아웃 기능을 연결할 수 없습니다.',
    );
  }

  Future<void> _runAccountAction({
    required Future<void> Function()? action,
    required String fallbackMessage,
  }) async {
    if (_accountActionInProgress) return;
    if (action == null) {
      _showMessage(fallbackMessage);
      return;
    }

    setState(() => _accountActionInProgress = true);
    try {
      await action();
      if (mounted) setState(() => _accountActionInProgress = false);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
      setState(() => _accountActionInProgress = false);
    } catch (_) {
      if (!mounted) return;
      _showMessage('처리 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.');
      setState(() => _accountActionInProgress = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openContactEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.privacyEmail,
      queryParameters: const {
        'subject': '[한결] 문의하기',
        'body': '문의 내용을 입력해 주세요.\n\n',
      },
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showMessage('메일 앱을 열 수 없습니다. 메일 앱 설정을 확인해 주세요.');
    }
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
          subtitle: '성별, 생년월일, 개인 관리 정보',
          requiredMark: true,
          onTap: _openProfileInfo,
        ),
        _ToggleCard(
          title: '알림 권한',
          subtitle: '앱의 알림 권한을 허용하거나 해제합니다.',
          value: _notificationEnabled,
          switchKey: const ValueKey('notification-permission-switch'),
          onChanged: _setNotificationPermission,
        ),
        _ToggleCard(
          title: '걸음수 연동 권한',
          subtitle: '휴대폰의 걸음수를 불러와 증상관리에 사용합니다.',
          value: _stepSyncEnabled,
          switchKey: const ValueKey('step-sync-switch'),
          onChanged: _setStepSync,
        ),
        _MenuTile(
          title: '문의하기',
          subtitle: '서비스 이용 중 궁금한 점을 보냅니다.',
          onTap: _openContactEmail,
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
        if (widget.isPreview)
          OutlinedButton(
            onPressed:
                widget.onExitPreview ?? () => _showMessage('둘러보기를 종료합니다.'),
            child: const Text('둘러보기 나가기'),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _accountActionInProgress ? null : _handleSignOut,
                  child: const Text('로그아웃'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _accountActionInProgress ? null : _confirmWithdrawal,
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
        const _AppVersionLabel(),
      ],
    );
  }
}

class _AppVersionLabel extends StatelessWidget {
  const _AppVersionLabel();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final packageInfo = snapshot.data;
        final version = packageInfo == null ? '-' : packageInfo.version;
        return Text(
          '앱 버전 $version',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.muted),
        );
      },
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
            childAspectRatio: 2.45,
            children: [
              _SummaryItem(
                  label: '성별/연령', value: '${profile.sex} · 만 ${profile.age}세'),
              _SummaryItem(
                label: '관리항목/단계',
                value: '${profile.cancerType} · ${profile.stage}',
              ),
              _SummaryItem(label: '관리 방식', value: profile.treatmentType),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    this.switchKey,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

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
              key: switchKey,
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
    super.key,
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
  final _sexKey = GlobalKey();
  final _birthDateKey = GlobalKey();
  final _cancerTypeKey = GlobalKey();
  final _stageKey = GlobalKey();
  final _diagnosisDateKey = GlobalKey();
  final _metastasisKey = GlobalKey();
  final _treatmentTypeKey = GlobalKey();
  final _treatmentStartDateKey = GlobalKey();
  final _heightKey = GlobalKey();
  final _cancerTypeFocus = FocusNode();
  final _stageFocus = FocusNode();
  final _treatmentTypeFocus = FocusNode();
  final _heightFocus = FocusNode();
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
    _cancerTypeFocus.dispose();
    _stageFocus.dispose();
    _treatmentTypeFocus.dispose();
    _heightFocus.dispose();
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final option in options)
                _SheetOption(
                  label: option,
                  selected: option == (_optionValueForTitle(title)),
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
    final today = _dateOnly(DateTime.now());
    final resolvedFirstDate = firstDate ?? DateTime(1990);
    final resolvedLastDate = lastDate ?? today;
    final fallback = _clampDate(
      value ?? today,
      resolvedFirstDate,
      resolvedLastDate,
    );
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _DatePickerDialog(
        initialDate: fallback,
        firstDate: resolvedFirstDate,
        lastDate: resolvedLastDate,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  String _optionValueForTitle(String title) {
    return switch (title) {
      '성별' => _sex,
      '전이 여부' => _metastasis,
      _ => '',
    };
  }

  Future<void> _moveToField(GlobalKey key, [FocusNode? focusNode]) async {
    final targetContext = key.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: .08,
      );
    }
    if (focusNode != null) {
      focusNode.requestFocus();
      Future<void>.delayed(const Duration(milliseconds: 40), () {
        if (!mounted || !focusNode.hasFocus) return;
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    }
  }

  _MissingProfileField? _firstMissingRequiredField() {
    if (_sex.isEmpty) return _MissingProfileField('성별을 입력해주세요.', _sexKey);
    if (_birthDate == null) {
      return _MissingProfileField('생년월일을 입력해주세요.', _birthDateKey);
    }
    if (_cancerType.text.trim().isEmpty) {
      return _MissingProfileField(
        '암종을 입력해주세요.',
        _cancerTypeKey,
        _cancerTypeFocus,
      );
    }
    if (_stage.text.trim().isEmpty) {
      return _MissingProfileField('병기를 입력해주세요.', _stageKey, _stageFocus);
    }
    if (_diagnosisDate == null) {
      return _MissingProfileField('진단일을 입력해주세요.', _diagnosisDateKey);
    }
    if (_metastasis.isEmpty) {
      return _MissingProfileField('전이 여부를 입력해주세요.', _metastasisKey);
    }
    if (_treatmentType.text.trim().isEmpty) {
      return _MissingProfileField(
        '관리 방식을 입력해주세요.',
        _treatmentTypeKey,
        _treatmentTypeFocus,
      );
    }
    if (_treatmentStartDate == null) {
      return _MissingProfileField('치료 시작일을 입력해주세요.', _treatmentStartDateKey);
    }
    if (_height.text.trim().isEmpty) {
      return _MissingProfileField('키를 입력해주세요.', _heightKey, _heightFocus);
    }
    return null;
  }

  Future<void> _save() async {
    final missing = _firstMissingRequiredField();
    if (missing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(missing.message)),
      );
      await _moveToField(missing.fieldKey, missing.focusNode);
      return;
    }
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력값을 다시 확인해 주세요.')),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth >= 560;
            return Column(
              children: [
                _FieldGrid(
                  twoColumn: twoColumn,
                  children: [
                    _PickerField(
                      key: _sexKey,
                      label: '성별',
                      value: _sex,
                      onTap: () {
                        _selectOption(
                          title: '성별',
                          options: const ['여성', '남성', '기타'],
                          onSelected: (value) => setState(() => _sex = value),
                        );
                      },
                    ),
                    _PickerField(
                      key: _birthDateKey,
                      label: '생년월일',
                      value: _formatDate(_birthDate),
                      onTap: () => _pickDate(
                        value: _birthDate,
                        firstDate: DateTime(
                          DateTime.now().year - 120,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                        lastDate: _dateOnly(DateTime.now()),
                        onPicked: (value) => setState(() => _birthDate = value),
                      ),
                    ),
                  ],
                ),
                _TextInput(
                  key: _cancerTypeKey,
                  label: '암종',
                  controller: _cancerType,
                  focusNode: _cancerTypeFocus,
                  keyboardType: TextInputType.text,
                ),
                _TextInput(
                  key: _stageKey,
                  label: '병기',
                  controller: _stage,
                  focusNode: _stageFocus,
                  keyboardType: TextInputType.text,
                ),
                _FieldGrid(
                  twoColumn: twoColumn,
                  children: [
                    _PickerField(
                      key: _diagnosisDateKey,
                      label: '진단일',
                      value: _formatDate(_diagnosisDate),
                      onTap: () => _pickDate(
                        value: _diagnosisDate,
                        onPicked: (value) =>
                            setState(() => _diagnosisDate = value),
                      ),
                    ),
                    _PickerField(
                      key: _metastasisKey,
                      label: '전이 여부',
                      value: _metastasis,
                      onTap: () {
                        _selectOption(
                          title: '전이 여부',
                          options: const ['없음', '있음', '확인 필요'],
                          onSelected: (value) =>
                              setState(() => _metastasis = value),
                        );
                      },
                    ),
                  ],
                ),
                _FieldGrid(
                  twoColumn: twoColumn,
                  children: [
                    _TextInput(
                      key: _treatmentTypeKey,
                      label: '관리 방식',
                      controller: _treatmentType,
                      focusNode: _treatmentTypeFocus,
                      keyboardType: TextInputType.text,
                    ),
                    _PickerField(
                      key: _treatmentStartDateKey,
                      label: '치료 시작일',
                      value: _formatDate(_treatmentStartDate),
                      onTap: () => _pickDate(
                        value: _treatmentStartDate,
                        onPicked: (value) =>
                            setState(() => _treatmentStartDate = value),
                      ),
                    ),
                  ],
                ),
                _TextInput(
                  key: _heightKey,
                  label: '키(cm)',
                  controller: _height,
                  focusNode: _heightFocus,
                  keyboardType: TextInputType.number,
                ),
                _TextInput(
                  label: '기타정보',
                  controller: _extra,
                  required: false,
                  keyboardType: TextInputType.multiline,
                  maxLength: 500,
                  maxLines: 4,
                  hintText: '환자에 대해 알아야 하는 정보나 분석 시 참고할 만한 내용을 모두 입력해 주세요.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MissingProfileField {
  const _MissingProfileField(this.message, this.fieldKey, [this.focusNode]);

  final String message;
  final GlobalKey fieldKey;
  final FocusNode? focusNode;
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: Tooltip(
                              message: '이전',
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(color: AppColors.line),
                                  foregroundColor: AppColors.text,
                                ),
                                child: const Icon(Icons.chevron_left, size: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      child,
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 96,
                        child: ElevatedButton(
                          onPressed: action,
                          child: const Text('저장'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.accent : AppColors.text,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check, color: AppColors.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerDialog extends StatefulWidget {
  const _DatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late DateTime _visibleMonth =
      DateTime(widget.initialDate.year, widget.initialDate.month);
  late DateTime _selected = _dateOnly(widget.initialDate);
  late final TextEditingController _yearController =
      TextEditingController(text: _visibleMonth.year.toString());
  late final TextEditingController _monthController =
      TextEditingController(text: _visibleMonth.month.toString());

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  void _moveMonth(int delta) {
    setState(() {
      _visibleMonth = _clampMonth(
          DateTime(_visibleMonth.year, _visibleMonth.month + delta));
      _syncInputs();
    });
  }

  DateTime _clampMonth(DateTime value) {
    final month = DateTime(value.year, value.month);
    final minMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final maxMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (month.isBefore(minMonth)) return minMonth;
    if (month.isAfter(maxMonth)) return maxMonth;
    return month;
  }

  void _syncInputs() {
    _yearController.text = _visibleMonth.year.toString();
    _monthController.text = _visibleMonth.month.toString();
  }

  Future<void> _pickYear() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DateYearInputSheet(
        minYear: widget.firstDate.year,
        maxYear: widget.lastDate.year,
        selectedYear: _visibleMonth.year,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _visibleMonth = _clampMonth(DateTime(selected, _visibleMonth.month));
      _syncInputs();
    });
  }

  Future<void> _pickMonth() async {
    final minMonth = _visibleMonth.year == widget.firstDate.year
        ? widget.firstDate.month
        : 1;
    final maxMonth =
        _visibleMonth.year == widget.lastDate.year ? widget.lastDate.month : 12;
    final selected = await _pickNumber(
      title: '월 선택',
      values: [for (var month = minMonth; month <= maxMonth; month++) month],
      selectedValue: _visibleMonth.month,
      suffix: '월',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _visibleMonth = _clampMonth(DateTime(_visibleMonth.year, selected));
      _syncInputs();
    });
  }

  Future<int?> _pickNumber({
    required String title,
    required List<int> values,
    required int selectedValue,
    required String suffix,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DateNumberPickerSheet(
        title: title,
        values: values,
        selectedValue: selectedValue,
        suffix: suffix,
      ),
    );
  }

  bool _isDisabled(DateTime date) {
    final value = _dateOnly(date);
    return value.isBefore(_dateOnly(widget.firstDate)) ||
        value.isAfter(_dateOnly(widget.lastDate));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + bottomInset),
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: MediaQuery.sizeOf(context).height -
                bottomInset -
                MediaQuery.paddingOf(context).vertical -
                36,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '날짜 선택',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _DateNavButton(
                            icon: Icons.chevron_left,
                            onTap: () => _moveMonth(-1),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${_visibleMonth.year}년 ${_visibleMonth.month}월',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          _DateNavButton(
                            icon: Icons.chevron_right,
                            onTap: () => _moveMonth(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _yearController,
                              readOnly: true,
                              showCursor: false,
                              enableInteractiveSelection: false,
                              onTap: _pickYear,
                              textAlign: TextAlign.center,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _monthController,
                              readOnly: true,
                              showCursor: false,
                              enableInteractiveSelection: false,
                              onTap: _pickMonth,
                              textAlign: TextAlign.center,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        children: [
                          for (final weekday in const [
                            '월',
                            '화',
                            '수',
                            '목',
                            '금',
                            '토',
                            '일',
                          ])
                            Center(
                              child: Text(
                                weekday,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ..._dateCells(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _dateCells() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlankCount = firstDay.weekday - 1;
    return [
      for (var i = 0; i < leadingBlankCount; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DateCell(
          day: day,
          selected: _selected.year == _visibleMonth.year &&
              _selected.month == _visibleMonth.month &&
              _selected.day == day,
          disabled: _isDisabled(
            DateTime(_visibleMonth.year, _visibleMonth.month, day),
          ),
          onTap: () {
            final picked =
                DateTime(_visibleMonth.year, _visibleMonth.month, day);
            if (_isDisabled(picked)) return;
            FocusScope.of(context).unfocus();
            setState(() => _selected = picked);
            Navigator.of(context).pop(picked);
          },
        ),
    ];
  }
}

class _DateNavButton extends StatelessWidget {
  const _DateNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          foregroundColor: AppColors.text,
        ),
        child: Icon(icon, size: 19),
      ),
    );
  }
}

class _DateYearInputSheet extends StatefulWidget {
  const _DateYearInputSheet({
    required this.minYear,
    required this.maxYear,
    required this.selectedYear,
  });

  final int minYear;
  final int maxYear;
  final int selectedYear;

  @override
  State<_DateYearInputSheet> createState() => _DateYearInputSheetState();
}

class _DateYearInputSheetState extends State<_DateYearInputSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.selectedYear.toString());
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final year = int.tryParse(_controller.text.trim());
    if (year == null || year < widget.minYear || year > widget.maxYear) {
      setState(() {
        _errorText = '${widget.minYear}~${widget.maxYear}년 사이로 입력해주세요.';
      });
      return;
    }
    Navigator.of(context).pop(year);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottomInset),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: AppColors.text.withValues(alpha: .14),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '연도 입력',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: _fieldDecoration().copyWith(
                    hintText: '${widget.minYear}~${widget.maxYear}년 사이로 입력',
                    errorText: _errorText,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('적용'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateNumberPickerSheet extends StatelessWidget {
  const _DateNumberPickerSheet({
    required this.title,
    required this.values,
    required this.selectedValue,
    required this.suffix,
  });

  final String title;
  final List<int> values;
  final int selectedValue;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 360),
        margin: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.text.withValues(alpha: .14),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                itemCount: values.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final value = values[index];
                  final selected = value == selectedValue;
                  return Material(
                    color: selected
                        ? AppColors.accentSoft
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(value),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$value$suffix',
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.accent
                                      : AppColors.text,
                                  fontSize: 15,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_rounded,
                                color: AppColors.accent,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.day,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: disabled ? null : onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              color: disabled
                  ? AppColors.muted.withValues(alpha: .35)
                  : selected
                      ? Colors.white
                      : AppColors.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({
    required this.twoColumn,
    required this.children,
  });

  final bool twoColumn;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!twoColumn) {
      return Column(children: children);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(child: children[index]),
        ],
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
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
          decoration: _fieldDecoration(
            suffixIcon: const Icon(Icons.expand_more, color: AppColors.muted),
          ),
          child: Text(value.isEmpty ? '선택' : value),
        ),
      ),
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({
    super.key,
    required this.label,
    required this.controller,
    this.required = true,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.hintText,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final String? hintText;
  final FocusNode? focusNode;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final _focusNode = widget.focusNode ?? FocusNode();

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _showSoftKeyboard() {
    _focusNode.requestFocus();
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      if (!mounted || !_focusNode.hasFocus) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNumberInput = widget.keyboardType == TextInputType.number;
    return _FieldShell(
      label: widget.label,
      required: widget.required,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType ?? TextInputType.text,
        textCapitalization: TextCapitalization.none,
        textInputAction: widget.maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        autocorrect: !isNumberInput,
        enableSuggestions: !isNumberInput,
        enableIMEPersonalizedLearning: !isNumberInput,
        inputFormatters:
            isNumberInput ? [FilteringTextInputFormatter.digitsOnly] : null,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        decoration: _fieldDecoration(hintText: widget.hintText),
        onTap: _showSoftKeyboard,
        validator: (value) {
          if (!widget.required) return null;
          if (value == null || value.trim().isEmpty) return '필수 입력값입니다.';
          if (widget.keyboardType == TextInputType.number &&
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
      padding: const EdgeInsets.only(bottom: 12),
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
            style: const TextStyle(
              color: Color(0xFF3E484B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  String? hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    suffixIcon: suffixIcon,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    constraints: const BoxConstraints(minHeight: 42),
    counterStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
    hintStyle: const TextStyle(color: AppColors.muted),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accent),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
  );
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

  factory _ProfileInfo.fromUserProfile(UserProfile profile) {
    return _ProfileInfo(
      sex: profile.sex,
      birthDate: profile.birthDate,
      cancerType: profile.cancerType,
      stage: profile.stage,
      diagnosisDate: profile.diagnosisDate,
      metastasis: profile.metastasis,
      treatmentType: profile.treatmentType,
      treatmentStartDate: profile.treatmentStartDate,
      heightCm: profile.heightCm,
      extra: profile.extra,
    );
  }

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
    final today = DateTime.now();
    var value = today.year - birthDate.year;
    final birthdayPassed = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!birthdayPassed) value -= 1;
    return value;
  }

  UserProfile toUserProfile() {
    return UserProfile(
      sex: sex,
      birthDate: birthDate,
      cancerType: cancerType,
      stage: stage,
      diagnosisDate: diagnosisDate,
      metastasis: metastasis,
      treatmentType: treatmentType,
      treatmentStartDate: treatmentStartDate,
      heightCm: heightCm,
      extra: extra,
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime _clampDate(DateTime value, DateTime firstDate, DateTime lastDate) {
  final date = _dateOnly(value);
  final minDate = _dateOnly(firstDate);
  final maxDate = _dateOnly(lastDate);
  if (date.isBefore(minDate)) return minDate;
  if (date.isAfter(maxDate)) return maxDate;
  return date;
}
