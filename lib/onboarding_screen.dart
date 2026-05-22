import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

// Key stored in SharedPreferences once onboarding is done
const _kOnboardingDone = 'onboarding_done';

Future<bool> isOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDone) ?? false;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDone, true);
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _Page {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  const _Page({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}

const _pages = [
  _Page(
    icon: Icons.search_rounded,
    iconBg: Color(0xFFE8F5E9),
    iconColor: Color(0xFF2D9248),
    title: 'Find the Best Salons Near You',
    subtitle:
        'Browse approved salons within your area, filter by services and amenities, and discover top-rated barbers in minutes.',
  ),
  _Page(
    icon: Icons.calendar_today_rounded,
    iconBg: Color(0xFFE3F2FD),
    iconColor: Color(0xFF1565C0),
    title: 'Book Instantly, Skip the Wait',
    subtitle:
        'Choose your services, pick a time slot that works for you, and confirm your appointment — all in a few taps.',
  ),
  _Page(
    icon: Icons.verified_outlined,
    iconBg: Color(0xFFFFF3E0),
    iconColor: Color(0xFFE65100),
    title: 'Secure OTP Check-In',
    subtitle:
        'When you arrive, show your 4-digit booking OTP to the professional. Your appointment starts only after verification — no confusion, no mix-ups.',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _current = 0;

  void _next() {
    if (_current < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await markOnboardingDone();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.of(context).size;
    final primary = Theme.of(context).colorScheme.primary;
    final isLast  = _current == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ────────────────────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Skip',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
            ),

            // ── Pages ────────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageView(
                  page: _pages[i],
                  screenWidth: size.width,
                ),
              ),
            ),

            // ── Dots ─────────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // ── CTA button ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    isLast ? 'Get Started' : 'Next',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ── Single page ───────────────────────────────────────────────────────────────

class _PageView extends StatelessWidget {
  final _Page page;
  final double screenWidth;
  const _PageView({required this.page, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    // Cap illustration so it never dominates on wide tablets.
    final illustrationSize = (screenWidth * 0.50).clamp(120.0, 240.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Illustration circle
          Container(
            width: illustrationSize,
            height: illustrationSize,
            decoration: BoxDecoration(
              color: page.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon,
                size: illustrationSize * 0.45, color: page.iconColor),
          ),
          const SizedBox(height: 36),

          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.6),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
