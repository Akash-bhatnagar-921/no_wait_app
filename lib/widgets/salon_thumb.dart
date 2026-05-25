import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Square thumbnail for a salon. Shows the remote photo when [imageUrl] is
/// non-null, otherwise falls back to the scissors icon placeholder.
class SalonThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color primary;

  const SalonThumb({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.27);

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // imageUrl is a server-relative path like /uploads/salons/xyz.jpg
      final fullUrl = '${ApiService.baseUrl}$imageUrl';
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          fullUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, trace) => _placeholder(radius),
        ),
      );
    }
    return _placeholder(radius);
  }

  Widget _placeholder(BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: radius,
      ),
      child: Icon(Icons.content_cut, color: primary, size: size * 0.5),
    );
  }
}
