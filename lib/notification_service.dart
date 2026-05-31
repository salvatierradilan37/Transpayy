import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        'transpayy_channel',
        'Notificaciones TransPayy',
        description: 'Notificaciones de pagos y recargas',
        importance: Importance.high,
      );
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized || kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'transpayy_channel',
      'Notificaciones TransPayy',
      channelDescription: 'Notificaciones de pagos y recargas',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }
}
