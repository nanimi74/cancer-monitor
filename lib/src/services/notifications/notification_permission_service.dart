import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class NotificationPermissionService {
  Future<bool> requestPermission();
  Future<void> syncDailyConditionReminder({required bool enabled});
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

  static const _dailyConditionReminderId = 1900;
  static const _dailyConditionReminderTitle = '오늘 컨디션 기록';
  static const _dailyConditionReminderBody = '오늘 몸 상태는 어떠셨나요? 한결에 가볍게 남겨보세요.';
  static const _androidChannelId = 'daily_condition_reminder';
  static const _androidChannelName = '컨디션 기록 알림';
  static const _androidChannelDescription = '매일 저녁 컨디션 기록을 안내합니다.';

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  var _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
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
  Future<void> syncDailyConditionReminder({required bool enabled}) async {
    await _ensureInitialized();
    await _notificationsPlugin.cancel(id: _dailyConditionReminderId);
    if (!enabled) return;

    await _notificationsPlugin.zonedSchedule(
      id: _dailyConditionReminderId,
      title: _dailyConditionReminderTitle,
      body: _dailyConditionReminderBody,
      scheduledDate: _nextSevenPm(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
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

  tz.TZDateTime _nextSevenPm() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
