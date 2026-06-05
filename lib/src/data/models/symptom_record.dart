class SymptomRecord {
  const SymptomRecord({
    required this.date,
    required this.cycleNo,
    required this.cycleDay,
    required this.mealAmount,
    required this.waterAmount,
    required this.steps,
    required this.bowel,
    required this.sideEffects,
    this.stoolStatus = '',
    this.note = '',
  });

  final DateTime date;
  final int cycleNo;
  final int cycleDay;
  final String mealAmount;
  final String waterAmount;
  final int steps;
  final String bowel;
  final List<String> sideEffects;
  final String stoolStatus;
  final String note;
}
