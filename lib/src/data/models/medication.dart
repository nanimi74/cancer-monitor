class MedicationReminder {
  const MedicationReminder({
    required this.label,
    required this.time,
    required this.enabled,
  });

  final String label;
  final String time;
  final bool enabled;
}

class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.weekdays,
    required this.reminderEnabled,
    required this.reminders,
    this.memo = '',
  });

  final int id;
  final String name;
  final String dose;
  final String frequency;
  final List<String> weekdays;
  final bool reminderEnabled;
  final List<MedicationReminder> reminders;
  final String memo;
}
