import 'package:flutter/material.dart';

/// Displays a star rating (0–5) with optional review count.
///
/// Example:
///   StarRating(rating: 4.5, reviewCount: 23)   →  ★★★★½ 4.5 (23)
///   StarRating(rating: 3.2, compact: true)      →  ★ 3.2
class StarRating extends StatelessWidget {
  final double rating;      // 0.0 – 5.0
  final int?   reviewCount;
  final double starSize;
  final bool   compact;     // true = single star + number only

  const StarRating({
    super.key,
    required this.rating,
    this.reviewCount,
    this.starSize = 14,
    this.compact  = false,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC107);

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: starSize, color: gold),
          const SizedBox(width: 3),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : 'New',
            style: TextStyle(
              fontSize: starSize * 0.93,
              fontWeight: FontWeight.w600,
              color: rating > 0 ? Colors.black87 : Colors.grey,
            ),
          ),
          if (reviewCount != null && reviewCount! > 0) ...[
            const SizedBox(width: 3),
            Text(
              '($reviewCount)',
              style: TextStyle(
                fontSize: starSize * 0.86,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      );
    }

    // Full row of 5 stars
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final filled = rating - i;
          IconData icon;
          if (filled >= 0.75) {
            icon = Icons.star_rounded;
          } else if (filled >= 0.25) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
          return Icon(icon, size: starSize, color: gold);
        }),
        const SizedBox(width: 5),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : 'New',
          style: TextStyle(
            fontSize: starSize * 0.93,
            fontWeight: FontWeight.w700,
            color: rating > 0 ? Colors.black87 : Colors.grey,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            reviewCount! > 0 ? '(${reviewCount!} reviews)' : '(No reviews yet)',
            style: TextStyle(
              fontSize: starSize * 0.86,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ],
    );
  }
}
