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
import 'barber_profile_screen.dart';

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
  Map<String, dynamic>? _queueInfo;
  bool _loading = true;
  bool _hasError = false;
  bool   _planLimitReached = false;
  String _customerPlan     = '';

  // Selected service ids + their data
  final Map<String, Map<String, dynamic>> _selectedServices = {};

  // Computed
  double get _totalAmount =>
      _selectedServices.values.fold(0, (s, v) => s + ((v['price'] as num?) ?? 0));
  int get _totalDuration =>
      _selectedServices.values.fold(0, (s, v) => s + ((v['duration'] as num?) ?? 30).toInt());

  List<dynamic> get _services => (_detail?['services'] as List?) ?? [];
  List<dynamic> get _amenities => (_detail?['amenities'] as List?) ?? [];
  List<dynamic> _reviews   = [];
  List<dynamic> _offers    = [];
  List<dynamic> _portfolio = [];

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
        ApiService.getSalonQueue(widget.salonId),
        ApiService.getSalonPortfolio(widget.salonId),
      ]);
      if (mounted) {
        final monthlyCount = results[2] as int;
        final sub          = results[3] as Map<String, dynamic>;
        final plan         = sub['plan']?.toString() ?? '';
        setState(() {
          _detail           = results[0] as Map<String, dynamic>?;
          _reviews          = results[1] as List<dynamic>;
          _planLimitReached = plan == 'free' && monthlyCount >= 2;
          _customerPlan     = plan;
          _offers           = results[4] as List<dynamic>;
          _queueInfo        = results[5] as Map<String, dynamic>;
          _portfolio        = results[6] as List<dynamic>;
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

  bool _isTodayBookingWindowClosed() {
    final now = DateTime.now();
    final isToday = widget.initialDate.year == now.year &&
        widget.initialDate.month == now.month &&
        widget.initialDate.day == now.day;
    if (!isToday) return false;
    final closingStr = _detail?['closingTime'] as String?;
    if (closingStr == null || !closingStr.contains(':')) return false;
    final parts = closingStr.split(':');
    final cH = int.tryParse(parts[0]) ?? 23;
    final cM = int.tryParse(parts[1]) ?? 59;
    return now.isAfter(DateTime(now.year, now.month, now.day, cH, cM));
  }

  void _showReportDialog(BuildContext ctx) {
    const reasons = [
      'Inappropriate behavior',
      'Fraud or scam',
      'Poor service quality',
      'Health & safety concern',
      'Fake reviews / misleading info',
      'Other',
    ];
    String? selectedReason;
    String selectedSeverity = 'minor';
    final descCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Report Salon', style: TextStyle(fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...reasons.map((r) => RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(r, style: const TextStyle(fontSize: 13)),
                value: r,
                groupValue: selectedReason,
                activeColor: const Color(0xFF1565C0),
                onChanged: (v) => setS(() => selectedReason = v),
              )),
              const SizedBox(height: 8),
              const Text('Severity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                for (final s in ['minor', 'major'])
                  Expanded(child: Padding(
                    padding: EdgeInsets.only(right: s == 'minor' ? 6 : 0),
                    child: ChoiceChip(
                      label: Text(s == 'minor' ? 'Minor' : 'Major',
                          style: TextStyle(fontSize: 12,
                              color: selectedSeverity == s ? Colors.white : Colors.black87)),
                      selected: selectedSeverity == s,
                      selectedColor: s == 'major' ? Colors.red.shade600 : Colors.orange.shade600,
                      backgroundColor: Colors.grey.shade100,
                      onSelected: (_) => setS(() => selectedSeverity = s),
                    ),
                  )),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (selectedReason == null) return;
                Navigator.pop(dCtx);
                try {
                  await ApiService.submitComplaint(
                    type: 'salon',
                    targetId: widget.salonId,
                    reason: selectedReason!,
                    description: descCtrl.text.trim(),
                    severity: selectedSeverity,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted. Thank you for your feedback.')),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to submit report. Please try again.')),
                    );
                  }
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTodayClosedDialog() {
    final phone = (_detail?['contactNumber'] as String?) ?? '';
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Looks like today's fully booked online",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "The online booking window for today has closed.\n\n"
              "Give them a quick call — they might still squeeze you in.",
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.phone_outlined,
                        color: Colors.green.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      phone,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
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
              _openSlotPickerFromDate(
                  DateTime.now().add(const Duration(days: 1)));
            },
            child: const Text('Book for Tomorrow Instead'),
          ),
        ],
      ),
    );
  }

  void _openSlotPicker() async {
    if (_selectedServices.isEmpty) {
      AppSnackbar.error(context, 'Ready to look fresh? Pick a service first.');
      return;
    }
    if (_isTodayBookingWindowClosed()) {
      _showTodayClosedDialog();
      return;
    }
    _openSlotPickerFromDate(widget.initialDate);
  }

  void _openSlotPickerFromDate(DateTime from) async {
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
        salonId:       widget.salonId,
        initialDate:   from,
        workingDays:   workingDays,
        closingTime:   _detail?['closingTime'] as String?,
        contactNumber: (_detail?['contactNumber'] as String?) ?? '',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report',
            onPressed: () => _showReportDialog(context),
          ),
        ],
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
                          if ((_detail?['barbers'] as List?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 20),
                            _buildBarbersSection(primary),
                          ],
                          if (_portfolio.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildPortfolioSection(),
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
          _buildQueueRow(),
        ],
      ),
    );
  }

  Widget _buildQueueRow() {
    if (_queueInfo == null) return const SizedBox.shrink();
    final queueSize = (_queueInfo!['queueSize'] as num?)?.toInt() ?? 0;
    final waitMins  = (_queueInfo!['estimatedWaitMins'] as num?)?.toInt() ?? 0;
    final available = _queueInfo!['isAvailable'] as bool? ?? true;

    final color = available ? Colors.green.shade700 : Colors.orange.shade700;
    final bg    = available ? Colors.green.shade50  : Colors.orange.shade50;
    final icon  = available ? Icons.check_circle_outline : Icons.people_alt_outlined;
    final label = available
        ? 'Available now — no wait'
        : '$queueSize ${queueSize == 1 ? 'person' : 'people'} ahead · ~$waitMins min wait';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
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

  // ── Barbers section ─────────────────────────────────────────────────────────

  Widget _buildBarbersSection(Color primary) {
    final barbers = (_detail!['barbers'] as List).cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.people_outline, size: 18, color: primary),
          const SizedBox(width: 8),
          const Text('Our Barbers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: barbers.length,
            separatorBuilder: (_, si) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final b = barbers[i];
              final name = b['name'] as String? ?? 'Barber';
              final spec = b['specialization'] as String?;
              final photo = b['photoUrl'] as String?;
              final exp = (b['experience'] as num?)?.toInt() ?? 0;
              final available = b['isAvailable'] as bool? ?? true;
              final leaveUntil = b['leaveUntil'] as String?;
              final breakUntil = b['breakUntil'] as String?;

              final statusDot = leaveUntil != null
                  ? Colors.red.shade500
                  : breakUntil != null
                      ? Colors.orange.shade500
                      : available
                          ? Colors.green.shade500
                          : Colors.grey.shade400;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BarberProfileScreen(
                      barberId: b['id'] as String,
                      barberName: name,
                    ),
                  ),
                ),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          _barberAvatarSmall(photo, name, primary),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: statusDot,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      if (spec != null && spec.isNotEmpty)
                        Text(spec,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                      Text(exp == 0 ? 'New' : '${exp}yr exp',
                          style: TextStyle(
                              fontSize: 10, color: primary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _barberAvatarSmall(String? photo, String name, Color primary) {
    if (photo != null && photo.isNotEmpty) {
      final url = photo.startsWith('http') ? photo : '${ApiService.baseUrl}$photo';
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(url),
        backgroundColor: primary.withValues(alpha: 0.1),
        onBackgroundImageError: (e, s) {},
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: primary.withValues(alpha: 0.1),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: primary),
      ),
    );
  }

  // ── Portfolio section ────────────────────────────────────────────────────────

  Widget _buildPortfolioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.photo_library_outlined, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          const Text('Portfolio',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${_portfolio.length}',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _portfolio.length,
            separatorBuilder: (_, si) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final item = _portfolio[i] as Map<String, dynamic>;
              final type = item['type'] as String? ?? 'portfolio';
              final photoUrl = item['photoUrl'] as String? ?? '';
              final beforeUrl = item['beforeUrl'] as String?;
              final caption = item['caption'] as String?;
              final isBeforeAfter = type == 'before_after' && beforeUrl != null;

              return GestureDetector(
                onTap: () => _showPortfolioViewer(item),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: isBeforeAfter ? 200 : 110,
                    child: isBeforeAfter
                        ? _beforeAfterCard(beforeUrl, photoUrl, caption)
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              _portfolioImage(photoUrl),
                              if (caption != null && caption.isNotEmpty)
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    color: Colors.black45,
                                    child: Text(caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.white)),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _beforeAfterCard(String beforeUrl, String afterUrl, String? caption) {
    return Row(children: [
      Expanded(
        child: Stack(fit: StackFit.expand, children: [
          _portfolioImage(beforeUrl),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: const Text('Before',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
      Container(width: 2, color: Colors.white),
      Expanded(
        child: Stack(fit: StackFit.expand, children: [
          _portfolioImage(afterUrl),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: const Text('After',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _portfolioImage(String url) {
    if (url.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
      );
    }
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    return Image.network(fullUrl, fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: Colors.grey.shade200,
          child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
        ));
  }

  void _showPortfolioViewer(Map<String, dynamic> item) {
    final type = item['type'] as String? ?? 'portfolio';
    final photoUrl = item['photoUrl'] as String? ?? '';
    final beforeUrl = item['beforeUrl'] as String?;
    final caption = item['caption'] as String?;
    final isBeforeAfter = type == 'before_after' && beforeUrl != null;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          if (isBeforeAfter)
            Row(children: [
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  InteractiveViewer(child: _portfolioImage(beforeUrl)),
                  const Positioned(
                    bottom: 60, left: 0, right: 0,
                    child: Text('Before',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              Container(width: 2, color: Colors.white24),
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  InteractiveViewer(child: _portfolioImage(photoUrl)),
                  const Positioned(
                    bottom: 60, left: 0, right: 0,
                    child: Text('After',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            ])
          else
            SizedBox.expand(
              child: InteractiveViewer(child: _portfolioImage(photoUrl)),
            ),
          Positioned(
            top: 40, right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          if (caption != null && caption.isNotEmpty)
            Positioned(
              bottom: 40, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13)),
              ),
            ),
        ]),
      ),
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
            // ── Priority access banner (Basic / Pro members) ───────────
            if (_customerPlan == 'basic' || _customerPlan == 'pro')
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF66BB6A)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.rocket_launch_outlined,
                        size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _customerPlan == 'pro'
                            ? 'Pro Member — priority slot access & exclusive deals.'
                            : 'Basic Member — priority slot access active.',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ),
              ),

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
                          ? 'Upgrade to Book More'
                          : hasSelection
                              ? 'Reserve Your Chair'
                              : 'What\'s your vibe today?',
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
  final String? closingTime;
  final String contactNumber;
  final void Function(DateTime date, Map<String, dynamic> slot) onSlotSelected;

  const _SlotPickerSheet({
    required this.salonId,
    required this.initialDate,
    required this.workingDays,
    this.closingTime,
    this.contactNumber = '',
    required this.onSlotSelected,
  });

  @override
  State<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends State<_SlotPickerSheet> {
  late DateTime _selectedDate;
  List<dynamic> _slots = [];
  bool _loadingSlots = false;
  String? _tappedSlotTime; // tracks the briefly-highlighted slot

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

  bool _isPastClosingTime() {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    if (!isToday) return false;
    final ct = widget.closingTime;
    if (ct == null || !ct.contains(':')) return false;
    final parts = ct.split(':');
    final cH = int.tryParse(parts[0]) ?? 23;
    final cM = int.tryParse(parts[1]) ?? 59;
    return now.isAfter(DateTime(now.year, now.month, now.day, cH, cM));
  }

  Widget _buildEmptyState() {
    final isClosed = !_isWorkingDay(_selectedDate);
    final dayName  = DateFormat('EEEE').format(_selectedDate);
    final pastClose = _isPastClosingTime();

    if (pastClose) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store_outlined, size: 44, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text(
                "Online slots are closed for today",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                "Give them a quick call — they might still fit you in.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (widget.contactNumber.isNotEmpty) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse('tel:${widget.contactNumber}');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_outlined,
                            color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          widget.contactNumber,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

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
                  ? 'Closed on $dayName'
                  : 'Fully booked for this date',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              isClosed
                  ? 'Choose another day from the strip above.'
                  : 'All chairs are taken — try a different day.',
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
              const Text('Choose your chair time',
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
                ? GridView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 16,
                    itemBuilder: (_, i) => const _SlotSkeleton(),
                  )
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
                          final isTapped  = _tappedSlotTime == time;

                          return GestureDetector(
                            onTap: available ? () async {
                              HapticFeedback.lightImpact();
                              setState(() => _tappedSlotTime = time);
                              await Future.delayed(
                                  const Duration(milliseconds: 180));
                              if (mounted) {
                                setState(() => _tappedSlotTime = null);
                                widget.onSlotSelected(_selectedDate, slot);
                              }
                            } : null,
                            child: AnimatedScale(
                              scale: isTapped ? 0.90 : 1.0,
                              duration: const Duration(milliseconds: 120),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  color: isTapped
                                      ? primary
                                      : available
                                          ? primary.withValues(alpha: 0.08)
                                          : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: available
                                        ? primary.withValues(alpha: 0.35)
                                        : Colors.grey.shade200,
                                  ),
                                  boxShadow: isTapped
                                      ? [BoxShadow(
                                          color: primary.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2))]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(time,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isTapped
                                              ? Colors.white
                                              : available
                                                  ? primary
                                                  : Colors.grey.shade400,
                                        )),
                                    if (available && remaining < 3)
                                      Text('$remaining left',
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: isTapped
                                                  ? Colors.white70
                                                  : Colors.orange.shade600)),
                                  ],
                                ),
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

// ── Slot skeleton chip ────────────────────────────────────────────────────────

class _SlotSkeleton extends StatefulWidget {
  const _SlotSkeleton();

  @override
  State<_SlotSkeleton> createState() => _SlotSkeletonState();
}

class _SlotSkeletonState extends State<_SlotSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Color.lerp(
              Colors.grey.shade200, Colors.grey.shade100, _anim.value),
        ),
      ),
    );
  }
}
