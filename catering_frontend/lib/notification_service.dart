import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Call once in main()
  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'catering_channel',
      'Catering Reminders',
      description: 'Reminders for catering events',
      importance: Importance.max,
    );

    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static const bool _testMode = false;

  /// Notification on EVENT DAY at 9:00 AM
  static Future<void> scheduleEventDayReminder({
    required String title,
    required String body,
    required DateTime eventDate,
  }) async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    late DateTime scheduledDate;

    if (_testMode) {
      // TEST MODE → 10 seconds from now
      scheduledDate = DateTime.now().add(const Duration(seconds: 10));
    } else {
      //PRODUCTION MODE → Event day at 9:00 AM
      scheduledDate = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        9,
        0,
      );

      // Skip if already past
      if (scheduledDate.isBefore(DateTime.now())) {
        return;
      }
    }

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'catering_channel',
          'Catering Reminders',
          channelDescription: 'Reminders for catering events',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
