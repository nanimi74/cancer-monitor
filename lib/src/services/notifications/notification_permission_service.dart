abstract interface class NotificationPermissionService {
  Future<bool> requestPermission();
  Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String title,
    required DateTime scheduledAt,
  });
}

class LocalNotificationPermissionService implements NotificationPermissionService {
  const LocalNotificationPermissionService();

  @override
  Future<bool> requestPermission() async {
    // TODO: Implement with local notifications package and platform permission.
    return false;
  }

  @override
  Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    // TODO: Schedule local notification after permission is granted.
  }
}
