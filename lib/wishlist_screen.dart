import 'package:flutter/material.dart';

import 'salon_detail_screen.dart';
import 'services/api_service.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/error_retry.dart';
import 'widgets/loading_widget.dart';
import 'widgets/star_rating.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Map<String, dynamic>> _salons = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final results = await ApiService.getWishlist();
      if (mounted) {
        setState(() {
          _salons = List<Map<String, dynamic>>.from(results);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  Future<void> _remove(String salonId) async {
    final ok = await ApiService.removeFromWishlist(salonId);
    if (!mounted) return;
    if (ok) {
      setState(() => _salons.removeWhere((s) => s['id'] == salonId));
      AppSnackbar.success(context, 'Removed from wishlist');
    } else {
      AppSnackbar.error(context, 'Could not remove. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary   = Theme.of(context).colorScheme.primary;
    final isTablet  = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        centerTitle: true,
      ),
      body: _loading
          ? const AppLoadingIndicator(message: 'Loading your wishlist…')
          : _hasError
              ? ErrorRetry(onRetry: _load)
              : _salons.isEmpty
                  ? _buildEmpty(primary)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 16,
                      vertical: 16,
                    ),
                    itemCount: _salons.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 14),
                    itemBuilder: (_, i) =>
                        _buildCard(_salons[i], primary),
                  ),
                ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty(Color primary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No favourites yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the ♡ on any salon\nto save it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Salon card ─────────────────────────────────────────────────────────────

  Widget _buildCard(Map<String, dynamic> salon, Color primary) {
    final salonId  = salon['id']             as String;
    final name     = salon['name']           as String? ?? 'Salon';
    final city     = salon['city']           as String? ?? '';
    final address  = salon['address']        as String? ?? '';
    final open     = salon['openingTime']    as String?;
    final close    = salon['closingTime']    as String?;
    final rating   = (salon['rating']        as num?)?.toDouble() ?? 0.0;
    final reviews  = (salon['reviewCount']   as num?)?.toInt()   ?? 0;

    final locationStr = [address, city]
        .where((e) => e.isNotEmpty)
        .join(', ');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SalonDetailScreen(
            salonId:     salonId,
            salonName:   name,
            address:     address,
            city:        city,
            rating:      rating,
            reviewCount: reviews,
            initialDate: DateTime.now(),
          ),
        ),
      ),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.content_cut, color: primary, size: 22),
          ),

          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                StarRating(
                    rating: rating,
                    reviewCount: reviews,
                    compact: true,
                    starSize: 13),
                if (locationStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locationStr,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
                if (open != null && close != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.access_time, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('$open – $close',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ]),
                ],
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: () => _remove(salonId),
            icon: Icon(Icons.favorite_rounded, color: Colors.red.shade400),
            tooltip: 'Remove from wishlist',
          ),
        ],
      ),
    ), // Container
    ); // GestureDetector
  }
}
