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
    this.breakfastMemo = '',
    this.lunchMemo = '',
    this.dinnerMemo = '',
    this.extraMealMemo = '',
    this.stepsSource = '수동',
    this.stepsDeviceId = '',
    this.stoolStatus = '',
    this.note = '',
  });

  final DateTime date;
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
  final String stepsDeviceId;
  final String bowel;
  final List<String> sideEffects;
  final String stoolStatus;
  final String note;
}
