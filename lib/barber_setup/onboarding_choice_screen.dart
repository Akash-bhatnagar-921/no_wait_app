import 'package:flutter/material.dart';
import 'step1_screen.dart';

// Admin / support contact — update to your real number
const String kSupportPhone = '+91-9999999999';

class OnboardingChoiceScreen extends StatefulWidget {
  const OnboardingChoiceScreen({super.key});

  @override
  State<OnboardingChoiceScreen> createState() => _OnboardingChoiceScreenState();
}

class _OnboardingChoiceScreenState extends State<OnboardingChoiceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideA;
  late final Animation<Offset> _slideB;
  late final Animation<double> _fadeA;
  late final Animation<double> _fadeB;

  bool _showAdminContact = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _slideA = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _slideB = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.85, curve: Curves.easeOut)));
    _fadeA = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.55)));
    _fadeB = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.8)));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onAdminTap() {
    setState(() => _showAdminContact = !_showAdminContact);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 600 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // ── Logo ───────────────────────────────────────────────
                  Image.asset('assets/logo.png', height: isTablet ? 70 : 56),

                  const SizedBox(height: 24),

                  const Text(
                    'Join as Professional',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'How would you like to register your salon?',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // ── Card A: Manual Process ─────────────────────────────
                  FadeTransition(
                    opacity: _fadeA,
                    child: SlideTransition(
                      position: _slideA,
                      child: _ChoiceCard(
                        icon: Icons.edit_note_rounded,
                        title: 'Manual Process',
                        description:
                            'Fill out the registration form yourself with your salon details, services and barbers.',
                        actionLabel: 'Start Registration',
                        color: const Color(0xFF6FCF97),
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const Step1Screen()),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Card B: Admin Process ──────────────────────────────
                  FadeTransition(
                    opacity: _fadeB,
                    child: SlideTransition(
                      position: _slideB,
                      child: _ChoiceCard(
                        icon: Icons.support_agent_rounded,
                        title: 'Admin Process',
                        description:
                            'Prefer a guided setup? Contact our team and we\'ll onboard your salon for you.',
                        actionLabel: 'Contact Support',
                        color: const Color(0xFF4A90D9),
                        onTap: _onAdminTap,
                        trailing: _showAdminContact
                            ? _contactBadge()
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Back ───────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFF6FCF97),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4A90D9).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone, color: Color(0xFF4A90D9), size: 18),
          const SizedBox(width: 8),
          Text(
            'Call us @ $kSupportPhone',
            style: const TextStyle(
              color: Color(0xFF1A5FA8),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Choice Card ─────────────────────────────────────────────────────

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(height: 4),
            trailing!,
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onTap,
              child: Text(
                actionLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
