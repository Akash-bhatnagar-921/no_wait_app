import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/api_service.dart';
import 'services/location_prefs.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/loading_widget.dart';
import 'widgets/star_rating.dart';

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

  // Active filters
  Set<String> _selAmenities = {};
  Set<String> _selServices  = {};
  String      _sort         = 'distance_asc';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.searchSalons(
          lat:       widget.location.lat,
          lng:       widget.location.lng,
          radiusKm:  1.0,
          amenities: _selAmenities.toList(),
          services:  _selServices.toList(),
          sort:      _sort,
        ),
        ApiService.getAmenities(),
        ApiService.getServices(),
      ]);

      if (!mounted) return;
      setState(() {
        _salons       = List<Map<String, dynamic>>.from(results[0]);
        _allAmenities = results[1]
            .map((e) => (e['name'] as String?) ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        _allServices  = results[2]
            .map((e) => (e['name'] as String?) ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.error(context, 'Failed to load salons. Please try again.');
      }
    }
  }

  Future<void> _refresh() => _loadAll();

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
                  '${_salons.length} salon${_salons.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: primary,
                      fontWeight: FontWeight.w600),
                ),
            ]),
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
                : _salons.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 32 : 16,
                            vertical: 14,
                          ),
                          itemCount: _salons.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, i) =>
                              _buildSalonCard(_salons[i], primary),
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
    final name     = salon['name']        as String? ?? 'Salon';
    final city     = salon['city']        as String? ?? '';
    final address  = salon['address']     as String? ?? '';
    final open     = salon['openingTime'] as String?;
    final close    = salon['closingTime'] as String?;
    final dist     = salon['distance']    as num?;
    final rating   = (salon['rating']     as num?)?.toDouble() ?? 0.0;
    final reviews  = (salon['reviewCount'] as num?)?.toInt()   ?? 0;
    final services = (salon['services']   as List?)?.cast<String>() ?? [];
    final amenities = (salon['amenities'] as List?)?.cast<String>() ?? [];

    final locationStr = [address, city]
        .where((e) => e.isNotEmpty)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name row
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.content_cut, color: primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  StarRating(rating: rating, reviewCount: reviews,
                      compact: true, starSize: 13),
                ],
              ),
            ),
            if (dist != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${dist.toStringAsFixed(2)} km',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: primary)),
              ),
          ]),

          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 10),

          // Location & hours
          if (locationStr.isNotEmpty)
            _infoRow(Icons.location_on_outlined, locationStr),
          if (open != null && close != null)
            _infoRow(Icons.access_time, '$open – $close'),

          // Services chips
          if (services.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                ...services.take(4).map((s) => _chip(s, primary)),
                if (services.length > 4)
                  _chip('+${services.length - 4} more', Colors.grey.shade500,
                      bg: Colors.grey.shade100),
              ],
            ),
          ],

          // Amenities chips
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: amenities
                  .take(4)
                  .map((a) => _chip(a, Colors.teal.shade700,
                      bg: Colors.teal.shade50))
                  .toList(),
            ),
          ],
        ],
      ),
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
