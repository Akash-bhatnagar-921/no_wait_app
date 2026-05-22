import 'package:flutter/material.dart';

/// Horizontal progress bar showing profile completion percentage.
///
/// Usage:
///   ProfileCompletionWidget(percent: 0.6, label: 'Profile 60% complete')
class ProfileCompletionWidget extends StatelessWidget {
  final double percent;   // 0.0 – 1.0
  final String label;
  final bool compact;     // true = smaller bar for tight spaces

  const ProfileCompletionWidget({
    super.key,
    required this.percent,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final pct     = percent.clamp(0.0, 1.0);
    final pctInt  = (pct * 100).round();

    Color barColor;
    if (pct >= 0.8) {
      barColor = const Color(0xFF2D9248); // green
    } else if (pct >= 0.5) {
      barColor = const Color(0xFFFFB300); // amber
    } else {
      barColor = const Color(0xFFE53935); // red
    }

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_circle_outlined,
                size: compact ? 14 : 16, color: primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
            Text(
              '$pctInt%',
              style: TextStyle(
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: compact ? 5 : 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (!compact && pct < 1.0) ...[
            const SizedBox(height: 6),
            Text(
              pct < 0.5
                  ? 'Add more details to improve your profile.'
                  : pct < 0.8
                      ? 'Almost there! A few more fields to complete.'
                      : 'Great — your profile is nearly complete!',
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Helpers for calculating completion ────────────────────────────────────────

/// Customer profile completion (0.0 – 1.0).
double customerCompletion({
  required String fullName,
  required String email,
  required String? gender,
  required int? age,
}) {
  int filled = 0;
  if (fullName.isNotEmpty) filled++;
  if (email.isNotEmpty) filled++;
  if (gender?.isNotEmpty == true) filled++;
  if (age != null) filled++;
  return filled / 4;
}

/// Professional/salon profile completion (0.0 – 1.0).
double professionalCompletion(Map<String, dynamic> salon) {
  int filled = 0;
  const total = 10;

  final manager = salon['manager'] as Map<String, dynamic>?;
  if (manager?['fullName']?.toString().isNotEmpty == true) filled++;

  if ((salon['name'] as String?)?.isNotEmpty == true) filled++;
  if ((salon['address'] as String?)?.isNotEmpty == true) filled++;
  if ((salon['city'] as String?)?.isNotEmpty == true) filled++;
  if ((salon['contactNumber'] as String?)?.isNotEmpty == true) filled++;
  if ((salon['openingTime'] as String?)?.isNotEmpty == true) filled++;
  if ((salon['workingDays'] as String?)?.isNotEmpty == true) filled++;

  final services = salon['services'] as List? ?? [];
  final pricedServices =
      services.where((s) => (s['price'] as num? ?? 0) > 0).length;
  if (pricedServices > 0) filled++;      // at least one service priced
  if (pricedServices >= 3) filled++;     // 3+ services priced = bonus point

  final amenities = salon['amenities'] as List? ?? [];
  if (amenities.isNotEmpty) filled++;

  return filled / total;
}
