import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/symptom_record.dart';
import '../../services/health/step_sync_service.dart';

class SymptomScreen extends StatefulWidget {
  const SymptomScreen({
    super.key,
    this.hasRequiredInfo = true,
    this.isPreview = false,
    this.stepSyncEnabled = false,
    this.initialRecords = const [],
    this.stepSyncService,
    this.onStepSyncChanged,
    this.onRecordsChanged,
  });

  final bool hasRequiredInfo;
  final bool isPreview;
  final bool stepSyncEnabled;
  final List<SymptomRecord> initialRecords;
  final StepSyncService? stepSyncService;
  final ValueChanged<bool>? onStepSyncChanged;
  final ValueChanged<List<SymptomRecord>>? onRecordsChanged;

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  final _records = <DateTime, _SymptomRecord>{};
  late final StepSyncService _stepSyncService =
      widget.stepSyncService ?? PlatformStepSyncService();
  late var _stepSyncEnabled = widget.stepSyncEnabled;
  var _visibleMonth = _monthStart(DateTime.now());
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _syncInitialRecords();
  }

  @override
  void didUpdateWidget(covariant SymptomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepSyncEnabled != widget.stepSyncEnabled) {
      _stepSyncEnabled = widget.stepSyncEnabled;
    }
    if (oldWidget.initialRecords != widget.initialRecords) {
      _syncInitialRecords();
    }
  }

  void _syncInitialRecords() {
    _records
      ..clear()
      ..addEntries(
        widget.initialRecords.map(
          (record) => MapEntry(
            _dateOnly(record.date),
            _SymptomRecord.fromModel(record),
          ),
        ),
      );
  }

  Future<void> _openEditor(DateTime date, [_SymptomRecord? record]) async {
    if (!widget.hasRequiredInfo) {
      _showMessage('마이페이지의 사용자정보를 입력하세요.');
      return;
    }
    final result = await showModalBottomSheet<_SymptomEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SymptomEditorSheet(
        date: date,
        initialRecord: record,
        isPreview: widget.isPreview,
        stepSyncEnabled: _stepSyncEnabled,
        stepSyncService: _stepSyncService,
        onStepSyncChanged: (value) {
          if (mounted) setState(() => _stepSyncEnabled = value);
          widget.onStepSyncChanged?.call(value);
        },
      ),
    );

    if (!mounted || result == null) return;
    if (result.previewBlocked) {
      _showMessage('둘러보기에서는 기록이 저장되지 않습니다.');
      return;
    }
    if (result.record == null) return;
    setState(() {
      _records[_dateOnly(date)] = result.record!;
      _selectedDate = _dateOnly(date);
    });
    _notifyRecordsChanged();
    _showMessage('증상 기록을 저장했습니다.');
  }

  Future<void> _deleteRecord(DateTime date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('삭제된 기록은 복구되지 않습니다. 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _records.remove(_dateOnly(date)));
    _notifyRecordsChanged();
    _showMessage('증상 기록을 삭제했습니다.');
  }

  void _notifyRecordsChanged() {
    final records = _records.entries
        .map((entry) => entry.value.toModel(entry.key))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    widget.onRecordsChanged?.call(records);
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = _dateOnly(date));
  }

  void _moveMonth(int months) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + months,
      );
      _selectedDate = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _selectedDate;
    final selectedRecord =
        selectedDate == null ? null : _records[_dateOnly(selectedDate)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const SectionHeader(
          title: '증상 관리',
          subtitle: '회차별 생활반응과 주요 부작용을 기록합니다.',
        ),
        if (!widget.hasRequiredInfo) ...[
          const RequiredInfoBanner(),
          const SizedBox(height: 20),
        ],
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            children: [
              _CalendarHeader(
                visibleMonth: _visibleMonth,
                onMoveMonth: _moveMonth,
              ),
              const SizedBox(height: 18),
              _SymptomCalendar(
                visibleMonth: _visibleMonth,
                selectedDate: selectedDate,
                records: _records,
                onSelectDate: _selectDate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SelectedSymptomPanel(
          selectedDate: selectedDate,
          record: selectedRecord,
          onWrite: selectedDate == null || !widget.hasRequiredInfo
              ? null
              : () => _openEditor(selectedDate, selectedRecord),
          onDelete: selectedDate == null || selectedRecord == null
              ? null
              : () => _deleteRecord(selectedDate),
        ),
      ],
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.visibleMonth,
    required this.onMoveMonth,
  });

  final DateTime visibleMonth;
  final ValueChanged<int> onMoveMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MonthButton(label: '«', onTap: () => onMoveMonth(-12)),
        _MonthButton(label: '‹', onTap: () => onMoveMonth(-1)),
        Expanded(
          child: Text(
            '${visibleMonth.year}년 ${visibleMonth.month}월',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        _MonthButton(label: '›', onTap: () => onMoveMonth(1)),
        _MonthButton(label: '»', onTap: () => onMoveMonth(12)),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Text(
        label,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SymptomCalendar extends StatelessWidget {
  const _SymptomCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.records,
    required this.onSelectDate,
  });

  final DateTime visibleMonth;
  final DateTime? selectedDate;
  final Map<DateTime, _SymptomRecord> records;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final days = _calendarDays(visibleMonth);
    final weeks = [
      for (var start = 0; start < days.length; start += 7)
        days.sublist(start, start + 7),
    ];
    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: dayLabels
                  .map(
                    (label) => Expanded(
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.line),
                            right: BorderSide(color: AppColors.line),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: label == '일'
                                ? AppColors.danger
                                : AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            ...weeks.map(
              (week) {
                final rowHeight = _symptomWeekHeight(week, records);
                return SizedBox(
                  height: rowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: week.map(
                      (date) {
                        final key = _dateOnly(date);
                        final record = records[key];
                        return Expanded(
                          child: _SymptomDayCell(
                            key: ValueKey(
                              'symptom-day-${_formatDateKey(key)}',
                            ),
                            date: date,
                            isCurrentMonth: date.month == visibleMonth.month,
                            selected: selectedDate != null &&
                                _isSameDay(key, _dateOnly(selectedDate!)),
                            record: record,
                            onTap: () => onSelectDate(key),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

double _symptomWeekHeight(
  List<DateTime> week,
  Map<DateTime, _SymptomRecord> records,
) {
  var maxBadgeUnits = 0;
  for (final date in week) {
    final record = records[_dateOnly(date)];
    if (record == null) continue;
    final sideEffectUnits = record.visibleSideEffects
        .map(_sideEffectLineUnits)
        .fold<int>(0, (sum, units) => sum + units);
    final badgeUnits = 1 + sideEffectUnits;
    if (badgeUnits > maxBadgeUnits) maxBadgeUnits = badgeUnits;
  }
  if (maxBadgeUnits == 0) return 82;
  return (58 + maxBadgeUnits * 18).clamp(98, 196).toDouble();
}

int _sideEffectLineUnits(String label) {
  return 1;
}

class _SymptomDayCell extends StatelessWidget {
  const _SymptomDayCell({
    super.key,
    required this.date,
    required this.isCurrentMonth,
    required this.selected,
    required this.record,
    required this.onTap,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool selected;
  final _SymptomRecord? record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, _dateOnly(DateTime.now()));
    final isSunday = date.weekday == DateTime.sunday;
    final record = this.record;
    final cycleTone = record == null ? null : _cycleBadgeTone(record.cycleNo);
    return Material(
      color: selected ? AppColors.accentSoft : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 1.8 : .7,
            ),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 5, 2, 2),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${date.day}일',
                          style: TextStyle(
                            color: isCurrentMonth
                                ? (isSunday ? AppColors.danger : AppColors.text)
                                : AppColors.muted.withValues(alpha: .6),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 4),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 6, height: 6),
                          ),
                        ],
                      ],
                    ),
                    if (record != null) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: ClipRect(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CalendarBadge(
                                label: '${record.cycleNo}-${record.cycleDay}',
                                color: cycleTone!.foreground,
                                backgroundColor: cycleTone.background,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                minWidth: 34,
                                maxWidth: 56,
                                horizontalPadding: 5,
                                verticalPadding: 1.5,
                                maxLines: 1,
                                overflow: null,
                                fitText: true,
                              ),
                              const SizedBox(height: 3),
                              ...record.visibleSideEffects.map(
                                (effect) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: _CalendarBadge(
                                    label: effect,
                                    color: const Color(0xFF0B8F63),
                                    backgroundColor: const Color(0xFFE8F8EF),
                                    fontSize: effect.length >= 4 ? 8.5 : 10,
                                    fontWeight: FontWeight.w600,
                                    minWidth: 30,
                                    maxWidth: 56,
                                    horizontalPadding: 5,
                                    verticalPadding: 1.5,
                                    maxLines: 1,
                                    overflow: null,
                                    fitText: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleBadgeTone {
  const _CycleBadgeTone({
    required this.foreground,
    required this.background,
  });

  final Color foreground;
  final Color background;
}

_CycleBadgeTone _cycleBadgeTone(int cycleNo) {
  switch (cycleNo) {
    case 1:
      return const _CycleBadgeTone(
        foreground: Color(0xFFDB2777),
        background: Color(0xFFFCE7F3),
      );
    case 2:
      return const _CycleBadgeTone(
        foreground: Color(0xFF059669),
        background: Color(0xFFE7F8EF),
      );
    case 3:
      return const _CycleBadgeTone(
        foreground: Color(0xFF2563EB),
        background: Color(0xFFEFF6FF),
      );
    case 4:
      return const _CycleBadgeTone(
        foreground: Color(0xFF0F766E),
        background: Color(0xFFE0F7F4),
      );
    case 5:
      return const _CycleBadgeTone(
        foreground: Color(0xFF0891B2),
        background: Color(0xFFE0F7FA),
      );
    case 6:
      return const _CycleBadgeTone(
        foreground: Color(0xFF7C3AED),
        background: Color(0xFFF3E8FF),
      );
  }
  final hue = ((cycleNo <= 0 ? 1 : cycleNo) * 67 + 211) % 360;
  return _CycleBadgeTone(
    foreground: HSVColor.fromAHSV(1, hue.toDouble(), .72, .52).toColor(),
    background: HSVColor.fromAHSV(1, hue.toDouble(), .14, .98).toColor(),
  );
}

class _CalendarBadge extends StatelessWidget {
  const _CalendarBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.fontSize,
    required this.fontWeight,
    required this.minWidth,
    required this.maxWidth,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.maxLines,
    required this.overflow,
    required this.fitText,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double minWidth;
  final double maxWidth;
  final double horizontalPadding;
  final double verticalPadding;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool fitText;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: fitText
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: maxLines,
                    overflow: overflow,
                    textAlign: TextAlign.center,
                    softWrap: false,
                    style: TextStyle(
                      color: color,
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                    ),
                  ),
                )
              : Text(
                  label,
                  maxLines: maxLines,
                  overflow: overflow,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    color: color,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SelectedSymptomPanel extends StatelessWidget {
  const _SelectedSymptomPanel({
    required this.selectedDate,
    required this.record,
    required this.onWrite,
    required this.onDelete,
  });

  final DateTime? selectedDate;
  final _SymptomRecord? record;
  final VoidCallback? onWrite;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final date = selectedDate;
    final record = this.record;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date == null ? '날짜를 선택해 주세요' : _formatKoreanDate(date),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (date == null)
            const Text(
              '기록이 없는 날짜를 선택하면 증상기록하기 버튼이 표시됩니다.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else if (record == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  '입력된 내용이 없습니다.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
            )
          else
            _SymptomRecordSummary(record: record),
          if (date != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onWrite,
                    child: Text(record == null ? '증상기록하기' : '기록 수정하기'),
                  ),
                ),
                if (record != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDelete,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: AppColors.muted,
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('기록삭제하기'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SymptomRecordSummary extends StatelessWidget {
  const _SymptomRecordSummary({required this.record});

  final _SymptomRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(
          label: '▣ 항암 치료 정보',
          value: '${record.cycleNo}차 · ${record.cycleDay}일차',
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          child: Column(
            children: [
              _SummaryRow(label: '▤ 식사', value: record.mealAmount),
              const SizedBox(height: 10),
              _MealSummaryRow(label: '아침', value: record.breakfastMemo),
              _MealSummaryRow(label: '점심', value: record.lunchMemo),
              _MealSummaryRow(label: '저녁', value: record.dinnerMemo),
              if (record.extraMealMemo.trim().isNotEmpty)
                _MealSummaryRow(label: '기타', value: record.extraMealMemo),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryRow(label: '♢ 음수량', value: record.waterAmount),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryRow(
                label: '▥ 운동량',
                subLabel: '(*걸음수)',
                value: '${record.steps}보',
                valueColor: AppColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SummaryRow(
          label: '◎ 배변',
          value: record.bowel == '있음' && record.stoolStatus != null
              ? '${record.bowel} · ${record.stoolStatus}'
              : record.bowel,
        ),
        const SizedBox(height: 10),
        _SummaryRow(
          label: '△ 주요 부작용',
          trailing: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: record.sideEffects
                .map((effect) => _SmallTag(label: effect))
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '▤ 주요 증상',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                record.note.trim().isEmpty ? '입력된 내용이 없습니다.' : record.note,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    this.subLabel,
    this.value,
    this.trailing,
    this.valueColor,
  });

  final String label;
  final String? subLabel;
  final String? value;
  final Widget? trailing;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: label),
                  if (subLabel != null)
                    TextSpan(
                      text: subLabel,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null)
            Flexible(child: trailing!)
          else
            Text(
              value ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _MealSummaryRow extends StatelessWidget {
  const _MealSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0B8F63),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SymptomEditorSheet extends StatefulWidget {
  const _SymptomEditorSheet({
    required this.date,
    required this.initialRecord,
    required this.isPreview,
    required this.stepSyncEnabled,
    required this.stepSyncService,
    required this.onStepSyncChanged,
  });

  final DateTime date;
  final _SymptomRecord? initialRecord;
  final bool isPreview;
  final bool stepSyncEnabled;
  final StepSyncService stepSyncService;
  final ValueChanged<bool> onStepSyncChanged;

  @override
  State<_SymptomEditorSheet> createState() => _SymptomEditorSheetState();
}

class _SymptomEditorSheetState extends State<_SymptomEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _cycleNoKey = GlobalKey();
  final _cycleDayKey = GlobalKey();
  final _mealAmountKey = GlobalKey();
  final _waterAmountKey = GlobalKey();
  final _stepsKey = GlobalKey();
  final _bowelKey = GlobalKey();
  final _stoolStatusKey = GlobalKey();
  final _sideEffectsKey = GlobalKey();
  late final _cycleNo = TextEditingController(
    text: widget.initialRecord?.cycleNo.toString() ?? '',
  );
  late final _cycleDay = TextEditingController(
    text: widget.initialRecord?.cycleDay.toString() ?? '',
  );
  late final _breakfast = TextEditingController(
    text: widget.initialRecord?.breakfastMemo ?? '',
  );
  late final _lunch = TextEditingController(
    text: widget.initialRecord?.lunchMemo ?? '',
  );
  late final _dinner = TextEditingController(
    text: widget.initialRecord?.dinnerMemo ?? '',
  );
  late final _extraMeal = TextEditingController(
    text: widget.initialRecord?.extraMealMemo ?? '',
  );
  late final _steps = TextEditingController(
    text: widget.initialRecord?.steps.toString() ?? '',
  );
  late final _note = TextEditingController(
    text: widget.initialRecord?.note ?? '',
  );
  late String? _mealAmount = widget.initialRecord?.mealAmount;
  late String? _waterAmount = widget.initialRecord?.waterAmount;
  late String? _bowel = widget.initialRecord?.bowel;
  late String? _stoolStatus = widget.initialRecord?.stoolStatus;
  late final _sideEffects = {...?widget.initialRecord?.sideEffects};
  late var _stepSyncEnabled = widget.stepSyncEnabled;
  late var _stepsSource = widget.initialRecord?.stepsSource ??
      (widget.stepSyncEnabled ? '연동' : '수동');
  var _stepSyncInProgress = false;
  String? _validationMessage;

  @override
  void dispose() {
    _scrollController.dispose();
    _cycleNo.dispose();
    _cycleDay.dispose();
    _breakfast.dispose();
    _lunch.dispose();
    _dinner.dispose();
    _extraMeal.dispose();
    _steps.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickMealAmount() async {
    final scrollOffset = _currentScrollOffset();
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await _showOptionSheet(
      title: '식사량',
      options: _mealOptions,
      currentValue: _mealAmount,
    );
    if (selected != null) {
      setState(() => _mealAmount = selected);
      _restoreScrollOffset(scrollOffset, repeat: true);
    }
  }

  Future<void> _pickWaterAmount() async {
    final scrollOffset = _currentScrollOffset();
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await _showOptionSheet(
      title: '음수량',
      options: _waterOptions,
      currentValue: _waterAmount,
    );
    if (selected != null) {
      setState(() => _waterAmount = selected);
      _restoreScrollOffset(scrollOffset, repeat: true);
    }
  }

  double _currentScrollOffset() {
    return _scrollController.hasClients ? _scrollController.offset : 0;
  }

  void _restoreScrollOffset(double offset, {bool repeat = false}) {
    void jump() {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      final safeOffset =
          offset.clamp(position.minScrollExtent, position.maxScrollExtent);
      _scrollController.jumpTo(safeOffset);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      if (!repeat) return;
      Future<void>.delayed(const Duration(milliseconds: 60), jump);
      Future<void>.delayed(const Duration(milliseconds: 160), jump);
    });
  }

  Future<String?> _showOptionSheet({
    required String title,
    required List<String> options,
    required String? currentValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F1F2937),
                    blurRadius: 36,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.line,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('닫기'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(10),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = option == currentValue;
                        return _SheetOptionButton(
                          label: option,
                          selected: selected,
                          onTap: () => Navigator.of(context).pop(option),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _enableStepSync() async {
    if (_stepSyncInProgress || _stepSyncEnabled) return;
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
    if (!mounted || confirmed != true) return;
    setState(() => _stepSyncInProgress = true);
    try {
      final granted = await widget.stepSyncService.requestPermission();
      if (!mounted) return;
      setState(() {
        _stepSyncEnabled = granted;
        _stepsSource = granted ? '연동' : '수동';
      });
      widget.onStepSyncChanged(granted);
      if (granted) {
        final steps = await widget.stepSyncService.readTodaySteps();
        if (!mounted) return;
        if (steps != null) _steps.text = steps.toString();
        _showMessage('걸음수 연동 권한이 허용되었습니다.');
      } else {
        _showMessage('걸음수 연동 권한이 허용되지 않았습니다.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('걸음수 연동 중 문제가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _stepSyncInProgress = false);
    }
  }

  void _selectBowel(String value) {
    setState(() {
      _bowel = value;
      if (value == '없음') _stoolStatus = null;
    });
  }

  void _toggleSideEffect(String value) {
    setState(() {
      if (value == '없음') {
        if (_sideEffects.contains('없음')) {
          _sideEffects.clear();
        } else {
          _sideEffects
            ..clear()
            ..add('없음');
        }
        return;
      }
      _sideEffects.remove('없음');
      if (!_sideEffects.add(value)) _sideEffects.remove(value);
    });
  }

  void _save() {
    if (widget.isPreview) {
      Navigator.of(context).pop(const _SymptomEditorResult.previewBlocked());
      return;
    }
    final missingMessage = _firstMissingRequiredMessage();
    if (missingMessage != null) {
      _showValidationToast(missingMessage);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showValidationToast(
        const _ValidationMessage('입력값을 다시 확인해 주세요.', null),
      );
      return;
    }

    Navigator.of(context).pop(
      _SymptomEditorResult.save(
        _SymptomRecord(
          cycleNo: int.parse(_cycleNo.text),
          cycleDay: int.parse(_cycleDay.text),
          mealAmount: _mealAmount!,
          breakfastMemo: _breakfast.text.trim(),
          lunchMemo: _lunch.text.trim(),
          dinnerMemo: _dinner.text.trim(),
          extraMealMemo: _extraMeal.text.trim(),
          waterAmount: _waterAmount!,
          steps: int.parse(_steps.text),
          stepsSource: _stepsSource,
          bowel: _bowel!,
          stoolStatus: _bowel == '있음' ? _stoolStatus : null,
          sideEffects: _orderedSideEffects(_sideEffects),
          note: _note.text.trim(),
        ),
      ),
    );
  }

  _ValidationMessage? _firstMissingRequiredMessage() {
    if (_cycleNo.text.trim().isEmpty) {
      return _ValidationMessage('항암 회차를 입력해주세요.', _cycleNoKey);
    }
    if (_cycleDay.text.trim().isEmpty) {
      return _ValidationMessage('진행일차를 입력해주세요.', _cycleDayKey);
    }
    if (_mealAmount == null) {
      return _ValidationMessage('식사량을 입력해주세요.', _mealAmountKey);
    }
    if (_waterAmount == null) {
      return _ValidationMessage('음수량을 입력해주세요.', _waterAmountKey);
    }
    if (_steps.text.trim().isEmpty) {
      return _ValidationMessage('운동량을 입력해주세요.', _stepsKey);
    }
    if (_bowel == null) {
      return _ValidationMessage('배변 유무를 입력해주세요.', _bowelKey);
    }
    if (_bowel == '있음' && _stoolStatus == null) {
      return _ValidationMessage('배변 상태를 입력해주세요.', _stoolStatusKey);
    }
    if (_sideEffects.isEmpty) {
      return _ValidationMessage('주요부작용을 입력해주세요.', _sideEffectsKey);
    }
    return null;
  }

  void _showValidationToast(_ValidationMessage message) {
    setState(() => _validationMessage = message.text);
    final key = message.anchorKey;
    if (key != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = key.currentContext;
        if (context == null) return;
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: .08,
        );
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '증상 기록',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
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
              const Divider(height: 1),
              if (_validationMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _SheetToast(
                    message: _validationMessage!,
                    onClose: () => setState(() => _validationMessage = null),
                  ),
                ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    key: const ValueKey('symptom-editor-scroll'),
                    controller: _scrollController,
                    scrollCacheExtent: const ScrollCacheExtent.pixels(2400),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    children: [
                      KeyedSubtree(
                        key: _cycleNoKey,
                        child: _NumberField(
                          label: '항암 회차',
                          controller: _cycleNo,
                          placeholder: '진행회차를 숫자로 입력하세요.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      KeyedSubtree(
                        key: _cycleDayKey,
                        child: _NumberField(
                          label: '진행일차',
                          controller: _cycleDay,
                          placeholder: '진행일차를 숫자로 입력하세요.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      KeyedSubtree(
                        key: _mealAmountKey,
                        child: _SheetField(
                          label: '식사량',
                          value: _mealAmount ?? '선택',
                          empty: _mealAmount == null,
                          onTap: _pickMealAmount,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MemoField(
                        label: '아침 식사 내용 (선택)',
                        controller: _breakfast,
                        maxLength: 100,
                        placeholder: '식사 내용을 기록하세요. AI분석에 활용됩니다.',
                      ),
                      _MemoField(
                        label: '점심 식사 내용 (선택)',
                        controller: _lunch,
                        maxLength: 100,
                        placeholder: '식사 내용을 기록하세요. AI분석에 활용됩니다.',
                      ),
                      _MemoField(
                        label: '저녁 식사 내용 (선택)',
                        controller: _dinner,
                        maxLength: 100,
                        placeholder: '식사 내용을 기록하세요. AI분석에 활용됩니다.',
                      ),
                      _MemoField(
                        label: '기타 식사 내용 (선택)',
                        controller: _extraMeal,
                        maxLength: 100,
                        placeholder:
                            '아침, 점심, 저녁 외의 섭취한 식사를 기록하세요. AI분석에 활용됩니다.',
                      ),
                      KeyedSubtree(
                        key: _waterAmountKey,
                        child: _SheetField(
                          label: '음수량',
                          value: _waterAmount ?? '선택',
                          empty: _waterAmount == null,
                          onTap: _pickWaterAmount,
                        ),
                      ),
                      const SizedBox(height: 16),
                      KeyedSubtree(
                        key: _stepsKey,
                        child: _StepsField(
                          controller: _steps,
                          source: _stepsSource,
                          readOnly: _stepSyncEnabled,
                        ),
                      ),
                      if (!_stepSyncEnabled) ...[
                        const SizedBox(height: 10),
                        _StepSyncPanel(
                          inProgress: _stepSyncInProgress,
                          onTap: _enableStepSync,
                        ),
                      ],
                      const SizedBox(height: 18),
                      KeyedSubtree(
                        key: _bowelKey,
                        child: const _FieldLabel.required(
                          '배변 유무',
                          key: ValueKey('symptom-label-bowel'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ChoiceButton(
                              label: '있음',
                              selected: _bowel == '있음',
                              onTap: () => _selectBowel('있음'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ChoiceButton(
                              label: '없음',
                              selected: _bowel == '없음',
                              onTap: () => _selectBowel('없음'),
                            ),
                          ),
                        ],
                      ),
                      if (_bowel == '있음') ...[
                        const SizedBox(height: 18),
                        KeyedSubtree(
                          key: _stoolStatusKey,
                          child: const _FieldLabel.required(
                            '배변 상태',
                            key: ValueKey('symptom-label-stool'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ChoiceWrap(
                          options: _stoolOptions,
                          selected: {_stoolStatus},
                          onTap: (value) =>
                              setState(() => _stoolStatus = value),
                        ),
                      ],
                      const SizedBox(height: 18),
                      KeyedSubtree(
                        key: _sideEffectsKey,
                        child: const _FieldLabel.required(
                          '주요부작용',
                          key: ValueKey('symptom-label-side-effects'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ChoiceWrap(
                        options: _sideEffectOptions,
                        selected: _sideEffects,
                        disabledWhenNone: true,
                        onTap: _toggleSideEffect,
                      ),
                      const SizedBox(height: 18),
                      _MemoField(
                        label: '주요증상 (선택)',
                        controller: _note,
                        maxLength: 500,
                        placeholder:
                            '작성된 내용을 참고하여 AI분석을 진행합니다. 기록하고싶은 내용을 자세히 작성해주세요.',
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(92, 44),
                    ),
                    child: const Text('저장'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidationMessage {
  const _ValidationMessage(this.text, this.anchorKey);

  final String text;
  final GlobalKey? anchorKey;
}

class _SheetToast extends StatelessWidget {
  const _SheetToast({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        border: Border.all(color: AppColors.accent.withValues(alpha: .28)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.muted,
              tooltip: '닫기',
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('symptom-sheet-$label'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel.required(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration(placeholder),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            if (number == null) return '필수';
            if (number < 1 || number > 100) return '1~100';
            return null;
          },
        ),
      ],
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.value,
    required this.empty,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel.required(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: _inputDecoration(''),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: empty ? AppColors.muted : AppColors.text,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetOptionButton extends StatelessWidget {
  const _SheetOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppColors.accent : AppColors.text,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoField extends StatefulWidget {
  const _MemoField({
    required this.label,
    required this.controller,
    required this.maxLength,
    required this.placeholder,
  });

  final String label;
  final TextEditingController controller;
  final int maxLength;
  final String placeholder;

  @override
  State<_MemoField> createState() => _MemoFieldState();
}

class _MemoFieldState extends State<_MemoField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _MemoField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(widget.label),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.controller,
            maxLength: widget.maxLength,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: _inputDecoration(widget.placeholder).copyWith(
              counterText: '',
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${widget.controller.text.length}/${widget.maxLength}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsField extends StatelessWidget {
  const _StepsField({
    required this.controller,
    required this.source,
    required this.readOnly,
  });

  final TextEditingController controller;
  final String source;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel.required('운동량'),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('symptom-steps-field'),
          controller: controller,
          readOnly: readOnly,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration('걸음수를 입력하세요').copyWith(
            suffixText: source,
            suffixStyle: TextStyle(
              color: readOnly ? AppColors.accent : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            if (number == null) return '필수';
            if (number < 0) return '확인';
            return null;
          },
        ),
      ],
    );
  }
}

class _StepSyncPanel extends StatelessWidget {
  const _StepSyncPanel({required this.inProgress, required this.onTap});

  final bool inProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '걸음수 연동 꺼짐',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '휴대폰의 걸음수를 불러오려면 연동을 활성화하세요.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: inProgress ? null : onTap,
              child: Text(inProgress ? '요청 중' : '연동하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.onTap,
    this.disabledWhenNone = false,
  });

  final List<String> options;
  final Set<String?> selected;
  final ValueChanged<String> onTap;
  final bool disabledWhenNone;

  @override
  Widget build(BuildContext context) {
    final noneSelected = selected.contains('없음');
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 10,
          children: options.map((option) {
            final disabled = disabledWhenNone && noneSelected && option != '없음';
            return SizedBox(
              width: itemWidth,
              child: _ChoiceButton(
                label: option,
                selected: selected.contains(option),
                disabled: disabled,
                onTap: disabled ? null : () => onTap(option),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = disabled
        ? AppColors.muted.withValues(alpha: .42)
        : selected
            ? AppColors.accent
            : AppColors.text;
    final borderColor = disabled
        ? AppColors.line.withValues(alpha: .55)
        : selected
            ? AppColors.accentLine
            : AppColors.line;
    final backgroundColor = disabled
        ? const Color(0xFFFAFAFA)
        : selected
            ? AppColors.accentSoft
            : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {super.key, this.required = false});

  const _FieldLabel.required(String label, {Key? key})
      : this(label, key: key, required: true);

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
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
    );
  }
}

class _SymptomRecord {
  const _SymptomRecord({
    required this.cycleNo,
    required this.cycleDay,
    required this.mealAmount,
    required this.breakfastMemo,
    required this.lunchMemo,
    required this.dinnerMemo,
    required this.extraMealMemo,
    required this.waterAmount,
    required this.steps,
    required this.stepsSource,
    required this.bowel,
    required this.stoolStatus,
    required this.sideEffects,
    required this.note,
  });

  factory _SymptomRecord.fromModel(SymptomRecord record) {
    return _SymptomRecord(
      cycleNo: record.cycleNo,
      cycleDay: record.cycleDay,
      mealAmount: record.mealAmount,
      breakfastMemo: record.breakfastMemo,
      lunchMemo: record.lunchMemo,
      dinnerMemo: record.dinnerMemo,
      extraMealMemo: record.extraMealMemo,
      waterAmount: record.waterAmount,
      steps: record.steps,
      stepsSource: record.stepsSource,
      bowel: record.bowel,
      stoolStatus: record.stoolStatus.isEmpty ? null : record.stoolStatus,
      sideEffects: record.sideEffects,
      note: record.note,
    );
  }

  final int cycleNo;
  final int cycleDay;
  final String mealAmount;
  final String breakfastMemo;
  final String lunchMemo;
  final String dinnerMemo;
  final String extraMealMemo;
  final String waterAmount;
  final int steps;
  final String stepsSource;
  final String bowel;
  final String? stoolStatus;
  final List<String> sideEffects;
  final String note;

  List<String> get visibleSideEffects =>
      sideEffects.where((effect) => effect != '없음').take(3).toList();

  SymptomRecord toModel(DateTime date) {
    return SymptomRecord(
      date: date,
      cycleNo: cycleNo,
      cycleDay: cycleDay,
      mealAmount: mealAmount,
      breakfastMemo: breakfastMemo,
      lunchMemo: lunchMemo,
      dinnerMemo: dinnerMemo,
      extraMealMemo: extraMealMemo,
      waterAmount: waterAmount,
      steps: steps,
      stepsSource: stepsSource,
      bowel: bowel,
      stoolStatus: stoolStatus ?? '',
      sideEffects: sideEffects,
      note: note,
    );
  }
}

class _SymptomEditorResult {
  const _SymptomEditorResult._({this.record, this.previewBlocked = false});

  const _SymptomEditorResult.previewBlocked() : this._(previewBlocked: true);

  const _SymptomEditorResult.save(_SymptomRecord record)
      : this._(record: record);

  final _SymptomRecord? record;
  final bool previewBlocked;
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.muted),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.accent),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

List<DateTime> _calendarDays(DateTime visibleMonth) {
  final first = DateTime(visibleMonth.year, visibleMonth.month);
  final start = first.subtract(Duration(days: first.weekday - 1));
  return List.generate(42, (index) => start.add(Duration(days: index)));
}

String _formatKoreanDate(DateTime date) {
  return '${date.year}년 ${date.month.toString().padLeft(2, '0')}월 ${date.day.toString().padLeft(2, '0')}일';
}

List<String> _orderedSideEffects(Set<String> values) {
  if (values.contains('없음')) return const ['없음'];
  return _sideEffectOptions.where(values.contains).toList();
}

String _formatDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

const _mealOptions = ['평소와 같음', '평소의 절반', '평소의 1/4', '전혀 못 먹음'];
const _waterOptions = ['500ml 이하', '500ml~1L', '1~1.5L', '2L 이상'];
const _stoolOptions = ['정상', '설사', '묽은변', '딱딱한변', '혈변'];
const _sideEffectOptions = [
  '없음',
  '구토',
  '오심',
  '발열',
  '안면홍조',
  '오한',
  '손발저림',
  '두통',
  '어지러움',
  '설사',
  '변비',
  '복통',
  '복부팽만',
  '탈모',
  '발진',
  '가려움',
  '근육통',
  '피로',
  '식욕저하',
  '졸림',
];
