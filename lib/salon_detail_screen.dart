import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/api_service.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/error_retry.dart';
import 'widgets/loading_widget.dart';
import 'widgets/star_rating.dart';
import 'widgets/salon_thumb.dart';
import 'booking_summary_screen.dart';

class SalonDetailScreen extends StatefulWidget {
  final String salonId;
  final String salonName;
  final String? address;
  final String? city;
  final double? rating;
  final int? reviewCount;
  final DateTime initialDate;

  const SalonDetailScreen({
    super.key,
    required this.salonId,
    required this.salonName,
    this.address,
    this.city,
    this.rating,
    this.reviewCount,
    required this.initialDate,
  });

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _hasError = false;
  bool _planLimitReached = false;

  // Selected service ids + their data
  final Map<String, Map<String, dynamic>> _selectedServices = {};

  // Computed
  double get _totalAmount =>
      _selectedServices.values.fold(0, (s, v) => s + ((v['price'] as num?) ?? 0));
  int get _totalDuration =>
      _selectedServices.values.fold(0, (s, v) => s + ((v['duration'] as num?) ?? 30).toInt());

  List<dynamic> get _services => (_detail?['services'] as List?) ?? [];
  List<dynamic> get _amenities => (_detail?['amenities'] as List?) ?? [];
  List<dynamic> _reviews = [];
  List<dynamic> _offers  = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final results = await Future.wait([
        ApiService.getSalonDetail(widget.salonId),
        ApiService.getSalonReviews(widget.salonId),
        ApiService.getMonthlyBookingCount(),
        ApiService.getSubscription(),
        ApiService.getSalonOffers(widget.salonId),
      ]);
      if (mounted) {
        final monthlyCount = results[2] as int;
        final sub          = results[3] as Map<String, dynamic>;
        // '' as the unknown sentinel — API errors must not block paid users.
        final plan         = sub['plan']?.toString() ?? '';
        setState(() {
          _detail           = results[0] as Map<String, dynamic>?;
          _reviews          = results[1] as List<dynamic>;
          _planLimitReached = plan == 'free' && monthlyCount >= 2;
          _offers           = results[4] as List<dynamic>;
          _loading          = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  void _showAllReviews() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewsSheet(
        salonName: widget.salonName,
        reviews: _reviews,
      ),
    );
  }

  void _toggleService(Map<String, dynamic> svc) {
    HapticFeedback.selectionClick();
    final id = svc['id'] as String;
    setState(() {
      if (_selectedServices.containsKey(id)) {
        _selectedServices.remove(id);
      } else {
        _selectedServices[id] = svc;
      }
    });
  }

  void _openSlotPicker() async {
    if (_selectedServices.isEmpty) {
      AppSnackbar.error(context, 'Please select at least one service.');
      return;
    }
    // Parse workingDays from salon detail (e.g. "Mon,Tue,Wed,Thu,Fri,Sat")
    final rawDays   = _detail?['workingDays'] as String? ?? '';
    final workingDays = rawDays.isEmpty
        ? <String>[]
        : rawDays.split(',').map((d) => d.trim()).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SlotPickerSheet(
        salonId:     widget.salonId,
        initialDate: widget.initialDate,
        workingDays: workingDays,
        onSlotSelected: (date, slot) {
          Navigator.pop(context);
          _goToSummary(date, slot);
        },
      ),
    );
  }

  void _goToSummary(DateTime date, Map<String, dynamic> slot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingSummaryScreen(
          salonId: widget.salonId,
          salonName: widget.salonName,
          address: widget.address ?? '',
          city: widget.city ?? '',
          scheduledAt: slot['time'] as String,
          displayTime: slot['displayTime'] as String,
          bookingDate: date,
          selectedServices: _selectedServices.values.toList(),
          totalAmount: _totalAmount,
          totalDuration: _totalDuration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.salonName,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const AppLoadingIndicator(message: 'Loading salon…')
          : _hasError
              ? ErrorRetry(onRetry: _load)
              : _detail == null
                  ? const Center(child: Text('Salon not found'))
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isTablet ? 32 : 16, 0,
                        isTablet ? 32 : 16, 120,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildInfoCard(primary),
                          const SizedBox(height: 20),
                          _buildServicesSection(primary),
                          if (_amenities.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildAmenitiesSection(),
                          ],
                          if (_offers.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildOffersSection(),
                          ],
                          if (_reviews.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildReviewsSection(),
                          ],
                        ],
                      ),
                    ),
                    _buildBottomBar(primary),
                  ],
                ),
    );
  }

  // ── Salon info card ─────────────────────────────────────────────────────────

  Widget _buildInfoCard(Color primary) {
    final rating      = ((_detail?['rating'] as num?)?.toDouble() ?? widget.rating ?? 0);
    final reviewCount = ((_detail?['reviewCount'] as num?)?.toInt() ?? widget.reviewCount ?? 0);
    final address     = widget.address ?? (_detail?['address'] as String? ?? '');
    final city        = widget.city ?? (_detail?['city'] as String? ?? '');
    final open        = _detail?['openingTime'] as String?;
    final close       = _detail?['closingTime'] as String?;
    final barberCount = (_detail?['barberCount'] as num?)?.toInt() ?? 0;
    final rawDays      = _detail?['workingDays'] as String? ?? '';
    final workingDays  = rawDays.isEmpty
        ? <String>[]
        : rawDays.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    final locationStr  = [address, city].where((e) => e.isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SalonThumb(
              imageUrl: _detail?['image'] as String?,
              size: 48,
              primary: primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.salonName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                GestureDetector(
          onTap: _reviews.isNotEmpty ? _showAllReviews : null,
          child: StarRating(rating: rating, reviewCount: reviewCount, compact: true, starSize: 13),
        ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          if (locationStr.isNotEmpty)
            Row(children: [
              Expanded(child: _infoRow(Icons.location_on_outlined, locationStr)),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query='
                    '${Uri.encodeComponent(locationStr)}',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Tooltip(
                  message: 'Get Directions',
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.directions_outlined,
                        size: 16, color: Colors.blue.shade700),
                  ),
                ),
              ),
            ]),
          if (open != null && close != null)
            _infoRow(Icons.access_time, '$open – $close'),
          if (workingDays.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: workingDays.map((d) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(d,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500)),
              )).toList(),
            ),
            const SizedBox(height: 4),
          ],
          if (barberCount > 0)
            _infoRow(Icons.person_outline, '$barberCount barber${barberCount == 1 ? '' : 's'} available'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ── Services section ────────────────────────────────────────────────────────

  Widget _buildServicesSection(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Services',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Choose one or more services',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        ..._services.map((svc) {
          final id = svc['id'] as String;
          final name = svc['serviceName'] as String? ?? svc['name'] as String? ?? '';
          final price = (svc['price'] as num?)?.toDouble() ?? 0;
          final duration = (svc['duration'] as num?)?.toInt() ?? 30;
          final selected = _selectedServices.containsKey(id);

          return GestureDetector(
            onTap: () => _toggleService(svc as Map<String, dynamic>),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? primary.withValues(alpha: 0.07) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? primary : Colors.grey.shade200,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: selected ? primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? primary : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected ? primary : Colors.black87,
                          )),
                      const SizedBox(height: 2),
                      Text('$duration min',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Text('₹${price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: selected ? primary : Colors.black87,
                    )),
              ]),
            ),
          );
        }),
      ],
    );
  }

  // ── Amenities section ───────────────────────────────────────────────────────

  Widget _buildAmenitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amenities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _amenities.map((a) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(a.toString(),
                  style: TextStyle(fontSize: 12,
                      color: Colors.teal.shade700, fontWeight: FontWeight.w500)),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Offers section ──────────────────────────────────────────────────────────

  Widget _buildOffersSection() {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.local_offer_outlined, size: 18, color: primary),
          const SizedBox(width: 8),
          const Text('Offers & Promotions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        ..._offers.map((o) {
          final offer      = o as Map<String, dynamic>;
          final title      = offer['title'] as String? ?? '';
          final desc       = offer['description'] as String? ?? '';
          final disc       = (offer['discountPercent'] as num?)?.toInt() ?? 0;
          final validUntil = offer['validUntil'] != null
              ? DateTime.tryParse(offer['validUntil'] as String)
              : null;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_offer_outlined, size: 16, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      if (disc > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$disc% OFF',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                    ]),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(desc,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                    if (validUntil != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Valid till ${DateFormat('d MMM yyyy').format(validUntil)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }

  // ── Reviews section ─────────────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Customer Reviews',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text('${_reviews.length}',
                style: TextStyle(fontSize: 11, color: Colors.amber.shade800,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),
        ..._reviews.take(5).map((r) => _reviewTile(r as Map<String, dynamic>)),
        if (_reviews.length > 5) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              icon: Icon(Icons.expand_more, size: 18, color: primary),
              label: Text(
                'View all ${_reviews.length} reviews',
                style: TextStyle(color: primary, fontWeight: FontWeight.w500),
              ),
              onPressed: _showAllReviews,
              style: TextButton.styleFrom(foregroundColor: primary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _reviewTile(Map<String, dynamic> review) {
    final rating   = (review['rating'] as num?)?.toInt() ?? 0;
    final comment  = review['comment'] as String? ?? '';
    final reviewer = review['reviewerName'] as String? ?? 'Customer';
    final dt = DateTime.tryParse(review['createdAt'] as String? ?? '');
    final dateStr  = dt != null ? DateFormat('d MMM yyyy').format(dt.toLocal()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Row(children: List.generate(5, (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14, color: Colors.amber.shade500,
          ))),
          const SizedBox(width: 8),
          Expanded(child: Text(reviewer,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(dateStr,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(comment,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }

  // ── Bottom bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar(Color primary) {
    final hasSelection = _selectedServices.isNotEmpty;

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12, offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Free plan limit notice ──────────────────────────────────
            if (_planLimitReached)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 14, color: Colors.red.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Free plan limit reached (2/2 bookings this month). '
                        'Upgrade to Basic or Pro to book more.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Amount + CTA row ────────────────────────────────────────
            Row(children: [
              if (hasSelection && !_planLimitReached) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${_totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primary)),
                    Text('~$_totalDuration min',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _planLimitReached ? null : _openSlotPicker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _planLimitReached ? Colors.grey.shade300 : primary,
                      foregroundColor:
                          _planLimitReached ? Colors.grey.shade500 : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                    ),
                    child: Text(
                      _planLimitReached
                          ? 'Booking Limit Reached'
                          : hasSelection
                              ? 'Choose Time Slot'
                              : 'Select Services to Book',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Slot picker bottom sheet ─────────────────────────────────────────────────

class _SlotPickerSheet extends StatefulWidget {
  final String salonId;
  final DateTime initialDate;
  /// Parsed list of open days, e.g. ['Mon','Tue','Wed','Thu','Fri','Sat'].
  /// Empty list means no restriction (treat every day as open).
  final List<String> workingDays;
  final void Function(DateTime date, Map<String, dynamic> slot) onSlotSelected;

  const _SlotPickerSheet({
    required this.salonId,
    required this.initialDate,
    required this.workingDays,
    required this.onSlotSelected,
  });

  @override
  State<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends State<_SlotPickerSheet> {
  late DateTime _selectedDate;
  List<dynamic> _slots = [];
  bool _loadingSlots = false;

  // Returns true when workingDays is unconfigured OR the day is in the list.
  bool _isWorkingDay(DateTime d) {
    if (widget.workingDays.isEmpty) return true;
    // DateFormat('EEE') gives 'Mon', 'Tue' … matching the stored abbreviations.
    return widget.workingDays.contains(DateFormat('EEE').format(d));
  }

  // Returns the next working day on-or-after [from] within the 14-day window.
  DateTime _nextWorkingDay(DateTime from) {
    for (int i = 0; i < 14; i++) {
      final d = from.add(Duration(days: i));
      if (_isWorkingDay(d)) return d;
    }
    return from; // fallback: no restriction found — return as-is
  }

  @override
  void initState() {
    super.initState();
    final now    = DateTime.now();
    final base   = widget.initialDate.isBefore(now)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(widget.initialDate.year, widget.initialDate.month,
            widget.initialDate.day);
    // Auto-advance to the first working day so the user never sees a
    // closed-day selected by default.
    _selectedDate = _nextWorkingDay(base);
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() => _loadingSlots = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final slots = await ApiService.getAvailableSlots(
        salonId: widget.salonId, date: dateStr);
    if (mounted) setState(() { _slots = slots; _loadingSlots = false; });
  }

  Widget _buildEmptyState() {
    // If the selected day is not in the working-days list, show a specific
    // "closed" message rather than the generic "no slots" one.
    final isClosed = !_isWorkingDay(_selectedDate);
    final dayName  = DateFormat('EEEE').format(_selectedDate); // e.g. "Sunday"

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isClosed ? Icons.store_outlined : Icons.event_busy_outlined,
              size: 44,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              isClosed
                  ? 'Salon is closed on $dayName'
                  : 'No slots available for this date',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              isClosed
                  ? 'Please choose another day from the date strip above.'
                  : 'All slots are booked for this date. Try a different day.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final today   = DateTime.now();

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('Pick a Time Slot',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Date strip ─────────────────────────────────────────────────
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 14, // show 2 weeks so there's always a working day
              itemBuilder: (_, i) {
                final d        = today.add(Duration(days: i));
                final isOpen   = _isWorkingDay(d);
                final selected = isOpen &&
                    d.year  == _selectedDate.year &&
                    d.month == _selectedDate.month &&
                    d.day   == _selectedDate.day;

                return GestureDetector(
                  // Tap disabled for closed days
                  onTap: isOpen ? () {
                    setState(() => _selectedDate = d);
                    _loadSlots();
                  } : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 10),
                    width: 58,
                    decoration: BoxDecoration(
                      color: selected
                          ? primary
                          : isOpen
                              ? Colors.grey.shade100
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: isOpen
                          ? null
                          : Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE').format(d),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white70
                                  : isOpen
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade300,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.day.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? Colors.white
                                  : isOpen
                                      ? Colors.black87
                                      : Colors.grey.shade300,
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(d),
                            style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? Colors.white70
                                  : isOpen
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade300,
                            ),
                          ),
                          // Small "Closed" label under the date
                          if (!isOpen)
                            Text('Closed',
                                style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey.shade400)),
                        ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 8),

          // ── Slots grid ─────────────────────────────────────────────────
          Expanded(
            child: _loadingSlots
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _slots.length,
                        itemBuilder: (_, i) {
                          final slot      = _slots[i] as Map<String, dynamic>;
                          final available = slot['available'] as bool? ?? false;
                          final time      = slot['displayTime'] as String? ?? '';
                          final remaining = (slot['remainingSlots'] as num?)?.toInt() ?? 0;

                          return GestureDetector(
                            onTap: available
                                ? () => widget.onSlotSelected(
                                    _selectedDate, slot)
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              decoration: BoxDecoration(
                                color: available
                                    ? primary.withValues(alpha: 0.08)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: available
                                      ? primary.withValues(alpha: 0.35)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(time,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: available
                                            ? primary
                                            : Colors.grey.shade400,
                                      )),
                                  if (available && remaining < 3)
                                    Text('$remaining left',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.orange.shade600)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── All-reviews bottom sheet (customer-facing) ────────────────────────────────

class _ReviewsSheet extends StatelessWidget {
  final String salonName;
  final List<dynamic> reviews;
  const _ReviewsSheet({required this.salonName, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Customer Reviews',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(salonName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text('${reviews.length}',
                  style: TextStyle(
                      fontSize: 13, color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        Divider(height: 1, color: Colors.grey.shade100),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: reviews.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r        = reviews[i] as Map<String, dynamic>;
              final rating   = (r['rating'] as num?)?.toInt() ?? 0;
              final comment  = r['comment'] as String? ?? '';
              final reviewer = r['reviewerName'] as String? ?? 'Customer';
              final dt = DateTime.tryParse(r['createdAt'] as String? ?? '');
              final dateStr  = dt != null
                  ? DateFormat('d MMM yyyy').format(dt.toLocal()) : '';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Row(children: List.generate(5, (j) => Icon(
                      j < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14, color: Colors.amber.shade500,
                    ))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(reviewer,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(dateStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ]),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comment,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700,
                            height: 1.5)),
                  ],
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
