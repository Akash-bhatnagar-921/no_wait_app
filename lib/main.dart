import 'dart:convert';
import 'package:flutter/material.dart';
import 'barber_setup/barber_home_screen.dart';
import 'home_screen.dart';
import 'my_bookings_screen.dart';
import 'onboarding_screen.dart';
import 'role_selection_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'theme/theme_manager.dart';
import 'admin/admin_home_screen.dart';
import 'admin/admin_login_screen.dart';

/// Root navigator key — allows ApiService to trigger logout from any context.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.instance.loadSavedTheme();
  ApiService.navigatorKey = navigatorKey;

  // Initialise local notifications + wire up FCM if Firebase is configured.
  // See notification_service.dart for the one-file-drop activation steps.
  await NotificationService.instance.init();

  // Best-effort: upload FCM token to the backend so the server can push to
  // this device.  Silently ignored if Firebase is not yet configured.
  NotificationService.instance.getFcmToken().then((token) {
    if (token != null && token.isNotEmpty) {
      ApiService.saveFcmToken(token).catchError((_) {});
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    ThemeManager.instance.addListener(_onThemeChanged);
    // Wire notification-tap deep-link routing.
    NotificationService.instance.onTap = _handleNotificationTap;
  }

  @override
  void dispose() {
    ThemeManager.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  /// Called whenever the user taps a local or remote notification.
  /// Payload is a JSON string: `{"type": "...", "bookingId": "..."}`.
  void _handleNotificationTap(String payload) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type      = data['type']      as String? ?? '';
    final bookingId = data['bookingId'] as String? ?? '';

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // All booking-related notification types → navigate to My Bookings so the
    // customer can see the updated status and OTP.
    const bookingTypes = {
      'booking_accepted', 'booking_rejected', 'booking_completed',
    };

    if (bookingTypes.contains(type) && bookingId.isNotEmpty) {
      // Navigate to MyBookingsScreen; if we already have a full booking object
      // cached we could go straight to BookingDetailScreen, but the safest
      // approach is to load the list and let the user tap the relevant card.
      nav.push(MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
      return;
    }

    // Fallback for unknown types — still navigate to My Bookings
    if (bookingId.isNotEmpty) {
      nav.push(MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeManager.instance.themeData,
      home: const _StartupScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Startup screen: checks saved token → routes to correct home, no re-login
// ─────────────────────────────────────────────────────────────────────────────

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  int _tapCount = 0;
  DateTime? _firstTapTime;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _onLogoTap() {
    final now = DateTime.now();
    if (_firstTapTime == null || now.difference(_firstTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
      _firstTapTime = now;
    } else {
      _tapCount++;
    }
    if (_tapCount >= 5) {
      _tapCount = 0;
      _firstTapTime = null;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
    }
  }

  Future<void> _checkAuth() async {
    // Show onboarding on very first launch (before any auth check)
    final onboardingDone = await isOnboardingDone();
    if (!onboardingDone) {
      if (mounted) _goTo(const OnboardingScreen());
      return;
    }

    final token = await ApiService.getToken();
    if (!mounted) return;

    if (token == null) {
      _goTo(const RoleSelectionScreen());
      return;
    }

    // Validate token and get role
    try {
      final profile = await ApiService.getProfile();
      if (!mounted) return;
      if (profile == null) {
        _goTo(const RoleSelectionScreen());
        return;
      }

      if (profile.role == 'admin') {
        _goTo(AdminHomeScreen(adminName: profile.fullName));
      } else if (profile.role == 'professional') {
        _goTo(const ProfessionalHomeScreen());
      } else {
        _goTo(const HomeScreen());
      }
    } catch (_) {
      // Token invalid/expired — clear it and show login
      await ApiService.logout();
      if (mounted) _goTo(const RoleSelectionScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Blank white screen with centered logo while checking auth
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _onLogoTap,
              child: Image.asset('assets/logo.png', width: 90, height: 90),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

