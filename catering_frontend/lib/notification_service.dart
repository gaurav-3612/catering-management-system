import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    // Android Settings (Icon must exist in android/app/src/main/res/drawable)
    // You can use the default flutter icon '@mipmap/ic_launcher'
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(settings);
  }

  static Future<void> scheduleEventReminder({
    required int id,
    required String title,
    required String body,
    required DateTime eventDate,
  }) async {
    // Schedule notification for 9:00 AM on the day BEFORE the event
    // Subtract 1 day from event date
    final scheduledDate = eventDate.subtract(const Duration(days: 1));

    // If the scheduled date is in the past, don't schedule it
    if (scheduledDate.isBefore(DateTime.now())) return;

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local)
          .add(const Duration(hours: 9)), // 9 AM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'catering_channel', // Channel ID
          'Event Reminders', // Channel Name
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
