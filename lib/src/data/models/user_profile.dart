class UserProfile {
  const UserProfile({
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

  int age(DateTime today) {
    var value = today.year - birthDate.year;
    final birthdayPassed = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!birthdayPassed) value -= 1;
    return value;
  }
}
