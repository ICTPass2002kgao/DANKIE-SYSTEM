import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:ttact/Components/BibleVerseRepository.dart'; // Verify this path

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Initialize Timezones Database
    tz.initializeTimeZones();

    // 2. Set the Local Timezone (Critical for 11:00 AM to be accurate)
    try {
      final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName =
          tzResult is String ? tzResult : tzResult.toString();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print("Could not get local timezone: $e");
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 3. Android Settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_notification');

    // 4. iOS Settings
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

    // 5. Initialize Plugin
    await _notificationsPlugin.initialize(settings);

    // 6. Request Permission (Android 13+)
    final platform = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      await platform.requestNotificationsPermission();
    }
  }

  // --- SCHEDULING LOGIC ---
  static Future<void> scheduleDailyVerses() async {
    await _notificationsPlugin.cancelAll(); // Clear old queue

    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < 30; i++) {
      final targetDate = now.add(Duration(days: i));
      final verse = BibleVerseRepository.getDailyVerse(date: targetDate);

      await _scheduleNotification(
        id: i,
        title: "Verse of the Day ",
        body: '"${verse['text']}" - ${verse['ref']}',
        targetDate: targetDate,
      );
    }
    print("✅ Scheduled 30 days of verses at 11:00 AM");
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime targetDate,
  }) async {
    // Set to 11:00 AM
    var scheduledTime = tz.TZDateTime(
      tz.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      07, // Hour
      00, // Minute
    );

    // Skip if time passed today
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_verse_channel',
          'Daily Bible Verses',
          channelDescription: 'Word of the day biblical',
          importance: Importance.max,
          priority: Priority.high,
          largeIcon: DrawableResourceAndroidBitmap('ic_notification'),
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // ⭐️ PARAMETER REMOVED (Not needed in your version)
      
      // ⭐️ REQUIRED in your version
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // --- TEST FUNCTION ---
  static Future<void> showInstantTest() async {
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        importance: Importance.max,
        priority: Priority.high,
        largeIcon: DrawableResourceAndroidBitmap('ic_notification'),
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      999,
      'Test Notification',
      'If you see this, notifications work!',
      details,
    );
  }
}