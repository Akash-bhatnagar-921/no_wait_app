import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── FCM activation instructions ───────────────────────────────────────────────
// 1. Add google-services.json to android/app/
// 2. Uncomment the Gradle plugin in android/app/build.gradle.kts
// 3. Uncomment firebase_core + firebase_messaging in pubspec.yaml
// 4. Run: flutter pub get
// 5. Uncomment ALL lines marked [FCM] below
// ─────────────────────────────────────────────────────────────────────────────

// [FCM] import 'package:firebase_core/firebase_core.dart';
// [FCM] import 'package:firebase_messaging/firebase_messaging.dart';

// [FCM] @pragma('vm:entry-point')
// [FCM] Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
// [FCM]   await Firebase.initializeApp();
// [FCM]   NotificationService.instance._showFromRemote(message);
// [FCM] }

/// Callback signature: receives the raw payload string when a notification
/// is tapped. The payload is a JSON string with at least {"type", "bookingId"}.
typedef NotificationTapCallback = void Function(String payload);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fln = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  static const _channelId   = 'baari_default';
  static const _channelName = 'Baari Notifications';

  /// Registered from main.dart; called when the user taps a notification.
  NotificationTapCallback? onTap;

  // ── Init ─────────────────────────────────────────────────────────────────────

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
      onDidReceiveNotificationResponse: _onLocalTap,
      onDidReceiveBackgroundNotificationResponse: _onLocalTap,
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

    // [FCM] — uncomment to enable remote push ─────────────────────────────────
    // await Firebase.initializeApp();
    // FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    // final messaging = FirebaseMessaging.instance;
    // await messaging.requestPermission(alert: true, badge: true, sound: true);
    //
    // // Foreground messages → show as local notification
    // FirebaseMessaging.onMessage.listen(_showFromRemote);
    //
    // // Notification tap when app is in background/terminated
    // FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    //   final payload = _remotePayload(msg);
    //   if (payload != null) onTap?.call(payload);
    // });
    //
    // // App opened from terminated state via notification
    // final initial = await messaging.getInitialMessage();
    // if (initial != null) {
    //   final payload = _remotePayload(initial);
    //   if (payload != null) {
    //     // Slight delay so the widget tree is ready
    //     Future.delayed(const Duration(milliseconds: 500), () => onTap?.call(payload));
    //   }
    // }
    // ─────────────────────────────────────────────────────────────────────────
  }

  // ── FCM token ─────────────────────────────────────────────────────────────────

  /// Returns the FCM registration token, or null if Firebase is not active.
  Future<String?> getFcmToken() async {
    // [FCM] return await FirebaseMessaging.instance.getToken();
    return null; // Firebase not yet configured
  }

  // ── Show local notification (title + body + optional payload) ────────────────

  Future<void> show(String title, String body, {String? payload}) async {
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
      payload: payload,
    );
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  @pragma('vm:entry-point')
  static void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      instance.onTap?.call(payload);
    }
  }

  // [FCM] helper: show a local notification from a remote FCM message
  // void _showFromRemote(RemoteMessage message) {
  //   final n = message.notification;
  //   if (n == null) return;
  //   final payload = _remotePayload(message);
  //   show(n.title ?? 'Baari', n.body ?? '', payload: payload);
  // }

  // [FCM] helper: build a JSON payload string from an FCM message's data map
  // String? _remotePayload(RemoteMessage message) {
  //   if (message.data.isEmpty) return null;
  //   final type      = message.data['type']      ?? '';
  //   final bookingId = message.data['bookingId'] ?? '';
  //   return '{"type":"$type","bookingId":"$bookingId"}';
  // }
}
