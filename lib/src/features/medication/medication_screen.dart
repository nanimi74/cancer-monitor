import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/medication.dart' as data;
import '../../services/notifications/notification_permission_service.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({
    super.key,
    this.hasRequiredInfo = true,
    this.isPreview = false,
    this.notificationEnabled = false,
    this.initialMedications = const [],
    this.onNotificationPermissionChanged,
    this.onMedicationsChanged,
    this.notificationPermissionService,
  });

  final bool hasRequiredInfo;
  final bool isPreview;
  final bool notificationEnabled;
  final List<data.Medication> initialMedications;
  final ValueChanged<bool>? onNotificationPermissionChanged;
  final ValueChanged<List<data.Medication>>? onMedicationsChanged;
  final NotificationPermissionService? notificationPermissionService;

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final _medications = <_Medication>[];
  var _nextMedicationId = 1;
  late var _notificationEnabled = widget.notificationEnabled;
  late final NotificationPermissionService _notificationPermissionService =
      widget.notificationPermissionService ??
          LocalNotificationPermissionService();

  @override
  void initState() {
    super.initState();
    _syncInitialMedications();
  }

  @override
  void didUpdateWidget(covariant MedicationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMedications != widget.initialMedications) {
      _syncInitialMedications();
    }
    if (oldWidget.notificationEnabled != widget.notificationEnabled) {
      _notificationEnabled = widget.notificationEnabled;
    }
  }

  Future<void> _openEditor([_Medication? medication]) async {
    if (!widget.hasRequiredInfo) return;

    final result = await showModalBottomSheet<_MedicationEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MedicationEditorSheet(
        initialMedication: medication,
        isPreview: widget.isPreview,
        notificationEnabled: _notificationEnabled,
        notificationPermissionService: _notificationPermissionService,
        onNotificationPermissionChanged: (value) {
          _notificationEnabled = value;
          widget.onNotificationPermissionChanged?.call(value);
        },
      ),
    );

    if (!mounted || result == null) return;
    if (result.previewBlocked) {
      _showMessage('둘러보기에서는 기록이 저장되지 않습니다.');
      return;
    }

    if (result.deletedId != null) {
      setState(() {
        _medications.removeWhere((item) => item.id == result.deletedId);
      });
      _showMessage('약물 기록이 삭제되었습니다.');
      _notifyMedicationsChanged();
      return;
    }

    final saved = result.medication;
    if (saved == null) return;
    setState(() {
      final index = _medications.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        _medications.add(saved);
      } else {
        _medications[index] = saved;
      }
    });
    _notifyMedicationsChanged();
    if (!saved.reminderEnabled) {
      _showMessage('약물 정보가 저장되었습니다.');
    }
  }

  void _syncInitialMedications() {
    _medications
      ..clear()
      ..addAll(widget.initialMedications.map(_Medication.fromModel));
    final maxId = _medications.fold<int>(
      0,
      (value, medication) => medication.id > value ? medication.id : value,
    );
    _nextMedicationId = maxId + 1;
  }

  void _notifyMedicationsChanged() {
    widget.onMedicationsChanged?.call(
      _medications.map((medication) => medication.toModel()).toList(),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  _Medication _createMedication({
    required String name,
    required String dose,
    required String frequency,
    required List<String> weekdays,
    required bool reminderEnabled,
    required List<_MedicationReminder> reminders,
    required String memo,
    int? id,
  }) {
    return _Medication(
      id: id ?? _nextMedicationId++,
      name: name,
      dose: dose,
      frequency: frequency,
      weekdays: weekdays,
      reminderEnabled: reminderEnabled,
      reminders: reminders,
      memo: memo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final addEnabled = widget.hasRequiredInfo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const SectionHeader(
          title: '약물 관리',
          subtitle: '복용 약물을 등록하고 섭취 시간 알림을 설정합니다.',
        ),
        ElevatedButton(
          onPressed: addEnabled
              ? () => _openEditor(
                    _createMedication(
                      name: '',
                      dose: '',
                      frequency: '매일',
                      weekdays: const [],
                      reminderEnabled: _notificationEnabled,
                      reminders: _defaultReminders(),
                      memo: '',
                    ),
                  )
              : null,
          child: const Text('약물 등록'),
        ),
        if (!widget.hasRequiredInfo) ...[
          const SizedBox(height: 14),
          const RequiredInfoBanner(),
        ],
        const SizedBox(height: 14),
        if (_medications.isEmpty)
          const AppCard(
            padding: EdgeInsets.symmetric(vertical: 42, horizontal: 16),
            child: Center(
              child: Text(
                '등록된 약물이 없습니다.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          ..._medications.map(
            (medication) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MedicationListCard(
                medication: medication,
                notificationEnabled: _notificationEnabled,
                onTap: () => _openEditor(medication),
              ),
            ),
          ),
      ],
    );
  }
}

class _MedicationListCard extends StatelessWidget {
  const _MedicationListCard({
    required this.medication,
    required this.notificationEnabled,
    required this.onTap,
  });

  final _Medication medication;
  final bool notificationEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          medication.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _ReminderBadge(
                        enabled:
                            medication.reminderEnabled && notificationEnabled,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    medication.summary,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.accent : AppColors.muted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? AppColors.accentSoft : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: enabled ? AppColors.accentLine : AppColors.line,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              enabled ? '켜짐' : '꺼짐',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationEditorSheet extends StatefulWidget {
  const _MedicationEditorSheet({
    required this.initialMedication,
    required this.isPreview,
    required this.notificationEnabled,
    required this.notificationPermissionService,
    required this.onNotificationPermissionChanged,
  });

  final _Medication? initialMedication;
  final bool isPreview;
  final bool notificationEnabled;
  final NotificationPermissionService notificationPermissionService;
  final ValueChanged<bool> onNotificationPermissionChanged;

  @override
  State<_MedicationEditorSheet> createState() => _MedicationEditorSheetState();
}

class _MedicationEditorSheetState extends State<_MedicationEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _initialDose = _parseDose(widget.initialMedication?.dose ?? '');
  late final _name = TextEditingController(
    text: widget.initialMedication?.name ?? '',
  );
  late final _doseAmount = TextEditingController(
    text: _initialDose.amount,
  );
  late final _memo = TextEditingController(
    text: widget.initialMedication?.memo ?? '',
  );
  late var _doseUnit = _initialDose.unit;
  late var _frequency = widget.initialMedication?.frequency ?? '매일';
  late var _weekdays = widget.initialMedication?.weekdays.toSet() ?? <String>{};
  late var _reminderEnabled = widget.initialMedication?.reminderEnabled ?? true;
  late final _reminders = [
    ...(widget.initialMedication?.reminders ?? _defaultReminders()),
  ];
  late var _notificationEnabled = widget.notificationEnabled;
  var _requestingPermission = false;

  bool get _isNewMedication {
    final medication = widget.initialMedication;
    return medication == null ||
        (medication.name.isEmpty &&
            medication.dose.isEmpty &&
            medication.memo.isEmpty);
  }

  @override
  void dispose() {
    _name.dispose();
    _doseAmount.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDoseUnit() async {
    final selected = await _showOptionSheet(
      title: '복용 단위',
      options: _doseUnits,
      currentValue: _doseUnit,
    );
    if (selected == null) return;
    setState(() => _doseUnit = selected);
  }

  Future<void> _pickFrequency() async {
    final selected = await _showOptionSheet(
      title: '복용 주기',
      options: const ['매일', '필요시', '직접입력'],
      currentValue: _frequency,
    );
    if (selected == null) return;
    setState(() {
      final wasAsNeeded = _frequency == '필요시';
      _frequency = selected;
      if (_frequency != '직접입력') {
        _weekdays.clear();
      }
      if (_frequency == '필요시') {
        _reminderEnabled = false;
      } else if (wasAsNeeded) {
        _reminderEnabled = true;
      }
    });
  }

  Future<void> _pickReminderLabel(int index) async {
    final selected = await _showOptionSheet(
      title: '알림 시간',
      options: _reminderLabels,
      currentValue: _reminders[index].label,
    );
    if (selected == null) return;
    setState(() {
      _reminders[index] = _reminders[index].copyWith(label: selected);
    });
  }

  Future<void> _pickReminderTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminders[index].time,
      helpText: '직접 시간 설정',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null) return;
    setState(() {
      _reminders[index] = _reminders[index].copyWith(time: picked);
    });
  }

  Future<String?> _showOptionSheet({
    required String title,
    required List<String> options,
    required String currentValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ChoiceButton(
                      label: option,
                      selected: option == currentValue,
                      onTap: () => Navigator.of(context).pop(option),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addReminder() {
    final next = _defaultReminders().firstWhere(
      (reminder) => !_reminders.any((item) => item.label == reminder.label),
      orElse: () => const _MedicationReminder(
        label: '직접설정',
        time: TimeOfDay(hour: 9, minute: 0),
      ),
    );
    setState(() => _reminders.add(next));
  }

  void _removeReminder(int index) {
    if (_reminders.length == 1) return;
    setState(() => _reminders.removeAt(index));
  }

  Future<void> _save() async {
    if (widget.isPreview) {
      Navigator.of(context).pop(const _MedicationEditorResult.previewBlocked());
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_frequency == '직접입력' && _weekdays.isEmpty) {
      _showMessage('복용 요일을 선택해 주세요.');
      return;
    }
    if (_reminderEnabled && _reminders.isEmpty) {
      _showMessage('알림 시간을 1개 이상 등록해 주세요.');
      return;
    }

    var shouldEnableReminder = _reminderEnabled;
    if (shouldEnableReminder && !_notificationEnabled) {
      final granted = await _requestNotificationPermission();
      if (!mounted) return;
      shouldEnableReminder = granted;
    }

    final source = widget.initialMedication;
    final parsedDose = _parseDose(_doseAmount.text.trim());
    final doseAmount = parsedDose.amount;
    final doseUnit = parsedDose.unit == '정' ? _doseUnit : parsedDose.unit;
    final medication = _Medication(
      id: source?.id ?? DateTime.now().microsecondsSinceEpoch,
      name: _name.text.trim(),
      dose: '$doseAmount$doseUnit',
      frequency: _frequency,
      weekdays: _orderedWeekdays(_weekdays),
      reminderEnabled: shouldEnableReminder,
      reminders: List.unmodifiable(_reminders),
      memo: _memo.text.trim(),
    );
    Navigator.of(context).pop(_MedicationEditorResult.save(medication));
  }

  Future<bool> _requestNotificationPermission() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 권한'),
        content: const Text(
          '복약 알림을 받기 위해 알림 권한이 필요합니다. 알림 권한을 허용하시겠습니까?',
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
    if (!mounted || confirmed != true) {
      _showMessage('알림 권한이 없어 알림은 꺼짐으로 저장됩니다.');
      return false;
    }

    setState(() => _requestingPermission = true);
    try {
      final granted =
          await widget.notificationPermissionService.requestPermission();
      if (!mounted) return false;
      setState(() => _notificationEnabled = granted);
      widget.onNotificationPermissionChanged(granted);
      if (!granted) {
        _showMessage('알림 권한이 허용되지 않아 알림은 꺼짐으로 저장됩니다.');
      }
      return granted;
    } catch (_) {
      if (!mounted) return false;
      _showMessage('알림 권한 요청 중 문제가 발생했습니다.');
      return false;
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  Future<void> _delete() async {
    if (widget.isPreview) {
      Navigator.of(context).pop(const _MedicationEditorResult.previewBlocked());
      return;
    }
    final id = widget.initialMedication?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('약물 삭제'),
        content: const Text('삭제된 약물 기록은 복구되지 않습니다. 정말 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제하기'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(_MedicationEditorResult.delete(id));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        minChildSize: .55,
        maxChildSize: .95,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isNewMedication ? '약물 등록' : '약물 수정',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
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
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                      children: [
                        _TextField(
                          controller: _name,
                          label: '약물명',
                          hint: '예: 항구토제',
                          maxLength: 40,
                          validator: _requiredValidator,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _TextField(
                                controller: _doseAmount,
                                label: '복용량',
                                hint: '예: 1',
                                maxLength: 6,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: _doseAmountValidator,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 104,
                              child: _PickerField(
                                label: '복용 단위',
                                value: _doseUnit,
                                onTap: _pickDoseUnit,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        _PickerField(
                          label: '복용 주기',
                          value: _frequency,
                          onTap: _pickFrequency,
                        ),
                        if (_frequency == '직접입력') ...[
                          const SizedBox(height: 14),
                          _WeekdaySelector(
                            selected: _weekdays,
                            onChanged: (value) {
                              setState(() => _weekdays = value);
                            },
                          ),
                        ],
                        const SizedBox(height: 18),
                        _FormLabel(
                          label: '섭취 시간 알림',
                          requiredMark: true,
                          trailing: _InlineSwitch(
                            key: const ValueKey('medication-reminder-switch'),
                            value: _reminderEnabled,
                            onChanged: (value) =>
                                setState(() => _reminderEnabled = value),
                          ),
                        ),
                        if (_reminderEnabled) ...[
                          const SizedBox(height: 10),
                          ..._reminders.asMap().entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ReminderEditorRow(
                                    reminder: entry.value,
                                    canRemove: _reminders.length > 1,
                                    onPickLabel: () =>
                                        _pickReminderLabel(entry.key),
                                    onPickTime: () =>
                                        _pickReminderTime(entry.key),
                                    onRemove: () => _removeReminder(entry.key),
                                  ),
                                ),
                              ),
                          OutlinedButton.icon(
                            onPressed: _addReminder,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('알림 추가'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _TextField(
                          controller: _memo,
                          label: '메모',
                          hint: '복용 시 주의사항이나 함께 기록할 내용을 입력해 주세요.',
                          maxLength: 100,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.line),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: Row(
                      children: [
                        if (!_isNewMedication) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _requestingPermission ? null : _delete,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.muted,
                                side: const BorderSide(color: AppColors.line),
                              ),
                              child: const Text('삭제하기'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _requestingPermission ? null : _save,
                            child: Text(_requestingPermission ? '확인 중' : '저장'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({
    required this.label,
    this.requiredMark = false,
    this.trailing,
  });

  final String label;
  final bool requiredMark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                if (requiredMark)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormLabel(label: label, requiredMark: validator != null),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            maxLength: maxLength,
            maxLines: maxLines,
            textInputAction:
                maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
            keyboardType: keyboardType ??
                (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: maxLines == 1 ? 13 : 14,
              ),
              enabledBorder: _fieldBorder(AppColors.line),
              focusedBorder: _fieldBorder(AppColors.accent),
              errorBorder: _fieldBorder(AppColors.danger),
              focusedErrorBorder: _fieldBorder(AppColors.danger),
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label: label, requiredMark: true),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : Colors.white,
          border: Border.all(
            color: selected ? AppColors.accentLine : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.accent : AppColors.text,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FormLabel(label: '복용 요일', requiredMark: true),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _weekdayLabels.map(
            (day) {
              final isSelected = selected.contains(day);
              return GestureDetector(
                onTap: () {
                  final next = {...selected};
                  if (isSelected) {
                    next.remove(day);
                  } else {
                    next.add(day);
                  }
                  onChanged(next);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accentSoft : Colors.white,
                    border: Border.all(
                      color: isSelected ? AppColors.accentLine : AppColors.line,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    child: Text(
                      day,
                      style: TextStyle(
                        color: isSelected ? AppColors.accent : AppColors.text,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ).toList(),
        ),
      ],
    );
  }
}

class _ReminderEditorRow extends StatelessWidget {
  const _ReminderEditorRow({
    required this.reminder,
    required this.canRemove,
    required this.onPickLabel,
    required this.onPickTime,
    required this.onRemove,
  });

  final _MedicationReminder reminder;
  final bool canRemove;
  final VoidCallback onPickLabel;
  final VoidCallback onPickTime;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onPickLabel,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        reminder.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.muted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: onPickTime,
              child: Text(
                reminder.formattedTime,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: canRemove ? onRemove : null,
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.muted,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineSwitch extends StatelessWidget {
  const _InlineSwitch({
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
        width: 46,
        height: 27,
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
            width: 21,
            height: 21,
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

class _Medication {
  const _Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.weekdays,
    required this.reminderEnabled,
    required this.reminders,
    required this.memo,
  });

  factory _Medication.fromModel(data.Medication medication) {
    final shouldKeepReminders =
        medication.reminderEnabled || medication.frequency != '필요시';
    return _Medication(
      id: medication.id,
      name: medication.name,
      dose: medication.dose,
      frequency: medication.frequency,
      weekdays: medication.weekdays,
      reminderEnabled: medication.reminderEnabled,
      reminders: shouldKeepReminders
          ? medication.reminders.map(_MedicationReminder.fromModel).toList()
          : const [],
      memo: medication.memo,
    );
  }

  final int id;
  final String name;
  final String dose;
  final String frequency;
  final List<String> weekdays;
  final bool reminderEnabled;
  final List<_MedicationReminder> reminders;
  final String memo;

  String get summary {
    final parts = <String>[];
    if (frequency == '직접입력' && weekdays.isNotEmpty) {
      parts.add(weekdays.join('·'));
    } else {
      parts.add(frequency);
    }
    if (reminders.isNotEmpty) {
      parts.add(reminders.map((item) => item.summary).join(' · '));
    }
    parts.add(dose);
    if (memo.isNotEmpty) parts.add(memo);
    return parts.join(' · ');
  }

  _Medication copyWith({
    bool? reminderEnabled,
  }) {
    return _Medication(
      id: id,
      name: name,
      dose: dose,
      frequency: frequency,
      weekdays: weekdays,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminders: reminders,
      memo: memo,
    );
  }

  data.Medication toModel() {
    final shouldKeepReminders = reminderEnabled || frequency != '필요시';
    return data.Medication(
      id: id,
      name: name,
      dose: dose,
      frequency: frequency,
      weekdays: weekdays,
      reminderEnabled: reminderEnabled,
      reminders: shouldKeepReminders
          ? reminders
              .map((reminder) => reminder.toModel(enabled: reminderEnabled))
              .toList()
          : const [],
      memo: memo,
    );
  }
}

class _MedicationReminder {
  const _MedicationReminder({
    required this.label,
    required this.time,
  });

  factory _MedicationReminder.fromModel(data.MedicationReminder reminder) {
    final parts = reminder.time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return _MedicationReminder(
      label: reminder.label,
      time: TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59)),
    );
  }

  final String label;
  final TimeOfDay time;

  String get formattedTime =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String get summary => '$label $formattedTime';

  _MedicationReminder copyWith({
    String? label,
    TimeOfDay? time,
  }) {
    return _MedicationReminder(
      label: label ?? this.label,
      time: time ?? this.time,
    );
  }

  data.MedicationReminder toModel({required bool enabled}) {
    return data.MedicationReminder(
      label: label,
      time: formattedTime,
      enabled: enabled,
    );
  }
}

class _MedicationEditorResult {
  const _MedicationEditorResult.save(this.medication)
      : deletedId = null,
        previewBlocked = false;

  const _MedicationEditorResult.delete(this.deletedId)
      : medication = null,
        previewBlocked = false;

  const _MedicationEditorResult.previewBlocked()
      : medication = null,
        deletedId = null,
        previewBlocked = true;

  final _Medication? medication;
  final int? deletedId;
  final bool previewBlocked;
}

OutlineInputBorder _fieldBorder(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '필수 입력 항목입니다.';
  }
  return null;
}

String? _doseAmountValidator(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return '필수 입력 항목입니다.';
  final number = double.tryParse(_parseDose(trimmed).amount);
  if (number == null || number <= 0) {
    return '숫자로 입력해 주세요.';
  }
  return null;
}

class _ParsedDose {
  const _ParsedDose({
    required this.amount,
    required this.unit,
  });

  final String amount;
  final String unit;
}

_ParsedDose _parseDose(String dose) {
  final trimmed = dose.trim();
  if (trimmed.isEmpty) {
    return const _ParsedDose(amount: '', unit: '정');
  }

  final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)(.*)$').firstMatch(trimmed);
  if (match == null) {
    return _ParsedDose(amount: trimmed, unit: '정');
  }

  final amount = match.group(1) ?? '';
  final rawUnit = (match.group(2) ?? '').trim();
  final unit = _doseUnits.contains(rawUnit) ? rawUnit : '정';
  return _ParsedDose(amount: amount, unit: unit);
}

const _doseUnits = ['정', '알', '포', 'ml', 'mg'];

List<_MedicationReminder> _defaultReminders() {
  return const [
    _MedicationReminder(
      label: '아침식후',
      time: TimeOfDay(hour: 9, minute: 0),
    ),
    _MedicationReminder(
      label: '점심식후',
      time: TimeOfDay(hour: 13, minute: 0),
    ),
    _MedicationReminder(
      label: '저녁식후',
      time: TimeOfDay(hour: 19, minute: 0),
    ),
  ];
}

List<String> _orderedWeekdays(Set<String> values) {
  return _weekdayLabels.where(values.contains).toList();
}

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

const _reminderLabels = [
  '아침식전',
  '아침식후',
  '점심식전',
  '점심식후',
  '저녁식전',
  '저녁식후',
  '취침전',
  '직접설정',
];
