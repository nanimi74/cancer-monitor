import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../data/models/medication.dart';

abstract interface class NotificationPermissionService {
  Future<bool> requestPermission();
  Future<void> syncMedicationReminders(Iterable<Medication> medications);
  Future<void> cancelMedicationReminders(int medicationId);
  Future<int> pendingMedicationReminderCount();
}

class LocalNotificationPermissionService
    implements NotificationPermissionService {
  LocalNotificationPermissionService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  var _initialized = false;
  var _timezoneInitialized = false;

  static const _androidChannelId = 'medication_reminders';
  static const _androidChannelName = '복약 알림';
  static const _androidChannelDescription = '등록한 약물의 섭취 시간을 알려줍니다.';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      ),
    );
    await _notificationsPlugin.initialize(settings: initializationSettings);
    _initialized = true;
  }

  Future<void> _ensureTimezoneInitialized() async {
    if (_timezoneInitialized) return;

    timezone_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
    } catch (_) {
      timezone.setLocalLocation(timezone.getLocation('Asia/Seoul'));
    }
    _timezoneInitialized = true;
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
  Future<void> syncMedicationReminders(Iterable<Medication> medications) async {
    await _ensureInitialized();
    await _ensureTimezoneInitialized();

    for (final medication in medications) {
      await cancelMedicationReminders(medication.id);
      if (!medication.reminderEnabled) continue;
      await _scheduleMedication(medication);
    }
  }

  @override
  Future<void> cancelMedicationReminders(int medicationId) async {
    await _ensureInitialized();
    for (var id = _notificationIdBase(medicationId);
        id < _notificationIdBase(medicationId + 1);
        id++) {
      await _notificationsPlugin.cancel(id: id);
    }
  }

  @override
  Future<int> pendingMedicationReminderCount() async {
    await _ensureInitialized();
    final requests = await _notificationsPlugin.pendingNotificationRequests();
    return requests
        .where((request) => request.payload?.startsWith('medication:') ?? false)
        .length;
  }

  Future<void> _scheduleMedication(Medication medication) async {
    final reminders = medication.reminders
        .where((reminder) => reminder.enabled)
        .toList(growable: false);
    for (var reminderIndex = 0;
        reminderIndex < reminders.length;
        reminderIndex++) {
      final reminder = reminders[reminderIndex];
      final time = _parseTime(reminder.time);
      if (time == null) continue;

      final weekdays = _weekdaysFor(medication);
      if (weekdays == null) {
        final id = _notificationIdBase(medication.id) + reminderIndex;
        final scheduledDate = _nextTime(time.hour, time.minute);
        if (_isCurrentMinute(time.hour, time.minute) ||
            _needsNearTermNotification(scheduledDate)) {
          await _scheduleNotification(
            id: _notificationIdBase(medication.id) + 900 + reminderIndex,
            medication: medication,
            reminderLabel: reminder.label,
            scheduledDate: timezone.TZDateTime.now(timezone.local)
                .add(const Duration(seconds: 10)),
          );
        }
        await _scheduleRepeatingNotification(
          id: id,
          medication: medication,
          reminderLabel: reminder.label,
          scheduledDate: scheduledDate,
          repeat: DateTimeComponents.time,
        );
        continue;
      }

      for (final weekday in weekdays) {
        final id = _notificationIdBase(medication.id) +
            100 +
            reminderIndex * 10 +
            weekday;
        final scheduledDate = _nextWeekdayTime(weekday, time.hour, time.minute);
        if ((_isToday(weekday) && _isCurrentMinute(time.hour, time.minute)) ||
            _needsNearTermNotification(scheduledDate)) {
          await _scheduleNotification(
            id: _notificationIdBase(medication.id) +
                900 +
                reminderIndex * 10 +
                weekday,
            medication: medication,
            reminderLabel: reminder.label,
            scheduledDate: timezone.TZDateTime.now(timezone.local)
                .add(const Duration(seconds: 10)),
          );
        }
        await _scheduleRepeatingNotification(
          id: id,
          medication: medication,
          reminderLabel: reminder.label,
          scheduledDate: scheduledDate,
          repeat: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  Future<void> _scheduleRepeatingNotification({
    required int id,
    required Medication medication,
    required String reminderLabel,
    required timezone.TZDateTime scheduledDate,
    required DateTimeComponents repeat,
  }) {
    return _scheduleNotification(
      id: id,
      medication: medication,
      reminderLabel: reminderLabel,
      scheduledDate: scheduledDate,
      repeat: repeat,
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required Medication medication,
    required String reminderLabel,
    required timezone.TZDateTime scheduledDate,
    DateTimeComponents? repeat,
  }) {
    return _notificationsPlugin.zonedSchedule(
      id: id,
      title: '복약 시간입니다',
      body: '${medication.name} ${medication.dose} · $reminderLabel',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: repeat,
      payload: 'medication:${medication.id}',
    );
  }

  timezone.TZDateTime _nextTime(int hour, int minute) {
    final now = timezone.TZDateTime.now(timezone.local);
    var scheduled = timezone.TZDateTime(
      timezone.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  timezone.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    final next = _nextTime(hour, minute);
    final daysUntilWeekday = (weekday - next.weekday) % DateTime.daysPerWeek;
    return next.add(Duration(days: daysUntilWeekday));
  }

  bool _needsNearTermNotification(timezone.TZDateTime scheduledDate) {
    final now = timezone.TZDateTime.now(timezone.local);
    final leadTime = scheduledDate.difference(now);
    return !leadTime.isNegative && leadTime <= const Duration(seconds: 15);
  }

  bool _isToday(int weekday) {
    return timezone.TZDateTime.now(timezone.local).weekday == weekday;
  }

  bool _isCurrentMinute(int hour, int minute) {
    final now = timezone.TZDateTime.now(timezone.local);
    return now.hour == hour && now.minute == minute;
  }

  ({int hour, int minute})? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour: hour, minute: minute);
  }

  List<int>? _weekdaysFor(Medication medication) {
    if (medication.frequency != '직접입력') return null;
    final weekdays = medication.weekdays
        .map(_weekdayNumber)
        .whereType<int>()
        .toList(growable: false);
    return weekdays.isEmpty ? null : weekdays;
  }

  int? _weekdayNumber(String label) {
    return switch (label) {
      '월' => DateTime.monday,
      '화' => DateTime.tuesday,
      '수' => DateTime.wednesday,
      '목' => DateTime.thursday,
      '금' => DateTime.friday,
      '토' => DateTime.saturday,
      '일' => DateTime.sunday,
      _ => null,
    };
  }

  int _notificationIdBase(int medicationId) {
    return medicationId.remainder(100000) * 1000;
  }
}
