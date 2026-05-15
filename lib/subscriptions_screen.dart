import 'package:flutter/material.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Subscriptions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 48 : 18,
          vertical: 24,
        ),
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            const Text(
              'Choose Your Plan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Unlock more features with a Baari subscription.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            // ── Plans ─────────────────────────────────────────────────────
            _PlanCard(
              title: 'Free',
              price: '₹0',
              period: 'forever',
              features: const [
                'Browse salons',
                'Up to 2 bookings / month',
                'Basic search filters',
              ],
              isActive: true,
              color: Colors.grey.shade700,
            ),

            const SizedBox(height: 16),

            _PlanCard(
              title: 'Basic',
              price: '₹99',
              period: '/ month',
              features: const [
                'Unlimited bookings',
                'Priority queue',
                'Booking reminders',
                'Email support',
              ],
              isActive: false,
              color: const Color(0xFF6FCF97),
            ),

            const SizedBox(height: 16),

            _PlanCard(
              title: 'Pro',
              price: '₹199',
              period: '/ month',
              features: const [
                'Everything in Basic',
                'Exclusive salon deals',
                'Loyalty reward points',
                'Dedicated support',
                'Early access to new features',
              ],
              isActive: false,
              color: const Color(0xFF2D9248),
              highlighted: true,
            ),

            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF6FCF97).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFF2D9248), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Subscriptions will be available soon. '
                      'You are on the Free plan.',
                      style: TextStyle(
                          color: Color(0xFF2D9248), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isActive;
  final Color color;
  final bool highlighted;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.isActive,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlighted ? color : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? color : Colors.grey.shade200,
          width: highlighted ? 0 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6))
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: highlighted ? Colors.white : Colors.black,
                ),
              ),
              if (highlighted)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6FCF97).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'CURRENT',
                    style: TextStyle(
                        color: Color(0xFF2D9248),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Price
          RichText(
            text: TextSpan(
              style: TextStyle(
                  color: highlighted ? Colors.white : Colors.black),
              children: [
                TextSpan(
                  text: price,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' $period',
                  style: TextStyle(
                      fontSize: 14,
                      color: highlighted
                          ? Colors.white70
                          : Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.grey.shade200),
          const SizedBox(height: 14),

          // Features
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18,
                        color: highlighted
                            ? Colors.white
                            : const Color(0xFF6FCF97)),
                    const SizedBox(width: 10),
                    Text(
                      f,
                      style: TextStyle(
                          color: highlighted
                              ? Colors.white
                              : Colors.black87),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: highlighted
                    ? Colors.white
                    : isActive
                        ? Colors.grey.shade200
                        : color,
                foregroundColor: highlighted
                    ? color
                    : isActive
                        ? Colors.grey
                        : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isActive ? null : () {},
              child: Text(
                isActive ? 'Current Plan' : 'Get $title',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
