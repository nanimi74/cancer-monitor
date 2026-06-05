class UserProfile {
  const UserProfile({
    required this.sex,
    required this.birthDate,
    required this.cancerType,
    required this.stage,
    required this.heightCm,
  });

  final String sex;
  final DateTime birthDate;
  final String cancerType;
  final String stage;
  final double heightCm;

  int age(DateTime today) {
    var value = today.year - birthDate.year;
    final birthdayPassed = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!birthdayPassed) value -= 1;
    return value;
  }
}
