import 'package:flutter/material.dart';
import 'package:no_wait_app/admin/admin_login_screen.dart';
import 'package:no_wait_app/barber_setup/onboarding_choice_screen.dart';
import 'package:no_wait_app/login_screen.dart';
import 'package:no_wait_app/signup_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  int _iconTapCount = 0;
  DateTime? _firstIconTap;

  void _onIconTap() {
    final now = DateTime.now();
    if (_firstIconTap == null ||
        now.difference(_firstIconTap!) > const Duration(seconds: 2)) {
      _iconTapCount = 1;
      _firstIconTap = now;
    } else {
      _iconTapCount++;
    }
    if (_iconTapCount >= 5) {
      _iconTapCount = 0;
      _firstIconTap = null;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
    }
  }

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
            child: isTablet ? _tabletLayout(context) : _mobileLayout(context),
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
          child: Padding(padding: const EdgeInsets.all(20), child: _image()),
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
        GestureDetector(
          onTap: _onIconTap,
          child: Icon(Icons.content_cut, size: 28, color: primary),
        ),
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
          style: TextStyle(color: primary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
