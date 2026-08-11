import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/models/medication.dart';
import '../data/models/symptom_record.dart';
import '../data/models/user_profile.dart';
import '../data/models/weight_record.dart';
import '../data/repositories/user_data_repository.dart';
import '../services/device/device_identity_service.dart';
import '../services/health/step_sync_service.dart';
import '../services/notifications/notification_permission_service.dart';
import 'analysis/analysis_screen.dart';
import 'medication/medication_screen.dart';
import 'profile/profile_screen.dart';
import 'symptom/symptom_screen.dart';
import 'weight/weight_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.isPreview = false,
    this.hasRequiredInfo = true,
    this.onExitPreview,
    this.onSignOut,
    this.onDeleteAccount,
    this.notificationPermissionService,
    this.stepSyncService,
    this.deviceIdentityService = const DeviceIdentityService(),
    this.deviceId,
    this.userId,
    this.userDataRepository,
  });

  final bool isPreview;
  final bool hasRequiredInfo;
  final VoidCallback? onExitPreview;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onDeleteAccount;
  final NotificationPermissionService? notificationPermissionService;
  final StepSyncService? stepSyncService;
  final DeviceIdentityService deviceIdentityService;
  final String? deviceId;
  final String? userId;
  final UserDataRepository? userDataRepository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _signOutWriteTimeout = Duration(seconds: 2);
  static const _profileTabIndex = 0;
  static const _symptomTabIndex = 3;

  late final UserDataRepository _userDataRepository =
      widget.userDataRepository ?? UserDataRepository();
  late final NotificationPermissionService _notificationPermissionService =
      widget.notificationPermissionService ??
          LocalNotificationPermissionService();
  late var _hasRequiredInfo = widget.hasRequiredInfo;
  late var _index = _hasRequiredInfo ? _symptomTabIndex : _profileTabIndex;
  var _notificationEnabled = false;
  var _stepSyncEnabled = false;
  late var _loadingUserData = _canPersist;
  double? _heightCm;
  UserProfile? _userProfile;
  var _medications = <Medication>[];
  var _medicationReminderEnabled = <int, bool>{};
  var _sharedMedicationReminderEnabled = <int, bool>{};
  var _weightRecords = <WeightRecord>[];
  var _symptomRecords = <SymptomRecord>[];
  String? _deviceId;
  Future<void> _pendingWrite = Future<void>.value();
  StreamSubscription<String>? _notificationPayloadSubscription;
  String? _pendingNotificationPayload;

  bool get _canPersist => !widget.isPreview && widget.userId != null;

  Future<String> _resolveDeviceId() async {
    final provided = widget.deviceId;
    if (provided != null && provided.isNotEmpty) return provided;
    return widget.deviceIdentityService.deviceId();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationPayloadSubscription =
        _notificationPermissionService.notificationPayloads.listen(
      _handleNotificationPayload,
    );
    unawaited(_consumeLaunchNotificationPayload());
    unawaited(_loadUserData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_notificationPayloadSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadUserData());
    }
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.isPreview != widget.isPreview ||
        oldWidget.deviceId != widget.deviceId) {
      unawaited(_loadUserData());
    }
  }

  Future<void> _loadUserData() async {
    if (!_canPersist) {
      if (mounted && _loadingUserData) {
        setState(() => _loadingUserData = false);
      }
      return;
    }
    final userId = widget.userId!;
    final deviceId = await _resolveDeviceId();
    if (!mounted || widget.userId != userId) return;
    _deviceId = deviceId;
    setState(() => _loadingUserData = true);
    try {
      final remoteSnapshot =
          await _userDataRepository.load(userId, deviceId: deviceId);
      final remoteMedications = _applyMedicationReminderSettings(
        remoteSnapshot.medications,
        remoteSnapshot.settings.medicationReminderEnabled,
      );
      if (!mounted || widget.userId != userId) return;
      setState(() {
        _notificationEnabled = remoteSnapshot.settings.notificationEnabled;
        _stepSyncEnabled = remoteSnapshot.settings.stepSyncEnabled;
        _medicationReminderEnabled = _medicationReminderMap(remoteMedications);
        _sharedMedicationReminderEnabled =
            _medicationReminderMap(remoteSnapshot.medications);
        _userProfile = remoteSnapshot.profile;
        _heightCm = remoteSnapshot.profile?.heightCm;
        _hasRequiredInfo = remoteSnapshot.profile != null;
        _medications = remoteMedications;
        _weightRecords = remoteSnapshot.weights;
        _symptomRecords = remoteSnapshot.symptoms;
        if (!_applyPendingNotificationDestination()) {
          if (_hasRequiredInfo && _index == _profileTabIndex) {
            _index = _symptomTabIndex;
          }
        }
      });
      unawaited(_syncMedicationNotifications());
      unawaited(_syncDailyConditionReminder());
      unawaited(
        _userDataRepository.saveCachedSnapshot(
          userId,
          remoteSnapshot,
          deviceId: deviceId,
        ),
      );
    } catch (_) {
      final cachedSnapshot = await _userDataRepository.loadCachedSnapshot(
        userId,
        deviceId: deviceId,
      );
      if (!mounted || widget.userId != userId) return;
      if (cachedSnapshot != null) {
        final cachedMedications = _applyMedicationReminderSettings(
          cachedSnapshot.medications,
          cachedSnapshot.settings.medicationReminderEnabled,
        );
        setState(() {
          _notificationEnabled = cachedSnapshot.settings.notificationEnabled;
          _stepSyncEnabled = cachedSnapshot.settings.stepSyncEnabled;
          _medicationReminderEnabled =
              _medicationReminderMap(cachedMedications);
          _sharedMedicationReminderEnabled =
              _medicationReminderMap(cachedSnapshot.medications);
          _userProfile = cachedSnapshot.profile;
          _heightCm = cachedSnapshot.profile?.heightCm;
          _hasRequiredInfo = cachedSnapshot.profile != null;
          _medications = cachedMedications;
          _weightRecords = cachedSnapshot.weights;
          _symptomRecords = cachedSnapshot.symptoms;
          if (!_applyPendingNotificationDestination()) {
            if (_hasRequiredInfo && _index == _profileTabIndex) {
              _index = _symptomTabIndex;
            }
          }
        });
        unawaited(_syncMedicationNotifications());
        unawaited(_syncDailyConditionReminder());
        return;
      }
      setState(() {
        _notificationEnabled = false;
        _stepSyncEnabled = false;
        _userProfile = null;
        _heightCm = null;
        _hasRequiredInfo = false;
        _medications = const [];
        _medicationReminderEnabled = const {};
        _sharedMedicationReminderEnabled = const {};
        _weightRecords = const [];
        _symptomRecords = const [];
        _index = _profileTabIndex;
      });
      unawaited(_syncDailyConditionReminder());
    } finally {
      if (mounted && widget.userId == userId) {
        setState(() => _loadingUserData = false);
      }
    }
  }

  void _saveSettings() {
    if (!_canPersist) return;
    final deviceId = _deviceId;
    if (deviceId == null || deviceId.isEmpty) return;
    _cacheCurrentSnapshot();
    _queueWrite(
      () => _userDataRepository.saveSettings(
        widget.userId!,
        UserSettings(
          notificationEnabled: _notificationEnabled,
          stepSyncEnabled: _stepSyncEnabled,
          medicationReminderEnabled: _medicationReminderEnabled,
        ),
        deviceId: deviceId,
      ),
    );
  }

  void _saveProfile(UserProfile? profile) {
    if (!_canPersist || profile == null) return;
    _cacheCurrentSnapshot();
    _queueWrite(() => _userDataRepository.saveProfile(widget.userId!, profile));
  }

  void _saveMedications(List<Medication> medications) {
    if (!_canPersist) return;
    _medicationReminderEnabled = _medicationReminderMap(medications);
    _sharedMedicationReminderEnabled = {
      for (final medication in medications)
        medication.id: _sharedMedicationReminderEnabled[medication.id] ??
            medication.reminderEnabled,
    };
    _saveSettings();
    _queueWrite(
      () => _userDataRepository.saveMedications(
        widget.userId!,
        _medicationsForSharedStorage(medications),
      ),
    );
  }

  void _saveWeights(List<WeightRecord> records) {
    if (!_canPersist) return;
    _cacheCurrentSnapshot();
    _queueWrite(() => _userDataRepository.saveWeights(widget.userId!, records));
  }

  void _saveSymptoms(List<SymptomRecord> records) {
    if (!_canPersist) return;
    _cacheCurrentSnapshot();
    _queueWrite(
      () => _userDataRepository.saveSymptoms(widget.userId!, records),
    );
  }

  void _cacheCurrentSnapshot() {
    if (!_canPersist) return;
    final deviceId = _deviceId;
    if (deviceId == null || deviceId.isEmpty) return;
    unawaited(
      _userDataRepository.saveCachedSnapshot(
        widget.userId!,
        UserDataSnapshot(
          settings: UserSettings(
            notificationEnabled: _notificationEnabled,
            stepSyncEnabled: _stepSyncEnabled,
            medicationReminderEnabled: _medicationReminderEnabled,
          ),
          profile: _userProfile,
          medications: _medications,
          weights: _weightRecords,
          symptoms: _symptomRecords,
        ),
        deviceId: deviceId,
      ),
    );
  }

  Future<void> _syncMedicationNotifications({bool announce = false}) async {
    if (widget.isPreview) return;
    try {
      final medications = _notificationEnabled ? _medications : <Medication>[];
      await _notificationPermissionService.syncMedicationReminders(medications);
      if (!announce ||
          !mounted ||
          !_hasActiveMedicationReminders(medications)) {
        return;
      }
      final pendingCount =
          await _notificationPermissionService.pendingMedicationReminderCount();
      if (!mounted) return;
      _showMessage(
        pendingCount > 0
            ? '복약 알림이 등록되었습니다.'
            : '예약된 복약 알림이 없습니다. 알림 시간과 기기 권한을 확인해 주세요.',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('복약 알림 예약 중 문제가 발생했습니다.');
    }
  }

  Future<void> _syncDailyConditionReminder() async {
    if (widget.isPreview) return;
    try {
      await _notificationPermissionService.syncDailyConditionReminder(
        enabled: _notificationEnabled,
      );
    } catch (_) {
      // 컨디션 알림 예약 실패가 앱 사용을 막지 않도록 합니다.
    }
  }

  Future<void> _consumeLaunchNotificationPayload() async {
    if (widget.isPreview) return;
    final String? payload;
    try {
      payload = await _notificationPermissionService.takeLaunchPayload();
    } catch (_) {
      return;
    }
    if (!mounted || payload == null) return;
    _handleNotificationPayload(payload);
  }

  void _handleNotificationPayload(String payload) {
    if (!_opensSymptomScreen(payload)) return;
    if (_loadingUserData) {
      _pendingNotificationPayload = payload;
      return;
    }
    setState(() => _index = _symptomTabIndex);
  }

  bool _applyPendingNotificationDestination() {
    final payload = _pendingNotificationPayload;
    if (payload == null || !_opensSymptomScreen(payload)) return false;
    _pendingNotificationPayload = null;
    _index = _symptomTabIndex;
    return true;
  }

  bool _opensSymptomScreen(String payload) {
    return payload.startsWith('medication:') ||
        payload.startsWith('condition:');
  }

  bool _hasActiveMedicationReminders(List<Medication> medications) {
    return medications.any(
      (medication) =>
          medication.reminderEnabled &&
          medication.reminders.any((reminder) => reminder.enabled),
    );
  }

  List<Medication> _applyMedicationReminderSettings(
    List<Medication> medications,
    Map<int, bool> reminderSettings,
  ) {
    return [
      for (final medication in medications)
        _copyMedication(
          medication,
          reminderEnabled:
              reminderSettings[medication.id] ?? medication.reminderEnabled,
        ),
    ];
  }

  Map<int, bool> _medicationReminderMap(List<Medication> medications) {
    return {
      for (final medication in medications)
        medication.id: medication.reminderEnabled,
    };
  }

  List<Medication> _medicationsForSharedStorage(
    List<Medication> medications,
  ) {
    return [
      for (final medication in medications)
        _copyMedication(
          medication,
          reminderEnabled: _sharedMedicationReminderEnabled[medication.id] ??
              medication.reminderEnabled,
        ),
    ];
  }

  Medication _copyMedication(
    Medication medication, {
    bool? reminderEnabled,
  }) {
    return Medication(
      id: medication.id,
      name: medication.name,
      dose: medication.dose,
      frequency: medication.frequency,
      weekdays: medication.weekdays,
      reminderEnabled: reminderEnabled ?? medication.reminderEnabled,
      reminders: medication.reminders,
      memo: medication.memo,
    );
  }

  Future<void> _queueWrite(Future<void> Function() operation) {
    final write = _pendingWrite
        .catchError((_) {})
        .then((_) => operation())
        .catchError((error) {
      _showSaveError();
      throw error;
    });
    _pendingWrite = write;
    return write;
  }

  Future<void> _flushPendingWrites() async {
    try {
      await _pendingWrite.timeout(_signOutWriteTimeout);
    } catch (_) {}
  }

  Future<void> _prepareAnalysisData() async {
    if (!_canPersist) return;
    await _pendingWrite.catchError((_) {});
    if (!mounted || !_canPersist) return;

    final userId = widget.userId!;
    final profile = _userProfile;
    final weights = List<WeightRecord>.of(_weightRecords);
    final symptoms = List<SymptomRecord>.of(_symptomRecords);
    _cacheCurrentSnapshot();

    final write = Future.wait<void>([
      if (profile != null) _userDataRepository.saveProfile(userId, profile),
      _userDataRepository.saveWeights(userId, weights),
      _userDataRepository.saveSymptoms(userId, symptoms),
    ]).then((_) {});
    _pendingWrite = write;
    try {
      await write;
    } catch (_) {
      _showSaveError();
      rethrow;
    }
  }

  Future<void> _handleSignOut() async {
    await _flushPendingWrites();
    await widget.onSignOut?.call();
  }

  Future<void> _handleDeleteAccount() async {
    await widget.onDeleteAccount?.call();
  }

  void _showSaveError() {
    if (!mounted) return;
    _showMessage('기록 저장에 실패했습니다. 네트워크 상태를 확인해 주세요.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width =
                constraints.maxWidth > 680 ? 680.0 : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: _loadingUserData
                    ? const _UserDataLoadingView()
                    : IndexedStack(
                        index: _index,
                        children: _screens,
                      ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _loadingUserData
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .97),
                border: const Border(top: BorderSide(color: AppColors.line)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.text.withValues(alpha: .08),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 74,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
                        child: NavigationBarTheme(
                          data: NavigationBarThemeData(
                            indicatorColor: Colors.transparent,
                            labelTextStyle: WidgetStateProperty.resolveWith(
                              (states) => TextStyle(
                                color: states.contains(WidgetState.selected)
                                    ? AppColors.accent
                                    : AppColors.muted,
                                fontSize: 12,
                                fontWeight:
                                    states.contains(WidgetState.selected)
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                              ),
                            ),
                            iconTheme: WidgetStateProperty.resolveWith(
                              (states) => IconThemeData(
                                color: states.contains(WidgetState.selected)
                                    ? AppColors.accent
                                    : AppColors.muted,
                                size: 27,
                              ),
                            ),
                          ),
                          child: NavigationBar(
                            selectedIndex: _index,
                            height: 58,
                            elevation: 0,
                            backgroundColor: Colors.transparent,
                            indicatorColor: Colors.transparent,
                            labelBehavior:
                                NavigationDestinationLabelBehavior.alwaysShow,
                            onDestinationSelected: (index) =>
                                setState(() => _index = index),
                            destinations: const [
                              NavigationDestination(
                                icon: Icon(Icons.person_outline),
                                selectedIcon: Icon(Icons.person_outline),
                                label: '마이페이지',
                              ),
                              NavigationDestination(
                                icon: _CapsuleIcon(),
                                selectedIcon: _CapsuleIcon(selected: true),
                                label: '복약관리',
                              ),
                              NavigationDestination(
                                icon: _ScaleIcon(),
                                selectedIcon: _ScaleIcon(selected: true),
                                label: '체중관리',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.calendar_month_outlined),
                                selectedIcon:
                                    Icon(Icons.calendar_month_outlined),
                                label: '증상관리',
                              ),
                              NavigationDestination(
                                icon: _AiIcon(),
                                selectedIcon: _AiIcon(selected: true),
                                label: 'AI분석',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> get _screens => [
        ProfileScreen(
          hasRequiredInfo: _hasRequiredInfo,
          isPreview: widget.isPreview,
          onExitPreview: widget.onExitPreview,
          onSignOut: widget.onSignOut == null ? null : _handleSignOut,
          onDeleteAccount:
              widget.onDeleteAccount == null ? null : _handleDeleteAccount,
          notificationPermissionService: _notificationPermissionService,
          stepSyncService: widget.stepSyncService,
          initialProfile: _userProfile,
          notificationEnabled: _notificationEnabled,
          stepSyncEnabled: _stepSyncEnabled,
          onNotificationPermissionChanged: (value) => setState(() {
            _notificationEnabled = value;
            _saveSettings();
            unawaited(_syncMedicationNotifications(announce: value));
            unawaited(_syncDailyConditionReminder());
          }),
          onStepSyncChanged: (value) => setState(() {
            _stepSyncEnabled = value;
            _saveSettings();
          }),
          onRequiredInfoChanged: (value) =>
              setState(() => _hasRequiredInfo = value),
          onHeightChanged: (value) => setState(() => _heightCm = value),
          onProfileChanged: (value) => setState(() {
            _userProfile = value;
            _heightCm = value?.heightCm;
            _saveProfile(value);
          }),
        ),
        MedicationScreen(
          hasRequiredInfo: _hasRequiredInfo,
          isPreview: widget.isPreview,
          notificationEnabled: _notificationEnabled,
          initialMedications: _medications,
          notificationPermissionService: _notificationPermissionService,
          onNotificationPermissionChanged: (value) => setState(() {
            _notificationEnabled = value;
            _saveSettings();
            unawaited(_syncMedicationNotifications(announce: value));
            unawaited(_syncDailyConditionReminder());
          }),
          onMedicationsChanged: (medications) => setState(() {
            _medications = medications;
            _saveMedications(medications);
            unawaited(_syncMedicationNotifications(announce: true));
          }),
        ),
        WeightScreen(
          hasRequiredInfo: _hasRequiredInfo,
          isPreview: widget.isPreview,
          heightCm: _heightCm,
          initialRecords: _weightRecords,
          onRecordsChanged: (records) => setState(() {
            _weightRecords = records;
            _saveWeights(records);
          }),
        ),
        SymptomScreen(
          hasRequiredInfo: _hasRequiredInfo,
          isPreview: widget.isPreview,
          deviceId: _deviceId,
          stepSyncEnabled: _stepSyncEnabled,
          initialRecords: _symptomRecords,
          stepSyncService: widget.stepSyncService,
          onStepSyncChanged: (value) => setState(() {
            _stepSyncEnabled = value;
            _saveSettings();
          }),
          onRecordsChanged: (records) => setState(() {
            _symptomRecords = records;
            _saveSymptoms(records);
          }),
        ),
        AnalysisScreen(
          hasRequiredInfo: _hasRequiredInfo,
          isPreview: widget.isPreview,
          profile: _userProfile,
          records: _symptomRecords,
          weights: _weightRecords,
          onPrepareAnalysis: _prepareAnalysisData,
        ),
      ];
}

class _UserDataLoadingView extends StatelessWidget {
  const _UserDataLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 18),
            Text(
              '사용자 데이터를 불러오고 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleIcon extends StatelessWidget {
  const _CapsuleIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return SizedBox(
      width: 25,
      height: 25,
      child: Transform.rotate(
        angle: -0.78,
        child: CustomPaint(
          painter: _CapsulePainter(color: color, filled: selected),
        ),
      ),
    );
  }
}

class _CapsulePainter extends CustomPainter {
  const _CapsulePainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(3, 7, size.width - 6, 11);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    final fill = Paint()
      ..color = color.withValues(alpha: filled ? .95 : .22)
      ..style = PaintingStyle.fill;

    final leftHalf =
        Rect.fromLTRB(rect.left, rect.top, rect.center.dx, rect.bottom);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(leftHalf, fill);
    canvas.restore();
    canvas.drawRRect(rrect, stroke);
    canvas.drawLine(Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom), stroke);
  }

  @override
  bool shouldRepaint(covariant _CapsulePainter oldDelegate) {
    return color != oldDelegate.color || filled != oldDelegate.filled;
  }
}

class _ScaleIcon extends StatelessWidget {
  const _ScaleIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return SizedBox(
      width: 25,
      height: 25,
      child: CustomPaint(painter: _ScalePainter(color: color)),
    );
  }
}

class _ScalePainter extends CustomPainter {
  const _ScalePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(5, 4, size.width - 10, size.height - 6),
      const Radius.circular(5),
    );
    final display = RRect.fromRectAndRadius(
      Rect.fromLTWH(8.5, 7.5, size.width - 17, 5.5),
      const Radius.circular(2),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawRRect(display, stroke);
    canvas.drawLine(
        Offset(size.width / 2, 15), Offset(size.width / 2, 18), stroke);
  }

  @override
  bool shouldRepaint(covariant _ScalePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _AiIcon extends StatelessWidget {
  const _AiIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.6),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'AI',
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
