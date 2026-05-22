import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local-notification wrapper.
///
/// Firebase Cloud Messaging (remote push) is intentionally disabled until the
/// project is registered in the Firebase Console and the config files are added:
///   Android : android/app/google-services.json
///   iOS     : ios/Runner/GoogleService-Info.plist
///
/// Once those files exist:
///   1. Uncomment firebase_core and firebase_messaging in pubspec.yaml
///   2. Uncomment the google-services plugin in android/app/build.gradle.kts
///   3. Restore the full Firebase implementation in this file (see git history)
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fln = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  static const _channelId   = 'baari_default';
  static const _channelName = 'Baari Notifications';

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _fln.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ),
        );
  }

  /// Shows a local notification immediately (foreground alerts, reminders, etc.).
  Future<void> show(String title, String body) async {
    await _fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          importance: Importance.high,
          priority:   Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
