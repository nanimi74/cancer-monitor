import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({
    super.key,
    this.hasRequiredInfo = true,
    this.isPreview = false,
    this.heightCm,
  });

  final bool hasRequiredInfo;
  final bool isPreview;
  final double? heightCm;

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final _records = <DateTime, double>{};
  late var _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late var _selectedDate = _dateOnly(DateTime.now());
  var _range = _WeightRange.recent30;

  List<MapEntry<DateTime, double>> get _sortedRecords {
    final values = _records.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return values;
  }

  MapEntry<DateTime, double>? get _latestRecord {
    if (_records.isEmpty) return null;
    return _sortedRecords.last;
  }

  void _moveMonth(int monthDelta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + monthDelta,
      );
    });
  }

  Future<void> _openWeightEditor(DateTime date) async {
    final day = _dateOnly(date);
    setState(() => _selectedDate = day);

    if (!widget.hasRequiredInfo) {
      _showMessage('마이페이지의 사용자정보를 입력하세요.');
      return;
    }

    final result = await showModalBottomSheet<_WeightEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WeightEditorSheet(
        date: day,
        initialWeight: _records[day],
        isPreview: widget.isPreview,
      ),
    );

    if (!mounted || result == null) return;
    if (result.previewBlocked) {
      _showMessage('둘러보기에서는 기록이 저장되지 않습니다.');
      return;
    }
    setState(() {
      if (result.deleted) {
        _records.remove(day);
      } else if (result.weightKg != null) {
        _records[day] = result.weightKg!;
      }
    });
    _showMessage(result.deleted ? '체중 기록이 삭제되었습니다.' : '체중 기록이 저장되었습니다.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latestRecord;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
      children: [
        const SectionHeader(
          title: '체중 관리',
          subtitle: '최근 체중과 사용자정보의 키를 기준으로 BMI를 계산하고, 기간별 체중 변화를 확인합니다.',
        ),
        if (!widget.hasRequiredInfo) ...[
          const RequiredInfoBanner(),
          const SizedBox(height: 14),
        ],
        if (latest != null && widget.heightCm != null) ...[
          _BmiCard(
            latest: latest,
            heightCm: widget.heightCm!,
          ),
          const SizedBox(height: 14),
        ],
        if (_weightAdvice(latest) case final advice?) ...[
          _WeightAdviceCard(advice: advice),
          const SizedBox(height: 14),
        ],
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: _WeightCalendar(
            visibleMonth: _visibleMonth,
            selectedDate: _selectedDate,
            records: _records,
            onMoveMonth: _moveMonth,
            onSelectDate: _openWeightEditor,
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: _WeightChartSection(
            range: _range,
            records: _chartRecords(),
            onRangeChanged: (value) => setState(() => _range = value),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'BMI와 체중 변화 안내는 참고용 정보이며,\n의학적 진단이나 치료 결정을 대체하지 않습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.45),
        ),
      ],
    );
  }

  List<MapEntry<DateTime, double>> _chartRecords() {
    final latest = _latestRecord?.key ?? _dateOnly(DateTime.now());
    final start = switch (_range) {
      _WeightRange.recent30 => latest.subtract(const Duration(days: 29)),
      _WeightRange.recent90 => latest.subtract(const Duration(days: 89)),
      _WeightRange.custom => DateTime(latest.year, latest.month),
    };
    return _sortedRecords
        .where((item) => !item.key.isBefore(start) && !item.key.isAfter(latest))
        .toList();
  }

  _WeightAdvice? _weightAdvice(MapEntry<DateTime, double>? latest) {
    if (latest == null || _records.length < 2) return null;
    final first = _sortedRecords.first;
    final change = ((latest.value - first.value) / first.value) * 100;
    final periodDays = latest.key.difference(first.key).inDays.abs();
    final weightDelta = latest.value - first.value;
    if (change <= -5) {
      return _WeightAdvice(
        lead: '기준 체중 대비 ',
        highlight: '${change.abs().toStringAsFixed(1)}% 감소',
        tail: '가 확인됩니다.',
      );
    }
    if (widget.heightCm != null) {
      final bmi = _bmi(latest.value, widget.heightCm!);
      if (bmi < 20 && change <= -2) {
        return _WeightAdvice(
          lead: 'BMI 20 미만에서 ',
          highlight: '${change.abs().toStringAsFixed(1)}% 감소',
          tail: '가 확인됩니다.',
        );
      }
    }
    if (periodDays <= 7 && (change >= 3 || weightDelta >= 1.5)) {
      return _WeightAdvice(
        lead: '최근 ${periodDays == 0 ? 1 : periodDays}일 ',
        highlight: '${change.toStringAsFixed(1)}% 증가',
        tail: '가 확인됩니다.\n부종, 복부팽만, 숨참이 있으면 확인이 필요합니다.',
      );
    }
    return null;
  }
}

class _BmiCard extends StatelessWidget {
  const _BmiCard({
    required this.latest,
    required this.heightCm,
  });

  final MapEntry<DateTime, double> latest;
  final double heightCm;

  @override
  Widget build(BuildContext context) {
    final bmi = _bmi(latest.value, heightCm);
    final status = _bmiStatus(bmi);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '현재 BMI '),
                TextSpan(
                  text: bmi.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                TextSpan(text: ' · ${status.emoji} ${status.label}'),
              ],
            ),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status.description,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '최근 체중 ${latest.value.toStringAsFixed(1)}kg · 마지막 입력일 ${_formatDate(latest.key)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _WeightAdviceCard extends StatelessWidget {
  const _WeightAdviceCard({required this.advice});

  final _WeightAdvice advice;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.dangerSoft,
      borderColor: const Color(0xFFFFB9B2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🚨 체중 변화 상담 권고',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: advice.lead),
                TextSpan(
                  text: advice.highlight,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: '${advice.tail}\n'),
                const TextSpan(
                  text: '의료진과 상담해 주세요.',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightCalendar extends StatelessWidget {
  const _WeightCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.records,
    required this.onMoveMonth,
    required this.onSelectDate,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Map<DateTime, double> records;
  final ValueChanged<int> onMoveMonth;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final days = _calendarDays(visibleMonth);
    return Column(
      children: [
        Row(
          children: [
            _MonthButton(label: '«', onTap: () => onMoveMonth(-12)),
            _MonthButton(label: '‹', onTap: () => onMoveMonth(-1)),
            Expanded(
              child: Center(
                child: Text(
                  '${visibleMonth.year}년 ${visibleMonth.month}월',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _MonthButton(label: '›', onTap: () => onMoveMonth(1)),
            _MonthButton(label: '»', onTap: () => onMoveMonth(12)),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children: const [
                    _WeekdayLabel('월'),
                    _WeekdayLabel('화'),
                    _WeekdayLabel('수'),
                    _WeekdayLabel('목'),
                    _WeekdayLabel('금'),
                    _WeekdayLabel('토'),
                    _WeekdayLabel('일', sunday: true),
                  ],
                ),
                GridView.builder(
                  itemCount: days.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: .9,
                  ),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    return _CalendarDayCell(
                      key: ValueKey('weight-day-${_formatDate(day)}'),
                      date: day,
                      inMonth: day.month == visibleMonth.month,
                      selected: _sameDay(day, selectedDate),
                      today: _sameDay(day, DateTime.now()),
                      weight: records[_dateOnly(day)],
                      onTap: () => onSelectDate(day),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
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
      icon: Text(
        label,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label, {this.sunday = false});

  final String label;
  final bool sunday;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: sunday ? AppColors.danger : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    super.key,
    required this.date,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.weight,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool selected;
  final bool today;
  final double? weight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sunday = date.weekday == DateTime.sunday;
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : Colors.white,
          border: Border(
            top: const BorderSide(color: AppColors.line),
            right: BorderSide(
              color: date.weekday == DateTime.sunday
                  ? Colors.transparent
                  : AppColors.line,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 7,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: !inMonth
                      ? AppColors.muted.withValues(alpha: .65)
                      : sunday
                          ? AppColors.danger
                          : AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (today)
              const Positioned(
                top: 31,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 5, height: 5),
                ),
              ),
            Positioned(
              bottom: 7,
              child: weight != null
                  ? Text(
                      '${weight!.toStringAsFixed(1)}kg',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : const Text(
                      '+',
                      style: TextStyle(
                        color: Color(0xFFC5CDD8),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightChartSection extends StatelessWidget {
  const _WeightChartSection({
    required this.range,
    required this.records,
    required this.onRangeChanged,
  });

  final _WeightRange range;
  final List<MapEntry<DateTime, double>> records;
  final ValueChanged<_WeightRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '체중 변화 그래프',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _RangeButton(
              label: '최근 30일',
              selected: range == _WeightRange.recent30,
              onTap: () => onRangeChanged(_WeightRange.recent30),
            ),
            const SizedBox(width: 8),
            _RangeButton(
              label: '최근 90일',
              selected: range == _WeightRange.recent90,
              onTap: () => onRangeChanged(_WeightRange.recent90),
            ),
            const SizedBox(width: 8),
            _RangeButton(
              label: '기간 설정',
              selected: range == _WeightRange.custom,
              onTap: () => onRangeChanged(_WeightRange.custom),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 210,
          width: double.infinity,
          child: records.length < 2
              ? const _ChartEmptyState()
              : CustomPaint(
                  painter: _WeightChartPainter(records),
                  child: const SizedBox.expand(),
                ),
        ),
      ],
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 38),
          foregroundColor: selected ? Colors.white : AppColors.text,
          backgroundColor: selected ? AppColors.accent : Colors.white,
          side: BorderSide(
            color: selected ? AppColors.accent : AppColors.line,
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            '그래프를 그릴 체중 기록이 부족합니다.\n선택한 기간에 2개 이상의 체중 기록이 필요합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  const _WeightChartPainter(this.records);

  final List<MapEntry<DateTime, double>> records;

  @override
  void paint(Canvas canvas, Size size) {
    final values = records.map((item) => item.value).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(maxValue - minValue, .8);
    const top = 18.0;
    final bottom = size.height - 28;
    const left = 10.0;
    final right = size.width - 10;

    final gridPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i += 1) {
      final y = top + (bottom - top) * (i / 3);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    Offset point(int index) {
      final x = left + (right - left) * (index / (records.length - 1));
      final normalized = (records[index].value - minValue) / range;
      final y = bottom - normalized * (bottom - top);
      return Offset(x, y);
    }

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var index = 1; index < records.length; index += 1) {
      path.lineTo(point(index).dx, point(index).dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(point(records.length - 1).dx, bottom)
      ..lineTo(point(0).dx, bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = AppColors.accent.withValues(alpha: .12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var index = 0; index < records.length; index += 1) {
      final p = point(index);
      canvas
        ..drawCircle(p, 5, Paint()..color = Colors.white)
        ..drawCircle(
          p,
          5,
          Paint()
            ..color = AppColors.accent
            ..strokeWidth = 2.2
            ..style = PaintingStyle.stroke,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      oldDelegate.records != records;
}

class _WeightEditorSheet extends StatefulWidget {
  const _WeightEditorSheet({
    required this.date,
    required this.initialWeight,
    required this.isPreview,
  });

  final DateTime date;
  final double? initialWeight;
  final bool isPreview;

  @override
  State<_WeightEditorSheet> createState() => _WeightEditorSheetState();
}

class _WeightEditorSheetState extends State<_WeightEditorSheet> {
  late final _controller = TextEditingController(
    text: widget.initialWeight?.toStringAsFixed(1) ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.isPreview) {
      Navigator.of(context).pop(const _WeightEditorResult.previewBlocked());
      return;
    }
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value <= 0) return;
    Navigator.of(context).pop(_WeightEditorResult.saved(value));
  }

  void _delete() {
    if (widget.isPreview) {
      Navigator.of(context).pop(const _WeightEditorResult.previewBlocked());
      return;
    }
    Navigator.of(context).pop(const _WeightEditorResult.deleted());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_formatDate(widget.date)} 체중',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '체중(kg)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,1}')),
                  ],
                  decoration: InputDecoration(
                    hintText: '체중을 입력하세요',
                    suffixText: 'kg',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (widget.initialWeight != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: Color(0xFFFFC8C2)),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('삭제'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.isPreview ? null : _save,
                        child: const Text('저장'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _WeightRange { recent30, recent90, custom }

class _WeightEditorResult {
  const _WeightEditorResult._({
    this.weightKg,
    this.deleted = false,
    this.previewBlocked = false,
  });

  const _WeightEditorResult.previewBlocked() : this._(previewBlocked: true);

  const _WeightEditorResult.deleted() : this._(deleted: true);

  const _WeightEditorResult.saved(double weightKg) : this._(weightKg: weightKg);

  final double? weightKg;
  final bool deleted;
  final bool previewBlocked;
}

class _BmiStatus {
  const _BmiStatus({
    required this.label,
    required this.emoji,
    required this.description,
  });

  final String label;
  final String emoji;
  final String description;
}

class _WeightAdvice {
  const _WeightAdvice({
    required this.lead,
    required this.highlight,
    required this.tail,
  });

  final String lead;
  final String highlight;
  final String tail;
}

double _bmi(double weightKg, double heightCm) {
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

_BmiStatus _bmiStatus(double bmi) {
  if (bmi < 18.5) {
    return const _BmiStatus(
      label: '저체중 위험',
      emoji: '⚠️',
      description: '식사량과 체중 감소 추이를 의료진에게 공유해 주세요.',
    );
  }
  if (bmi >= 25) {
    return const _BmiStatus(
      label: '과체중 주의',
      emoji: '⚠️',
      description: '부종, 복부팽만, 식사량 변화를 함께 확인해 주세요.',
    );
  }
  return const _BmiStatus(
    label: '정상',
    emoji: '✅',
    description: '체중 변화와 식사·수분섭취를 함께 확인해 주세요.',
  );
}

List<DateTime> _calendarDays(DateTime visibleMonth) {
  final first = DateTime(visibleMonth.year, visibleMonth.month);
  final start = first.subtract(Duration(days: first.weekday - 1));
  return List.generate(
      42, (index) => _dateOnly(start.add(Duration(days: index))));
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
