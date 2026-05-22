import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'barber_setup/onboarding_choice_screen.dart';
import 'barber_setup/barber_home_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'theme/theme_manager.dart';

/// Root navigator key — allows ApiService to trigger logout from any context.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.instance.loadSavedTheme();
  ApiService.navigatorKey = navigatorKey;

  // Initialise local notifications (no Firebase dependency).
  // FCM remote push will be enabled once google-services.json is added —
  // see notification_service.dart for instructions.
  await NotificationService.instance.init();

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
  }

  @override
  void dispose() {
    ThemeManager.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

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
  @override
  void initState() {
    super.initState();
    _checkAuth();
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

      if (profile.role == 'professional') {
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
            Image.asset('assets/logo.png', width: 90, height: 90),
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

// ─────────────────────────────────────────────────────────────────────────────

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final isDesktop = size.width >= 1100;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 900 : (isTablet ? 700 : double.infinity),
            ),
            child:
                isTablet ? _tabletLayout(context) : _mobileLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(flex: 4, child: _image()),
                    const SizedBox(height: 20),
                    _text(context),
                    const SizedBox(height: 20),
                    _buttons(context),
                    const SizedBox(height: 10),
                    _loginLink(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tabletLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
              padding: const EdgeInsets.all(20), child: _image()),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _text(context),
                const SizedBox(height: 30),
                _buttons(context),
                const SizedBox(height: 10),
                _loginLink(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _image() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.asset('assets/salon.png', fit: BoxFit.cover),
      ),
    );
  }

  Widget _text(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Icon(Icons.content_cut, size: 28, color: primary),
        const SizedBox(height: 10),
        const Text(
          'Look Good.\nFeel Your Best.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Book salons & barbers near you',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buttons(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            ),
            child: const Text('Continue as Customer'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const OnboardingChoiceScreen()),
            ),
            child: Text(
              'Join as Professional',
              style: TextStyle(color: primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loginLink(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'Already have an account? Login',
          style: TextStyle(
              color: primary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
