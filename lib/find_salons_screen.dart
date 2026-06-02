import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/api_service.dart';
import 'services/location_prefs.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/error_retry.dart';
import 'widgets/loading_widget.dart';
import 'widgets/star_rating.dart';
import 'salon_detail_screen.dart';
import 'subscriptions_screen.dart';

// ─── Sort options ─────────────────────────────────────────────────────────────

class _SortOption {
  final String value;
  final String label;
  final IconData icon;
  const _SortOption(this.value, this.label, this.icon);
}

const _sortOptions = [
  _SortOption('distance_asc',   'Nearest First',    Icons.near_me),
  _SortOption('distance_desc',  'Farthest First',   Icons.near_me_disabled),
  _SortOption('rating_desc',    'Best Rated',        Icons.star_rounded),
  _SortOption('reviews_desc',   'Most Popular',      Icons.people_alt_outlined),
  _SortOption('relevance_desc', 'Most Relevant',     Icons.recommend_outlined),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class FindSalonsScreen extends StatefulWidget {
  final SavedLocation location;
  final DateTime      date;

  const FindSalonsScreen({
    super.key,
    required this.location,
    required this.date,
  });

  @override
  State<FindSalonsScreen> createState() => _FindSalonsScreenState();
}

class _FindSalonsScreenState extends State<FindSalonsScreen> {
  // Data
  List<Map<String, dynamic>> _salons       = [];
  List<String>               _allAmenities = [];
  List<String>               _allServices  = [];
  Set<String>                _wishlistIds  = {};
  String                     _customerPlan = 'free';

  // Active filters
  Set<String> _selAmenities = {};
  Set<String> _selServices  = {};
  String      _sort         = 'distance_asc';

  // Search
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  bool _loading = true;
  bool _hasError = false;

  // Computed: salons filtered by the live search query
  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _salons;
    final q = _searchQuery.toLowerCase();
    return _salons.where((s) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      final city = (s['city'] as String? ?? '').toLowerCase();
      return name.contains(q) || city.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final results = await Future.wait([
        ApiService.searchSalons(
          lat:       widget.location.lat,
          lng:       widget.location.lng,
          radiusKm:  5.0,
          amenities: _selAmenities.toList(),
          services:  _selServices.toList(),
          sort:      _sort,
        ),
        ApiService.getAmenities(),
        ApiService.getServices(),
        ApiService.getWishlistIds(),
        ApiService.getSubscription().catchError((_) => <String, dynamic>{}),
      ]);

      if (!mounted) return;
      final subData = results[4] as Map<String, dynamic>;
      setState(() {
        _salons       = List<Map<String, dynamic>>.from(results[0] as List);
        _allAmenities = (results[1] as List)
            .map((e) => (e['name'] as String?) ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        _allServices  = (results[2] as List)
            .map((e) => (e['name'] as String?) ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        _wishlistIds  = results[3] as Set<String>;
        _customerPlan = (subData['plan'] as String?) ?? 'free';
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _loadAll();

  static const _kWishlistFreeLimit = 10;

  Future<void> _toggleWishlist(String salonId) async {
    final isWishlisted = _wishlistIds.contains(salonId);

    // Enforce wishlist limit for free plan before making any network call
    if (!isWishlisted &&
        _customerPlan == 'free' &&
        _wishlistIds.length >= _kWishlistFreeLimit) {
      _showWishlistUpgradeDialog();
      return;
    }

    // Optimistic update
    setState(() {
      if (isWishlisted) {
        _wishlistIds.remove(salonId);
      } else {
        _wishlistIds.add(salonId);
      }
    });

    try {
      if (isWishlisted) {
        await ApiService.removeFromWishlist(salonId);
      } else {
        await ApiService.addToWishlist(salonId);
      }
      if (!mounted) return;
      AppSnackbar.success(
        context,
        isWishlisted ? 'Removed from wishlist' : 'Added to wishlist',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (isWishlisted) {
          _wishlistIds.add(salonId);
        } else {
          _wishlistIds.remove(salonId);
        }
      });
      if (e.message.contains('WISHLIST_LIMIT')) {
        AppSnackbar.warning(
          context,
          'Wishlist limit reached (10 salons). Upgrade to Basic or Pro for unlimited wishlist.',
        );
      } else {
        AppSnackbar.error(context, 'Could not update wishlist. Try again.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isWishlisted) {
          _wishlistIds.add(salonId);
        } else {
          _wishlistIds.remove(salonId);
        }
      });
      AppSnackbar.error(context, 'Could not update wishlist. Try again.');
    }
  }

  void _showWishlistUpgradeDialog() {
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: Colors.amber, size: 22),
          ),
          const SizedBox(width: 12),
          const Text('Wishlist Full',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Free plan allows up to 10 saved salons.\n\nUpgrade to Basic or Pro for an unlimited wishlist.',
          style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SubscriptionsScreen()));
            },
            child: const Text('Upgrade'),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Filter sheet helpers ───────────────────────────────────────────────────

  void _openAmenitiesFilter() async {
    final result = await _showCheckboxSheet(
      title:    'Amenities',
      all:      _allAmenities,
      selected: _selAmenities,
    );
    if (result != null && mounted) {
      setState(() => _selAmenities = result);
      _loadAll();
    }
  }

  void _openServicesFilter() async {
    final result = await _showCheckboxSheet(
      title:    'Services',
      all:      _allServices,
      selected: _selServices,
    );
    if (result != null && mounted) {
      setState(() => _selServices = result);
      _loadAll();
    }
  }

  void _openSortSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SortSheet(current: _sort),
    );
    if (result != null && mounted) {
      setState(() => _sort = result);
      _loadAll();
    }
  }

  Future<Set<String>?> _showCheckboxSheet({
    required String title,
    required List<String> all,
    required Set<String> selected,
  }) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CheckboxSheet(
        title: title, all: all, initial: selected),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final primary  = Theme.of(context).colorScheme.primary;
    final dateStr  = _formatDate(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Salons'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sub-header ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: primary.withValues(alpha: 0.06),
            child: Row(children: [
              Icon(Icons.location_on, size: 15, color: primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${widget.location.name}  ·  $dateStr',
                  style: TextStyle(fontSize: 13, color: primary,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_loading)
                Text(
                  '${_filtered.length} salon${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: primary,
                      fontWeight: FontWeight.w600),
                ),
            ]),
          ),

          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search salon name or area…',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: primary.withValues(alpha: 0.5))),
              ),
            ),
          ),

          // ── Filter chips ──────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              _filterChip(
                label: _sort == 'distance_asc' ? 'Nearest First'
                    : _sortOptions
                        .firstWhere((o) => o.value == _sort,
                            orElse: () => _sortOptions.first)
                        .label,
                icon: Icons.sort,
                active: _sort != 'distance_asc',
                onTap: _openSortSheet,
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: _selAmenities.isEmpty
                    ? 'Amenities'
                    : 'Amenities (${_selAmenities.length})',
                icon: Icons.spa_outlined,
                active: _selAmenities.isNotEmpty,
                onTap: _openAmenitiesFilter,
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: _selServices.isEmpty
                    ? 'Services'
                    : 'Services (${_selServices.length})',
                icon: Icons.content_cut,
                active: _selServices.isNotEmpty,
                onTap: _openServicesFilter,
              ),
              if (_selAmenities.isNotEmpty || _selServices.isNotEmpty ||
                  _sort != 'distance_asc') ...[
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Clear All',
                  icon: Icons.close,
                  active: false,
                  onTap: () {
                    setState(() {
                      _selAmenities = {};
                      _selServices  = {};
                      _sort         = 'distance_asc';
                    });
                    _loadAll();
                  },
                ),
              ],
            ]),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // ── Results ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const AppLoadingIndicator(message: 'Finding salons nearby…')
                : _hasError
                    ? ErrorRetry(onRetry: _loadAll)
                    : _filtered.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 32 : 16,
                            vertical: 14,
                          ),
                          itemCount: _filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, i) =>
                              _buildSalonCard(_filtered[i], primary),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Filter chip ────────────────────────────────────────────────────────────

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? primary : Colors.grey.shade300,
          ),
          boxShadow: active
              ? [BoxShadow(color: primary.withValues(alpha: 0.2),
                    blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : Colors.grey.shade700,
              )),
        ]),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('No salons found within 1 km',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Try changing your location or\nremoving some filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Salon card ─────────────────────────────────────────────────────────────

  Widget _buildSalonCard(Map<String, dynamic> salon, Color primary) {
    final salonId         = salon['id']             as String;
    final name            = salon['name']           as String? ?? 'Salon';
    final city            = salon['city']           as String? ?? '';
    final address         = salon['address']        as String? ?? '';
    final open            = salon['openingTime']    as String?;
    final close           = salon['closingTime']    as String?;
    final dist            = salon['distance']       as num?;
    final rating          = (salon['rating']        as num?)?.toDouble() ?? 0.0;
    final reviews         = (salon['reviewCount']   as num?)?.toInt()   ?? 0;
    final services        = (salon['services']      as List?)?.cast<String>() ?? [];
    final amenities       = (salon['amenities']     as List?)?.cast<String>() ?? [];
    final featured        = salon['featured']        as bool? ?? false;
    final priorityListing = salon['priorityListing'] as bool? ?? false;
    final imageUrl        = salon['image']           as String?;
    final isWishlisted    = _wishlistIds.contains(salonId);

    final locationStr = [address, city].where((e) => e.isNotEmpty).join(', ');

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
            initialDate: widget.date,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top image ──────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            '${ApiService.baseUrl}$imageUrl',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                ),
                // Wishlist button overlay (top-right)
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => _toggleWishlist(salonId),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4)],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          key: ValueKey(isWishlisted),
                          size: 18,
                          color: isWishlisted ? Colors.red.shade400 : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ),
                // Distance badge overlay (top-left)
                if (dist != null)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${dist.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
              ],
            ),

            // ── Info section ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badges row
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (featured || priorityListing) ...[
                            const SizedBox(height: 3),
                            Wrap(spacing: 4, children: [
                              if (featured)
                                _badge('Featured', Colors.amber.shade700),
                              if (priorityListing)
                                _badge('Priority', Colors.purple.shade600),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StarRating(rating: rating, reviewCount: reviews,
                        compact: true, starSize: 13),
                  ]),

                  const SizedBox(height: 8),

                  // Location & hours
                  if (locationStr.isNotEmpty)
                    _infoRow(Icons.location_on_outlined, locationStr),
                  if (open != null && close != null)
                    _infoRow(Icons.access_time, '$open – $close'),

                  // Services chips
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 5,
                      children: [
                        ...services.take(4).map((s) => _chip(s, primary)),
                        if (services.length > 4)
                          _chip('+${services.length - 4} more',
                              Colors.grey.shade500, bg: Colors.grey.shade100),
                      ],
                    ),
                  ],

                  // Amenities chips
                  if (amenities.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: 5,
                      children: amenities.take(5).map((a) => _amenityChip(a)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.storefront_rounded, size: 40, color: Colors.grey.shade300),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  static IconData _amenityIcon(String name) {
    final key = name.toLowerCase();
    if (key.contains('ac') || key.contains('air')) return Icons.ac_unit;
    if (key.contains('wifi') || key.contains('wi-fi')) return Icons.wifi;
    if (key.contains('park')) return Icons.local_parking;
    if (key.contains('sanitiz') || key.contains('hygiene') || key.contains('clean')) {
      return Icons.clean_hands_outlined;
    }
    if (key.contains('family') || key.contains('kid')) return Icons.family_restroom;
    if (key.contains('card') || key.contains('payment') || key.contains('upi')) {
      return Icons.credit_card_outlined;
    }
    if (key.contains('premium') || key.contains('interior') || key.contains('luxury')) {
      return Icons.auto_awesome_outlined;
    }
    if (key.contains('tv') || key.contains('entertainment')) return Icons.tv;
    if (key.contains('wheelchair') || key.contains('accessible')) return Icons.accessible_outlined;
    if (key.contains('water') || key.contains('drink')) return Icons.local_drink_outlined;
    return Icons.check_circle_outline;
  }

  Widget _amenityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_amenityIcon(label), size: 11, color: Colors.teal.shade700),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color textColor, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? textColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: textColor,
              fontWeight: FontWeight.w500)),
    );
  }

  String _formatDate(DateTime d) {
    final today    = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Today';
    }
    if (d.year == tomorrow.year && d.month == tomorrow.month &&
        d.day == tomorrow.day) {
      return 'Tomorrow';
    }
    return DateFormat('d MMM yyyy').format(d);
  }
}

// ─── Sort bottom sheet ────────────────────────────────────────────────────────

class _SortSheet extends StatelessWidget {
  final String current;
  const _SortSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Sort By',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._sortOptions.map((opt) {
                final selected = opt.value == current;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? primary.withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(opt.icon,
                        size: 18, color: selected ? primary : Colors.grey),
                  ),
                  title: Text(opt.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.normal,
                        color: selected ? primary : Colors.black87,
                      )),
                  trailing: selected
                      ? Icon(Icons.check_circle_rounded, color: primary, size: 20)
                      : null,
                  onTap: () => Navigator.pop(context, opt.value),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Checkbox filter sheet ────────────────────────────────────────────────────

class _CheckboxSheet extends StatefulWidget {
  final String      title;
  final List<String> all;
  final Set<String>  initial;
  const _CheckboxSheet(
      {required this.title, required this.all, required this.initial});

  @override
  State<_CheckboxSheet> createState() => _CheckboxSheetState();
}

class _CheckboxSheetState extends State<_CheckboxSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              if (_selected.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: Text('Clear', style: TextStyle(color: primary)),
                ),
            ]),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: widget.all.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                          child: Text('No options available',
                              style: TextStyle(color: Colors.grey.shade400))),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: widget.all.map((item) {
                        final checked = _selected.contains(item);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item, style: const TextStyle(fontSize: 14)),
                          value: checked,
                          activeColor: primary,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(item);
                            } else {
                              _selected.remove(item);
                            }
                          }),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, _selected),
                child: Text(
                  _selected.isEmpty
                      ? 'Show All'
                      : 'Apply (${_selected.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
