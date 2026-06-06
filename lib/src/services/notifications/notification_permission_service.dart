import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class NotificationPermissionService {
  Future<bool> requestPermission();
  Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String title,
    required DateTime scheduledAt,
  });
}

class LocalNotificationPermissionService
    implements NotificationPermissionService {
  LocalNotificationPermissionService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  var _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _notificationsPlugin.initialize(settings: initializationSettings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();

    if (Platform.isIOS) {
      final iosPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? true;
    }

    return false;
  }

  @override
  Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    await _ensureInitialized();
    // Medication scheduling will be connected when 복약관리 storage is added.
  }
}
