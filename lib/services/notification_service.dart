import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../providers/settings_provider.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _weeklyId = 1001;
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'weekly_reminder',
    'Weekly Reminder',
    description: 'Weekly task planning reminder',
    importance: Importance.defaultImportance,
  );

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // Timezone setup (use platform local zone)
    try {
      tzdata.initializeTimeZones();
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initializationSettings);

    // Android 13+ permission
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.createNotificationChannel(_channel);
    }
    // iOS permission (macOS shares Darwin implementation)
    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  Future<void> ensureWeeklyReminder({
    required bool enabled,
    required WeekStart weekStart,
    required int hour,
    required int minute,
  }) async {
    await init();
    if (!enabled) {
      await cancelWeeklyReminder();
      return;
    }
    await scheduleWeeklyReminder(weekStart: weekStart, hour: hour, minute: minute);
  }

  Future<void> cancelWeeklyReminder() async {
    await _plugin.cancel(_weeklyId);
  }

  Future<void> scheduleWeeklyReminder({
    required WeekStart weekStart,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    // Determine target weekday: Monday=1..Sunday=7 (ISO)
    final targetIso = weekStart == WeekStart.monday ? DateTime.monday : DateTime.sunday;
    // Construct next occurrence this week at specified time
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // Move to target weekday
    final currentIso = scheduled.weekday; // 1..7
    final diff = (targetIso - currentIso) % 7; // 0..6
    scheduled = scheduled.add(Duration(days: diff));
    // If the computed time is already in the past for today, bump by 7 days
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
    );
    const darwinDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: darwinDetails, macOS: darwinDetails);

    await _plugin.zonedSchedule(
      _weeklyId,
      '今週はどのタスクをやりますか？',
      'TODOを選んで今週の計画を立てましょう',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly_reminder',
    );
  }
}
