import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';

const Color _p = Color(0xFF1565C0);

class AdminSalonDetailPage extends StatefulWidget {
  final String salonId;
  final String initialName;
  final String initialStatus;

  const AdminSalonDetailPage({
    super.key,
    required this.salonId,
    required this.initialName,
    required this.initialStatus,
  });

  @override
  State<AdminSalonDetailPage> createState() => _AdminSalonDetailPageState();
}

class _AdminSalonDetailPageState extends State<AdminSalonDetailPage> {
  Map<String, dynamic>? _salon;
  bool _loadingSalon = true;

  List<dynamic> _bookings = [];
  int _bookingsTotal = 0;
  int _bookingsPage = 1;
  bool _loadingBookings = true;
  bool _loadingMoreBookings = false;
  String _bookingStatus = '';
  String _bookingDateFilter = '';
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _fetchSalon();
    _fetchBookings(reset: true);
  }

  // ── Data loaders ─────────────────────────────────────────────────────────────

  Future<void> _fetchSalon() async {
    try {
      final data = await ApiService.adminGetSalon(widget.salonId);
      if (mounted) setState(() { _salon = data; _loadingSalon = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSalon = false);
    }
  }

  String? get _dateFrom {
    final now = DateTime.now();
    switch (_bookingDateFilter) {
      case 'today':  return DateFormat('yyyy-MM-dd').format(now);
      case 'week':   return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6)));
      case 'month':  return DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
      case 'year':   return DateFormat('yyyy-MM-dd').format(DateTime(now.year, 1, 1));
      case 'custom': return _customFrom != null ? DateFormat('yyyy-MM-dd').format(_customFrom!) : null;
      default:       return null;
    }
  }

  String? get _dateTo {
    final now = DateTime.now();
    switch (_bookingDateFilter) {
      case 'today':
      case 'week':
      case 'month':
      case 'year':   return DateFormat('yyyy-MM-dd').format(now);
      case 'custom': return _customTo != null ? DateFormat('yyyy-MM-dd').format(_customTo!) : null;
      default:       return null;
    }
  }

  Future<void> _fetchBookings({bool reset = false}) async {
    if (reset) setState(() { _loadingBookings = true; _bookingsPage = 1; _bookings = []; });
    try {
      final res = await ApiService.adminGetSalonBookings(
        widget.salonId,
        page: _bookingsPage,
        status: _bookingStatus,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (mounted) {
        setState(() {
          final fetched = res['bookings'] as List<dynamic>? ?? [];
          _bookings = reset ? fetched : [..._bookings, ...fetched];
          _bookingsTotal = int.tryParse(res['total']?.toString() ?? '0') ?? 0;
          _loadingBookings = false;
          _loadingMoreBookings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loadingBookings = false; _loadingMoreBookings = false; });
    }
  }

  Future<void> _loadMoreBookings() async {
    if (_loadingMoreBookings || _bookings.length >= _bookingsTotal) return;
    setState(() { _bookingsPage++; _loadingMoreBookings = true; });
    _fetchBookings();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _customFrom != null && _customTo != null
          ? DateTimeRange(start: _customFrom!, end: _customTo!) : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _p)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() { _bookingDateFilter = 'custom'; _customFrom = picked.start; _customTo = picked.end; });
      _fetchBookings(reset: true);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _saveSalonField(String field, dynamic value, String displayLabel) async {
    try {
      await ApiService.adminUpdateSalon(widget.salonId, {field: value});
      if (mounted) {
        setState(() { _salon = {...?_salon, field: value}; });
        AppSnackbar.success(context, '$displayLabel updated.');
      }
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  void _showEditDialog(String title, String field, String current, {TextInputType? keyboard}) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $title', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          autofocus: true,
          decoration: InputDecoration(
            labelText: title,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _p, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              _saveSalonField(field, ctrl.text.trim(), title);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBanSalonDialog() async {
    double? selectedHours;
    final reasonCtrl = TextEditingController();
    const durations = [
      {'label': '6 Hours',   'hours': 6.0},
      {'label': '12 Hours',  'hours': 12.0},
      {'label': '1 Day',     'hours': 24.0},
      {'label': '3 Days',    'hours': 72.0},
      {'label': '1 Week',    'hours': 168.0},
      {'label': '1 Month',   'hours': 720.0},
      {'label': '3 Months',  'hours': 2160.0},
      {'label': 'Permanent', 'hours': null},
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ban Salon', style: TextStyle(fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: durations.map((d) {
                  final h = d['hours'] as double?;
                  final isSelected = selectedHours == h;
                  return ChoiceChip(
                    label: Text(d['label'] as String,
                        style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: h == null ? Colors.red.shade600 : Colors.orange.shade700,
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (_) => setS(() => selectedHours = h),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  );
                }).toList()),
                const SizedBox(height: 16),
                Text('Reason *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Fraud, repeated complaints…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ban Salon'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (reasonCtrl.text.trim().isEmpty) {
      AppSnackbar.error(context, 'Please enter a reason.');
      return;
    }
    try {
      await ApiService.adminBanSalon(
        widget.salonId,
        durationHours: selectedHours,
        reason: reasonCtrl.text.trim(),
      );
      if (mounted) AppSnackbar.success(context, 'Salon banned.');
      _fetchSalon();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _revokeSalonBan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Revoke Ban', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Restore access for "${_salon?['name'] ?? widget.initialName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke Ban'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.adminUnbanSalon(widget.salonId);
      if (mounted) AppSnackbar.success(context, 'Ban revoked.');
      _fetchSalon();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _approveSalon() async {
    try {
      await ApiService.adminApproveSalon(widget.salonId);
      if (mounted) {
        setState(() { _salon = {...?_salon, 'status': 'approved'}; });
        AppSnackbar.success(context, 'Salon approved.');
      }
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _rejectSalon() async {
    try {
      await ApiService.adminRejectSalon(widget.salonId);
      if (mounted) {
        setState(() { _salon = {...?_salon, 'status': 'rejected'}; });
        AppSnackbar.success(context, 'Salon rejected.');
      }
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  // ── Manager subscription management ──────────────────────────────────────────

  static const _professionalPlans = [
    {'value': 'free',                 'label': 'Free',    'price': 'Free'},
    {'value': 'professional_starter', 'label': 'Starter', 'price': '₹299/mo'},
    {'value': 'professional_growth',  'label': 'Growth',  'price': '₹599/mo'},
    {'value': 'professional_premium', 'label': 'Premium', 'price': '₹999/mo'},
  ];
  static const _durations = [30, 60, 90, 180, 365];

  static String _durationLabel(int days) {
    if (days == 30)  return '1 Month';
    if (days == 60)  return '2 Months';
    if (days == 90)  return '3 Months';
    if (days == 180) return '6 Months';
    if (days == 365) return '1 Year';
    return '$days days';
  }

  void _showManagerSubscriptionDialog() {
    final managerId = _salon?['managerId'] as String?;
    if (managerId == null) {
      AppSnackbar.error(context, 'No manager assigned to this salon.');
      return;
    }

    final sub     = _salon?['managerSubscription'] as Map<String, dynamic>? ?? {};
    String selPlan = sub['plan'] as String? ?? 'free';
    int? selDays   = selPlan == 'free' ? null : 30;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final expiry = selDays != null
              ? DateFormat('d MMM yyyy').format(DateTime.now().add(Duration(days: selDays!)))
              : null;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Manager Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
            contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text('Plan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  ),
                  ..._professionalPlans.map((p) {
                    final meta = _planMeta(p['value']!);
                    final c = meta['color'] as Color;
                    return RadioListTile<String>(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(p['label']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(p['price']!, style: TextStyle(fontSize: 11, color: c)),
                      value: p['value']!,
                      groupValue: selPlan,
                      activeColor: _p,
                      onChanged: (v) => setS(() {
                        selPlan = v!;
                        selDays = v == 'free' ? null : 30;
                      }),
                    );
                  }),
                  if (selPlan != 'free') ...[
                    const Divider(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Text('Duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Wrap(spacing: 8, runSpacing: 6, children: _durations.map((d) => ChoiceChip(
                        label: Text(_durationLabel(d), style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: selDays == d ? Colors.white : Colors.black87,
                        )),
                        selected: selDays == d,
                        selectedColor: _p,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: selDays == d ? _p : Colors.grey.shade300),
                        onSelected: (_) => setS(() => selDays = d),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      )).toList()),
                    ),
                    if (expiry != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Text('Expires: $expiry',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ),
                  ],
                  const SizedBox(height: 8),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _p, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () { Navigator.pop(ctx); _grantManagerSubscription(managerId, selPlan, selDays); },
                child: const Text('Grant'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _grantManagerSubscription(String managerId, String plan, int? durationDays) async {
    try {
      await ApiService.adminSetSubscription(managerId, plan, durationDays: durationDays);
      if (mounted) {
        AppSnackbar.success(context, 'Subscription updated to ${plan.replaceAll('_', ' ')}.');
        _fetchSalon();
      }
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _cancelManagerSubscription() async {
    final managerId = _salon?['managerId'] as String?;
    if (managerId == null) return;
    final sub  = _salon?['managerSubscription'] as Map<String, dynamic>? ?? {};
    final plan = sub['plan'] as String? ?? 'free';
    final meta = _planMeta(plan);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Cancel the ${meta['label']} plan for "${_salon?['managerName'] ?? 'this manager'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Plan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.adminCancelSubscription(managerId);
      if (mounted) { AppSnackbar.success(context, 'Subscription cancelled.'); _fetchSalon(); }
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _deleteSalon() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Salon', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Permanently delete "${_salon?['name'] ?? widget.initialName}"? All associated data will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.adminDeleteSalon(widget.salonId);
      if (mounted) { AppSnackbar.success(context, 'Salon deleted.'); Navigator.pop(context, true); }
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final salon     = _salon;
    final name      = salon?['name']               as String? ?? widget.initialName;
    final status    = salon?['status']             as String? ?? widget.initialStatus;
    final isBanned  = salon?['isCurrentlyBanned']  as bool?   ?? (salon?['isBanned'] as bool? ?? false);

    final gradientEnd = status == 'approved'
        ? Colors.teal.shade400
        : status == 'pending'
            ? Colors.orange.shade400
            : Colors.red.shade400;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: () async { await _fetchSalon(); await _fetchBookings(reset: true); },
        color: _p,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 160,
              backgroundColor: _p,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_p, gradientEnd],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(Icons.store, size: 32, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              _chip(status.toUpperCase(),
                                  Colors.white.withValues(alpha: 0.3), Colors.white),
                              if (salon?['city'] != null) ...[
                                const SizedBox(width: 6),
                                _chip(salon!['city'] as String,
                                    Colors.white.withValues(alpha: 0.15), Colors.white70),
                              ],
                            ]),
                          ],
                        )),
                      ]),
                    ),
                  ),
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'approve') _approveSalon();
                    if (v == 'reject')  _rejectSalon();
                    if (v == 'ban')     _showBanSalonDialog();
                    if (v == 'unban')   _revokeSalonBan();
                    if (v == 'delete')  _deleteSalon();
                  },
                  itemBuilder: (_) => [
                    if (status != 'approved')
                      PopupMenuItem(
                        value: 'approve',
                        child: Row(children: [
                          Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 18),
                          const SizedBox(width: 8),
                          Text('Approve Salon', style: TextStyle(color: Colors.green.shade700)),
                        ]),
                      ),
                    if (status != 'rejected')
                      PopupMenuItem(
                        value: 'reject',
                        child: Row(children: [
                          Icon(Icons.cancel_outlined, color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text('Reject Salon', style: TextStyle(color: Colors.orange.shade700)),
                        ]),
                      ),
                    if (!isBanned)
                      PopupMenuItem(
                        value: 'ban',
                        child: Row(children: [
                          Icon(Icons.block, color: Colors.red.shade600, size: 18),
                          const SizedBox(width: 8),
                          Text('Ban Salon', style: TextStyle(color: Colors.red.shade600)),
                        ]),
                      ),
                    if (isBanned)
                      PopupMenuItem(
                        value: 'unban',
                        child: Row(children: [
                          Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 18),
                          const SizedBox(width: 8),
                          Text('Revoke Ban', style: TextStyle(color: Colors.green.shade600)),
                        ]),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: Colors.red.shade500, size: 18),
                        const SizedBox(width: 8),
                        const Text('Delete Salon', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),

            if (_loadingSalon)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _p)),
              )
            else ...[
              if (isBanned)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(child: _banStatusSection(salon)),
                ),
              if ((salon?['complaintCount'] as int? ?? 0) > 0)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, isBanned ? 8 : 16, 16, 0),
                  sliver: SliverToBoxAdapter(child: _complaintSummarySection(salon)),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, isBanned || (salon?['complaintCount'] as int? ?? 0) > 0 ? 8 : 16, 16, 0),
                sliver: SliverToBoxAdapter(child: _statsSection(salon)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: _salonInfoSection(salon)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: _managerSection(salon)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: _flagsSection(salon)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(child: _bookingFilters()),
              ),

              if (_loadingBookings)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: _p)),
                  ),
                )
              else if (_bookings.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No bookings found',
                        style: TextStyle(color: Colors.grey.shade500))),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        if (i == _bookings.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: CircularProgressIndicator(color: _p, strokeWidth: 2)),
                          );
                        }
                        return _bookingCard(_bookings[i] as Map<String, dynamic>);
                      },
                      childCount: _bookings.length + (_loadingMoreBookings ? 1 : 0),
                    ),
                  ),
                ),
                if (_bookings.length < _bookingsTotal)
                  SliverToBoxAdapter(
                    child: Center(
                      child: TextButton(
                        onPressed: _loadMoreBookings,
                        child: Text(
                            'Load more (${_bookingsTotal - _bookings.length} remaining)',
                            style: const TextStyle(color: _p)),
                      ),
                    ),
                  ),
              ],

              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────────

  Widget _banStatusSection(Map<String, dynamic>? salon) {
    final bannedUntil = salon?['bannedUntil'] as String?;
    final banReason   = salon?['banReason']   as String? ?? 'No reason provided';
    final isPermanent = bannedUntil == null;
    final until = isPermanent
        ? 'Permanent ban'
        : () {
            final dt = DateTime.tryParse(bannedUntil)?.toLocal();
            if (dt == null) return 'Unknown expiry';
            final diff = dt.difference(DateTime.now());
            if (diff.inDays >= 1) return 'Until ${dt.day} ${_monthName(dt.month)} ${dt.year}';
            if (diff.inHours >= 1) return 'Expires in ${diff.inHours}h ${diff.inMinutes % 60}m';
            return 'Expires soon';
          }();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.block, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 8),
          Text('Salon Suspended', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPermanent ? Colors.red.shade600 : Colors.orange.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(isPermanent ? 'PERMANENT' : 'TIMED',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(until, style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Reason: $banReason', style: TextStyle(fontSize: 12, color: Colors.red.shade600)),
      ]),
    );
  }

  Widget _complaintSummarySection(Map<String, dynamic>? salon) {
    final total = salon?['complaintCount']      as int? ?? 0;
    final major = salon?['majorComplaintCount'] as int? ?? 0;
    final color = major >= 3 ? Colors.red.shade600 : major >= 1 ? Colors.orange.shade700 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(
          '$total complaint${total == 1 ? '' : 's'}  ·  $major major unresolved',
          style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
        )),
        if (major >= 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(6)),
            child: const Text('AUTO-BAN THRESHOLD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
      ]),
    );
  }

  String _monthName(int m) => const ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m];

  Widget _statsSection(Map<String, dynamic>? salon) {
    final bStats         = salon?['bookingStats'] as Map<String, dynamic>? ?? {};
    final totalBookings  = int.tryParse(bStats['totalBookings']?.toString()  ?? '0') ?? 0;
    final completedCount = int.tryParse(bStats['completedCount']?.toString() ?? '0') ?? 0;
    final cancelledCount = int.tryParse(bStats['cancelledCount']?.toString() ?? '0') ?? 0;
    final activeCount    = int.tryParse(bStats['activeCount']?.toString()    ?? '0') ?? 0;
    final totalRevenue   = (bStats['totalRevenue'] as num?)?.toDouble() ?? 0;
    final baariFee       = (bStats['baariFee']     as num?)?.toDouble() ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Financial Overview'),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _statCard('Total Bookings', '$totalBookings',
            Icons.calendar_today_outlined, Colors.blue.shade700)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Completed', '$completedCount',
            Icons.check_circle_outline, Colors.green.shade600)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Cancelled', '$cancelledCount',
            Icons.cancel_outlined, Colors.red.shade400)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _statCard('Active', '$activeCount',
            Icons.pending_outlined, Colors.orange.shade600)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Revenue', '₹${_fmt(totalRevenue)}',
            Icons.currency_rupee, Colors.indigo.shade600)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Baari Fee', '₹${_fmt(baariFee)}',
            Icons.account_balance_wallet_outlined, Colors.teal.shade600)),
      ]),
    ]);
  }

  Widget _salonInfoSection(Map<String, dynamic>? salon) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _sectionHeader('Salon Details'),
          const Spacer(),
          Text('Tap  to edit', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
        const SizedBox(height: 12),
        _editRow(Icons.store_outlined, 'Name',
            salon?['name'] as String? ?? '—',
            onTap: () => _showEditDialog('Name', 'name', salon?['name'] as String? ?? '')),
        _editRow(Icons.location_on_outlined, 'Address',
            salon?['address'] as String? ?? '—',
            onTap: () => _showEditDialog('Address', 'address',
                salon?['address'] as String? ?? '')),
        _editRow(Icons.location_city_outlined, 'City',
            salon?['city'] as String? ?? '—',
            onTap: () => _showEditDialog('City', 'city', salon?['city'] as String? ?? '')),
        _editRow(Icons.map_outlined, 'State',
            salon?['state'] as String? ?? '—',
            onTap: () => _showEditDialog('State', 'state',
                salon?['state'] as String? ?? '')),
        _editRow(Icons.pin_drop_outlined, 'Pincode',
            salon?['pincode'] as String? ?? '—',
            onTap: () => _showEditDialog('Pincode', 'pincode',
                salon?['pincode'] as String? ?? '', keyboard: TextInputType.number)),
        _editRow(Icons.phone, 'Contact',
            salon?['contactNumber'] as String? ?? '—',
            onTap: () => _showEditDialog('Contact Number', 'contactNumber',
                salon?['contactNumber'] as String? ?? '', keyboard: TextInputType.phone)),
        _editRow(Icons.access_time, 'Opening',
            salon?['openingTime'] as String? ?? '—',
            onTap: () => _showEditDialog('Opening Time', 'openingTime',
                salon?['openingTime'] as String? ?? '')),
        _editRow(Icons.access_time_filled, 'Closing',
            salon?['closingTime'] as String? ?? '—',
            onTap: () => _showEditDialog('Closing Time', 'closingTime',
                salon?['closingTime'] as String? ?? '')),
        _editRow(Icons.calendar_view_week, 'Working Days',
            salon?['workingDays'] as String? ?? '—',
            onTap: () => _showEditDialog('Working Days', 'workingDays',
                salon?['workingDays'] as String? ?? '')),
        _infoRow(Icons.star_outline, 'Rating',
            '${salon?['rating'] ?? 0} (${salon?['reviewCount'] ?? 0} reviews)'),
        _infoRow(Icons.calendar_today_outlined, 'Created',
            _fmtDate(salon?['createdAt'] ?? salon?['created_at'])),
      ]),
    );
  }

  Map<String, dynamic> _planMeta(String plan) {
    switch (plan) {
      case 'professional_starter': return {'label': 'Starter', 'price': '₹299/mo', 'color': Colors.teal.shade600};
      case 'professional_growth':  return {'label': 'Growth',  'price': '₹599/mo', 'color': Colors.orange.shade600};
      case 'professional_premium': return {'label': 'Premium', 'price': '₹999/mo', 'color': Colors.amber.shade700};
      default:                     return {'label': 'Free',    'price': 'Free',     'color': Colors.grey.shade500};
    }
  }

  Widget _managerSection(Map<String, dynamic>? salon) {
    final sub    = salon?['managerSubscription'] as Map<String, dynamic>? ?? {};
    final plan   = sub['plan']   as String? ?? 'free';
    final status = sub['status'] as String? ?? 'active';
    final expires = sub['expiresAt'];

    final isCancelled = status == 'cancelled';
    final isExpired   = expires != null &&
        (DateTime.tryParse(expires.toString())?.isBefore(DateTime.now()) ?? false);
    final effectiveStatus = isCancelled ? 'cancelled' : isExpired ? 'expired' : 'active';

    final meta  = _planMeta(plan);
    final label = meta['label'] as String;
    final price = meta['price'] as String;
    final color = meta['color'] as Color;

    final statusColor = effectiveStatus == 'active'
        ? Colors.green.shade600
        : effectiveStatus == 'expired'
            ? Colors.orange.shade600
            : Colors.red.shade500;

    return _card(
      borderColor: Colors.blue.shade100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_outline, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          _sectionHeader('Manager'),
        ]),
        const SizedBox(height: 12),
        _infoRow(Icons.person_outline, 'Name',
            salon?['managerName'] as String? ?? '—'),
        _infoRow(Icons.phone, 'Phone',
            salon?['managerPhone'] as String? ?? '—'),
        _infoRow(Icons.email_outlined, 'Email',
            salon?['managerEmail'] as String? ?? '—'),
        const Divider(height: 20),
        Row(children: [
          Icon(Icons.card_membership_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Text('Plan: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              plan == 'free' ? label : '$label  ·  $price',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(effectiveStatus.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
          ),
          const Spacer(),
          InkWell(
            onTap: _showManagerSubscriptionDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade400),
            ),
          ),
        ]),
        if (expires != null && plan != 'free') ...[
          const SizedBox(height: 6),
          _infoRow(Icons.event_outlined, 'Expires', _fmtDate(expires),
              valueColor: isExpired ? Colors.red.shade500 : null),
        ],
        if (plan != 'free' && effectiveStatus == 'active') ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _cancelManagerSubscription,
              icon: Icon(Icons.cancel_outlined, size: 14, color: Colors.red.shade400),
              label: Text('Cancel Plan', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _flagsSection(Map<String, dynamic>? salon) {
    final isOpen          = salon?['isOpen']          as bool? ?? false;
    final priorityListing = salon?['priorityListing'] as bool? ?? false;
    final featured        = salon?['featured']        as bool? ?? false;

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('Settings'),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Open Now', style: TextStyle(fontSize: 14)),
          subtitle: Text(isOpen ? 'Accepting bookings' : 'Not accepting bookings',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          value: isOpen,
          activeColor: Colors.green.shade600,
          onChanged: (v) => _saveSalonField('isOpen', v, 'Open status'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Priority Listing', style: TextStyle(fontSize: 14)),
          subtitle: Text('Appears higher in search results',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          value: priorityListing,
          activeColor: Colors.orange.shade600,
          onChanged: (v) => _saveSalonField('priorityListing', v, 'Priority listing'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Featured', style: TextStyle(fontSize: 14)),
          subtitle: Text('Shown in featured section on home screen',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          value: featured,
          activeColor: Colors.purple.shade600,
          onChanged: (v) => _saveSalonField('featured', v, 'Featured'),
        ),
      ]),
    );
  }

  Widget _bookingFilters() {
    final statusOptions = {
      '': 'All', 'completed': 'Completed', 'confirmed': 'Confirmed',
      'pending': 'Pending', 'cancelled': 'Cancelled',
    };
    final dateOptions = {
      '': 'All Dates', 'today': 'Today', 'week': 'Week',
      'month': 'Month', 'year': 'Year',
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _sectionHeader('Bookings'),
        const SizedBox(width: 8),
        Text('($_bookingsTotal total)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: statusOptions.entries.map((e) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(e.value, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: _bookingStatus == e.key ? Colors.white : Colors.black87)),
            selected: _bookingStatus == e.key,
            onSelected: (_) {
              setState(() => _bookingStatus = e.key);
              _fetchBookings(reset: true);
            },
            selectedColor: _p,
            backgroundColor: Colors.white,
            side: BorderSide(color: _bookingStatus == e.key ? _p : Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ),
        )).toList()),
      ),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ...dateOptions.entries.map((e) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _bookingDateFilter == e.key ? Colors.white : Colors.black87)),
              selected: _bookingDateFilter == e.key,
              onSelected: (_) {
                setState(() => _bookingDateFilter = e.key);
                _fetchBookings(reset: true);
              },
              selectedColor: _p,
              backgroundColor: Colors.white,
              side: BorderSide(
                  color: _bookingDateFilter == e.key ? _p : Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
          )),
          GestureDetector(
            onTap: _pickCustomRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _bookingDateFilter == 'custom' ? _p : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _bookingDateFilter == 'custom' ? _p : Colors.grey.shade300),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range, size: 11,
                    color: _bookingDateFilter == 'custom' ? Colors.white : Colors.black87),
                const SizedBox(width: 4),
                Text(
                  _bookingDateFilter == 'custom' && _customFrom != null
                      ? '${DateFormat('d MMM').format(_customFrom!)} – ${DateFormat('d MMM').format(_customTo ?? _customFrom!)}'
                      : 'Custom',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: _bookingDateFilter == 'custom' ? Colors.white : Colors.black87),
                ),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final status        = b['status'] as String? ?? '';
    final totalAmt      = (b['totalAmount']    as num?)?.toDouble() ?? 0;
    final convenience   = (b['convenienceFee'] as num?)?.toDouble() ?? 0;
    final services      = b['services'] as List<dynamic>? ?? [];
    final customerName  = b['customerName']  as String?;
    final customerPhone = b['customerPhone'] as String?;
    final customer      = (customerName?.isNotEmpty == true) ? customerName! : customerPhone ?? '—';
    final reason        = b['cancellationReason'] as String?;

    final statusColors = <String, Color>{
      'completed':   Colors.green.shade600,
      'confirmed':   Colors.blue.shade600,
      'pending':     Colors.orange.shade600,
      'cancelled':   Colors.grey.shade500,
      'rejected':    Colors.red.shade400,
      'in_progress': Colors.purple.shade600,
    };
    final c = statusColors[status] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(customer,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis)),
          _statusChip(status, c),
        ]),
        const SizedBox(height: 4),
        Text(_fmtDateTime(b['scheduledAt']),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        if (services.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: services.take(3).map((s) {
            final sName = (s is Map) ? (s['serviceName'] as String? ?? '') : s.toString();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text(sName,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
            );
          }).toList()),
        ],
        if (reason != null && reason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Reason: $reason',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.shade400,
                    fontStyle: FontStyle.italic)),
          ),
        const Divider(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text('₹${totalAmt.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('Duration', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text('${b['totalDuration'] ?? 0} min',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Baari Fee', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text('₹${convenience.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade600)),
          ])),
        ]),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _card({required Widget child, Color? borderColor}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: borderColor != null ? Border.all(color: borderColor) : null,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
    ),
    child: child,
  );

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87));

  Widget _statCard(String label, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
    ]),
  );

  Widget _editRow(IconData icon, String label, String value,
      {required VoidCallback onTap}) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          SizedBox(width: 100,
              child: Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
          Expanded(child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade300),
        ]),
      ),
    );

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        SizedBox(width: 100,
            child: Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
        Expanded(child: Text(value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.black87))),
      ]),
    );

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
  );

  Widget _statusChip(String status, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
  );

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('d MMM yyyy').format(dt) : '—';
  }

  String _fmtDateTime(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString())?.toLocal();
    return dt != null ? DateFormat('d MMM yy, h:mm a').format(dt) : '—';
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
