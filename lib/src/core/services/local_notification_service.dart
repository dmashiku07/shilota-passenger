import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    tz.initializeTimeZones();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> scheduleRideReminder({
    required String onRideId,
    required DateTime scheduledAt,
    required String pickupLocation,
    required String dropoffLocation,
  }) async {
    await initialize();
    await cancelRideReminder(onRideId);
    final now = DateTime.now();
    final reminderTimes = <DateTime>[
      scheduledAt.subtract(const Duration(hours: 1)),
      scheduledAt.subtract(const Duration(minutes: 15)),
    ].where((value) => value.isAfter(now)).toList();

    for (var index = 0; index < reminderTimes.length; index++) {
      final when = reminderTimes[index];
      await _plugin.zonedSchedule(
        _notificationId(onRideId, index),
        'Scheduled ride reminder',
        'Upcoming ride from $pickupLocation to $dropoffLocation',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_ride_reminders',
            'Scheduled Ride Reminders',
            channelDescription: 'Local reminders for scheduled ride bookings',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelRideReminder(String onRideId) async {
    await initialize();
    await _plugin.cancel(_notificationId(onRideId, 0));
    await _plugin.cancel(_notificationId(onRideId, 1));
  }

  int _notificationId(String onRideId, int slot) {
    return onRideId.hashCode.abs() % 100000 + slot;
  }
}
