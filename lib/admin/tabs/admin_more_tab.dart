import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/admin/pages/admin_sub_admins_page.dart';
import 'package:no_wait_app/role_selection_screen.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _p = Color(0xFF1565C0);

class AdminMoreTab extends StatefulWidget {
  final String adminName;
  final bool isSuperAdmin;
  const AdminMoreTab({
    super.key,
    required this.adminName,
    this.isSuperAdmin = true,
  });

  @override
  State<AdminMoreTab> createState() => _AdminMoreTabState();
}

class _AdminMoreTabState extends State<AdminMoreTab> {
  List<dynamic> _offers   = [];
  int  _offersTotal       = 0;
  bool _loadingOffers     = true;

  List<dynamic> _coupons  = [];
  int  _couponsTotal      = 0;
  bool _loadingCoupons    = true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
    _loadCoupons();
  }

  // ── Offers ──────────────────────────────────────────────────────────────────

  Future<void> _loadOffers() async {
    setState(() => _loadingOffers = true);
    try {
      final res = await ApiService.adminGetOffers(limit: 50);
      if (mounted) {
        setState(() {
          _offers      = res['offers'] as List<dynamic>? ?? [];
          _offersTotal = (res['total'] as num?)?.toInt() ?? 0;
          _loadingOffers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOffers = false);
    }
  }

  void _showCreateOffer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateOfferSheet(onCreated: () {
        Navigator.pop(context);
        _loadOffers();
      }),
    );
  }

  void _showEditOffer(Map<String, dynamic> offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditOfferSheet(offer: offer, onUpdated: () {
        Navigator.pop(context);
        _loadOffers();
      }),
    );
  }

  void _showAssignUsers(Map<String, dynamic> coupon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AssignUsersSheet(coupon: coupon),
    );
  }

  Future<void> _deleteOffer(Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Offer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Delete "${offer['title']}"?'),
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
    if (confirmed != true || !mounted) { return; }
    try {
      await ApiService.adminDeleteOffer(offer['id'] as String);
      if (mounted) AppSnackbar.success(context, 'Offer deleted.');
      _loadOffers();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  // ── Coupons ──────────────────────────────────────────────────────────────────

  Future<void> _loadCoupons() async {
    setState(() => _loadingCoupons = true);
    try {
      final res = await ApiService.adminGetCoupons(limit: 50);
      if (mounted) {
        setState(() {
          _coupons      = res['coupons'] as List<dynamic>? ?? [];
          _couponsTotal = (res['total'] as num?)?.toInt() ?? 0;
          _loadingCoupons = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCoupons = false);
    }
  }

  Future<void> _toggleCoupon(Map<String, dynamic> coupon) async {
    try {
      await ApiService.adminToggleCoupon(coupon['id'] as String);
      _loadCoupons();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _deleteCoupon(Map<String, dynamic> coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Coupon', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Delete coupon "${coupon['code']}"?'),
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
    if (confirmed != true || !mounted) { return; }
    try {
      await ApiService.adminDeleteCoupon(coupon['id'] as String);
      if (mounted) AppSnackbar.success(context, 'Coupon deleted.');
      _loadCoupons();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  void _showCreateCoupon() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateCouponSheet(onCreated: () {
        Navigator.pop(context);
        _loadCoupons();
      }),
    );
  }

  // ── Logout ───────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Sign out of the admin panel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _p, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) { return; }
    await ApiService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_permissions');
    if (!mounted) { return; }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _p,
        title: const Text('More',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async { await _loadOffers(); await _loadCoupons(); },
        color: _p,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Admin info card ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_p, Colors.blue.shade400]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    widget.adminName.isNotEmpty
                        ? widget.adminName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.adminName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Text('Baari Administrator',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                      widget.isSuperAdmin ? 'SUPER ADMIN' : 'SUB ADMIN',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Coupons section ────────────────────────────────────────────
            Row(children: [
              Container(width: 4, height: 18,
                  decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              Text('Coupons ($_couponsTotal)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: _p, size: 22),
                onPressed: _showCreateCoupon,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Create Coupon',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: _p, size: 20),
                onPressed: _loadCoupons,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: 8),

            if (_loadingCoupons)
              const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _p, strokeWidth: 2)))
            else if (_coupons.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.discount_outlined, size: 36, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No coupons yet. Tap + to create one.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ]),
              ))
            else
              ...(_coupons.map((c) => _couponCard(c as Map<String, dynamic>))),

            const SizedBox(height: 20),

            // ── Offers section ─────────────────────────────────────────────
            Row(children: [
              Container(width: 4, height: 18,
                  decoration: BoxDecoration(
                      color: _p, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              Text('Salon Offers ($_offersTotal)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: _p, size: 22),
                onPressed: _showCreateOffer,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Create Offer',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: _p, size: 20),
                onPressed: _loadOffers,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: 8),

            if (_loadingOffers)
              const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _p, strokeWidth: 2)))
            else if (_offers.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No offers found',
                    style: TextStyle(color: Colors.grey.shade500)),
              ))
            else
              ...(_offers.map((o) => _offerCard(o as Map<String, dynamic>))),

            const SizedBox(height: 24),

            // ── Management tiles ───────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
                ],
              ),
              child: Column(children: [
                if (widget.isSuperAdmin) ...[
                  _tile(
                    icon: Icons.manage_accounts_outlined,
                    iconColor: Colors.deepPurple.shade400,
                    title: 'Sub-Admins',
                    subtitle: 'Manage roles & permissions',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminSubAdminsPage()),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                  const Divider(height: 1, indent: 56),
                ],
                _tile(
                  icon: Icons.logout,
                  iconColor: Colors.red.shade400,
                  title: 'Sign Out',
                  subtitle: 'End admin session',
                  onTap: _logout,
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ]),
            ),
            const SizedBox(height: 32),

            Center(child: Text('Baari Admin Panel  ·  Internal Use Only',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _couponCard(Map<String, dynamic> c) {
    final isActive   = c['isActive'] as bool? ?? true;
    final disc       = (c['discountPercent'] as num?)?.toInt() ?? 0;
    final target     = c['targetType'] as String? ?? 'all';
    final validUntil = c['validUntil'] != null
        ? DateTime.tryParse(c['validUntil'] as String) : null;
    final expired    = validUntil != null && validUntil.isBefore(DateTime.now());
    final usedCount  = (c['usedCount'] as num?)?.toInt() ?? 0;
    final maxUses    = c['maxUses'] != null ? (c['maxUses'] as num).toInt() : null;

    final targetLabel = target == 'customer'
        ? 'Customers only'
        : target == 'professional'
            ? 'Professionals only'
            : 'All users';
    final targetColor = target == 'customer'
        ? Colors.blue
        : target == 'professional'
            ? Colors.teal
            : Colors.indigo;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isActive && !expired ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: _p.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _p.withValues(alpha: 0.2)),
          ),
          child: Text(c['code'] as String? ?? '',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: _p, letterSpacing: 1)),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['title'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis),
          Row(children: [
            if (disc > 0)
              _tag('$disc% off', Colors.green),
            const SizedBox(width: 4),
            _tag(targetLabel, targetColor),
          ]),
          if (validUntil != null)
            Text(
              expired
                  ? 'Expired ${DateFormat('d MMM yy').format(validUntil)}'
                  : 'Until ${DateFormat('d MMM yy').format(validUntil)}',
              style: TextStyle(
                  fontSize: 10,
                  color: expired ? Colors.red.shade400 : Colors.grey.shade400),
            ),
          if (maxUses != null)
            Text('$usedCount / $maxUses uses',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ])),
        Column(children: [
          Switch(
            value: isActive,
            onChanged: (_) => _toggleCoupon(c),
            activeThumbColor: _p,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              onPressed: () => _showAssignUsers(c),
              icon: Icon(Icons.person_add_outlined, color: _p, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Assign Users',
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => _deleteCoupon(c),
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Delete',
            ),
          ]),
        ]),
      ]),
    );
  }

  Widget _tag(String label, MaterialColor color) => Container(
    margin: const EdgeInsets.only(right: 4, bottom: 2),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(label,
        style: TextStyle(fontSize: 10, color: color.shade700, fontWeight: FontWeight.w600)),
  );

  Widget _offerCard(Map<String, dynamic> offer) {
    final isActive   = offer['isActive'] as bool? ?? true;
    final disc       = (offer['discountPercent'] as num?)?.toInt() ?? 0;
    final validUntil = offer['validUntil'] != null
        ? DateTime.tryParse(offer['validUntil'] as String) : null;
    final expired    = validUntil != null && validUntil.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)
        ],
      ),
      child: Row(children: [
        if (disc > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: _p.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$disc%',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _p)),
          ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(offer['title'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis),
          Text(offer['salonName'] as String? ?? '',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          if (validUntil != null)
            Text(
              expired
                  ? 'Expired'
                  : 'Until ${DateFormat('d MMM yy').format(validUntil)}',
              style: TextStyle(
                  fontSize: 11,
                  color: expired ? Colors.red.shade400 : Colors.grey.shade400),
            ),
        ])),
        if (!isActive)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6)),
            child: Text('Paused',
                style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
          ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            onPressed: () => _showEditOffer(offer),
            icon: Icon(Icons.edit_outlined, color: Colors.blue.shade400, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: () => _deleteOffer(offer),
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Delete',
          ),
        ]),
      ]),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// ── Create coupon sheet ────────────────────────────────────────────────────────

class _CreateCouponSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateCouponSheet({required this.onCreated});

  @override
  State<_CreateCouponSheet> createState() => _CreateCouponSheetState();
}

class _CreateCouponSheetState extends State<_CreateCouponSheet> {
  final _codeCtrl  = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _pctCtrl   = TextEditingController(text: '10');
  final _maxCtrl   = TextEditingController();

  String _targetType = 'all';
  DateTime? _validUntil;
  bool _loading   = false;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_codeCtrl, _titleCtrl, _descCtrl, _pctCtrl, _maxCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _p)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final code  = _codeCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    final pct   = int.tryParse(_pctCtrl.text.trim()) ?? -1;
    if (code.isEmpty || title.isEmpty || pct < 0 || pct > 100) return;

    setState(() => _loading = true);
    try {
      await ApiService.adminCreateCoupon({
        'code':            code.toUpperCase(),
        'title':           title,
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'discountPercent': pct,
        'targetType':      _targetType,
        if (_validUntil != null) 'validUntil': _validUntil!.toIso8601String(),
        if (_maxCtrl.text.trim().isNotEmpty)
          'maxUses': int.tryParse(_maxCtrl.text.trim()),
      });
      widget.onCreated();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false, initialChildSize: 0.75, maxChildSize: 0.92,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                const Text('Create Coupon',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Expanded(child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
              _f('Coupon Code *', _codeCtrl,
                  hint: 'e.g. SAVE20',
                  onChanged: (v) => _codeCtrl.value = _codeCtrl.value.copyWith(
                    text: v.toUpperCase(),
                    selection: TextSelection.collapsed(offset: v.length),
                  )),
              _f('Title *', _titleCtrl, hint: 'e.g. 20% off for new users'),
              _f('Description', _descCtrl, hint: 'Optional details'),
              _f('Discount %  (0–100) *', _pctCtrl,
                  hint: '10', keyboard: TextInputType.number),

              // Target type
              const Text('Applies To',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                for (final e in {
                  'all': 'All Users',
                  'customer': 'Customers',
                  'professional': 'Professionals',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _targetType == e.key
                                  ? Colors.white : Colors.black87)),
                      selected: _targetType == e.key,
                      onSelected: (_) => setState(() => _targetType = e.key),
                      selectedColor: _p,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: _targetType == e.key
                              ? _p : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),

              // Valid until
              const Text('Valid Until (optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickValidUntil,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      _validUntil != null
                          ? DateFormat('d MMM yyyy').format(_validUntil!)
                          : 'No expiry',
                      style: TextStyle(
                          fontSize: 13,
                          color: _validUntil != null
                              ? Colors.black87 : Colors.grey.shade400),
                    ),
                    const Spacer(),
                    if (_validUntil != null)
                      GestureDetector(
                        onTap: () => setState(() => _validUntil = null),
                        child: Icon(Icons.clear,
                            size: 16, color: Colors.grey.shade400),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              _f('Max Uses (optional)', _maxCtrl,
                  hint: 'Leave blank for unlimited',
                  keyboard: TextInputType.number),

              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _p, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Create Coupon',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _f(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard,
       void Function(String)? onChanged}) {
    final required = label.endsWith('*');
    final empty    = _submitted && required && ctrl.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          onChanged: onChanged ?? (_) { if (_submitted) setState(() {}); },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: empty ? Colors.red.shade400 : Colors.grey.shade300)),
            errorText: empty ? 'Required' : null,
          ),
        ),
      ]),
    );
  }
}

// ── Create offer sheet ────────────────────────────────────────────────────────

class _CreateOfferSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateOfferSheet({required this.onCreated});

  @override
  State<_CreateOfferSheet> createState() => _CreateOfferSheetState();
}

class _CreateOfferSheetState extends State<_CreateOfferSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _pctCtrl   = TextEditingController(text: '10');
  final _searchCtrl = TextEditingController();

  List<dynamic> _salons     = [];
  Map<String, dynamic>? _selectedSalon;
  bool _searchingS  = false;
  DateTime? _validUntil;
  bool _loading     = false;
  bool _submitted   = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pctCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchSalons(String q) async {
    if (q.trim().length < 2) { setState(() => _salons = []); return; }
    setState(() => _searchingS = true);
    try {
      final res = await ApiService.adminGetSalons(search: q, limit: 8);
      if (mounted) {
        setState(() {
          _salons    = (res['salons'] as List<dynamic>?) ?? [];
          _searchingS = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searchingS = false);
    }
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _p)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final title = _titleCtrl.text.trim();
    final pct   = int.tryParse(_pctCtrl.text.trim()) ?? -1;
    if (title.isEmpty || pct < 0 || pct > 100 || _selectedSalon == null) return;

    setState(() => _loading = true);
    try {
      await ApiService.adminCreateOffer({
        'salonId':         _selectedSalon!['id'] as String,
        'title':           title,
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'discountPercent': pct,
        if (_validUntil != null) 'validUntil': _validUntil!.toIso8601String(),
      });
      widget.onCreated();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false, initialChildSize: 0.8, maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                const Text('Create Offer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Expanded(child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
              // Salon search
              const Text('Salon *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if (_selectedSalon != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: _p),
                    borderRadius: BorderRadius.circular(10),
                    color: _p.withValues(alpha: 0.05),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(
                      _selectedSalon!['name'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    )),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedSalon = null;
                        _salons = [];
                        _searchCtrl.clear();
                      }),
                      child: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
                    ),
                  ]),
                )
              else ...[
                TextField(
                  controller: _searchCtrl,
                  onChanged: _searchSalons,
                  decoration: InputDecoration(
                    hintText: 'Search salon by name…',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: _submitted && _selectedSalon == null
                                ? Colors.red.shade400
                                : Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: _submitted && _selectedSalon == null
                                ? Colors.red.shade400
                                : Colors.grey.shade300)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    suffixIcon: _searchingS
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _p),
                            ))
                        : null,
                  ),
                ),
                if (_submitted && _selectedSalon == null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.error_outline, size: 12, color: Colors.red.shade600),
                    const SizedBox(width: 4),
                    Text('Select a salon', style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
                  ]),
                ],
                if (_salons.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: _salons.map((s) {
                        final salon = s as Map<String, dynamic>;
                        return ListTile(
                          dense: true,
                          title: Text(salon['name'] as String? ?? '',
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                              '${salon['city'] ?? ''}, ${salon['state'] ?? ''}',
                              style: const TextStyle(fontSize: 11)),
                          onTap: () => setState(() {
                            _selectedSalon = salon;
                            _salons = [];
                            _searchCtrl.clear();
                          }),
                        );
                      }).toList(),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              _fld('Title *', _titleCtrl, hint: 'e.g. Summer Special'),
              _fld('Description', _descCtrl, hint: 'Optional details'),
              _fld('Discount % (0–100) *', _pctCtrl,
                  hint: '10', keyboard: TextInputType.number),
              // Valid until
              const Text('Valid Until (optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickValidUntil,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      _validUntil != null
                          ? DateFormat('d MMM yyyy').format(_validUntil!)
                          : 'No expiry',
                      style: TextStyle(
                          fontSize: 13,
                          color: _validUntil != null
                              ? Colors.black87 : Colors.grey.shade400),
                    ),
                    const Spacer(),
                    if (_validUntil != null)
                      GestureDetector(
                        onTap: () => setState(() => _validUntil = null),
                        child: Icon(Icons.clear, size: 16, color: Colors.grey.shade400),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _p, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Create Offer',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _fld(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard}) {
    final required = label.endsWith('*');
    final empty    = _submitted && required && ctrl.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          onChanged: (_) { if (_submitted) setState(() {}); },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: empty ? Colors.red.shade400 : Colors.grey.shade300)),
            errorText: empty ? 'Required' : null,
          ),
        ),
      ]),
    );
  }
}

// ── Edit offer sheet ──────────────────────────────────────────────────────────

class _EditOfferSheet extends StatefulWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onUpdated;
  const _EditOfferSheet({required this.offer, required this.onUpdated});

  @override
  State<_EditOfferSheet> createState() => _EditOfferSheetState();
}

class _EditOfferSheetState extends State<_EditOfferSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _pctCtrl;
  late bool _isActive;
  DateTime? _validUntil;
  bool _loading   = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
        text: widget.offer['title'] as String? ?? '');
    _descCtrl = TextEditingController(
        text: widget.offer['description'] as String? ?? '');
    _pctCtrl = TextEditingController(
        text: '${(widget.offer['discountPercent'] as num?)?.toInt() ?? 0}');
    _isActive  = widget.offer['isActive'] as bool? ?? true;
    final v = widget.offer['validUntil'];
    if (v != null) _validUntil = DateTime.tryParse(v as String);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pctCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _p)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final title = _titleCtrl.text.trim();
    final pct   = int.tryParse(_pctCtrl.text.trim()) ?? -1;
    if (title.isEmpty || pct < 0 || pct > 100) return;

    setState(() => _loading = true);
    try {
      await ApiService.adminUpdateOffer(widget.offer['id'] as String, {
        'title':           title,
        'description':     _descCtrl.text.trim(),
        'discountPercent': pct,
        'isActive':        _isActive,
        'validUntil':      _validUntil?.toIso8601String(),
      });
      widget.onUpdated();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.92,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                const Text('Edit Offer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Expanded(child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
              _fld('Title *', _titleCtrl, hint: 'Offer title'),
              _fld('Description', _descCtrl, hint: 'Optional details'),
              _fld('Discount % (0–100) *', _pctCtrl,
                  hint: '10', keyboard: TextInputType.number),
              // Active toggle
              Row(children: [
                const Text('Active',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeThumbColor: _p,
                ),
              ]),
              const SizedBox(height: 8),
              // Valid until
              const Text('Valid Until (optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickValidUntil,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      _validUntil != null
                          ? DateFormat('d MMM yyyy').format(_validUntil!)
                          : 'No expiry',
                      style: TextStyle(
                          fontSize: 13,
                          color: _validUntil != null
                              ? Colors.black87 : Colors.grey.shade400),
                    ),
                    const Spacer(),
                    if (_validUntil != null)
                      GestureDetector(
                        onTap: () => setState(() => _validUntil = null),
                        child: Icon(Icons.clear, size: 16, color: Colors.grey.shade400),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _p, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Save Changes',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _fld(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard}) {
    final required = label.endsWith('*');
    final empty    = _submitted && required && ctrl.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          onChanged: (_) { if (_submitted) setState(() {}); },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: empty ? Colors.red.shade400 : Colors.grey.shade300)),
            errorText: empty ? 'Required' : null,
          ),
        ),
      ]),
    );
  }
}

// ── Assign users to coupon sheet ──────────────────────────────────────────────

class _AssignUsersSheet extends StatefulWidget {
  final Map<String, dynamic> coupon;
  const _AssignUsersSheet({required this.coupon});

  @override
  State<_AssignUsersSheet> createState() => _AssignUsersSheetState();
}

class _AssignUsersSheetState extends State<_AssignUsersSheet> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _assignees   = [];
  List<dynamic> _searchResults = [];
  bool _loadingAssignees = true;
  bool _searching        = false;

  @override
  void initState() {
    super.initState();
    _loadAssignees();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAssignees() async {
    setState(() => _loadingAssignees = true);
    try {
      final list = await ApiService.adminGetCouponAssignees(
          widget.coupon['id'] as String);
      if (mounted) setState(() { _assignees = list; _loadingAssignees = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAssignees = false);
    }
  }

  Future<void> _searchUsers(String q) async {
    if (q.trim().length < 2) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    try {
      final res = await ApiService.adminGetUsers(search: q, limit: 10);
      if (mounted) {
        setState(() {
          _searchResults = (res['users'] as List<dynamic>?) ?? [];
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _assign(Map<String, dynamic> user) async {
    try {
      await ApiService.adminAssignCoupon(
          widget.coupon['id'] as String, [user['id'] as String]);
      _searchCtrl.clear();
      setState(() => _searchResults = []);
      _loadAssignees();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _remove(Map<String, dynamic> assignee) async {
    try {
      await ApiService.adminRemoveCouponAssignee(
          widget.coupon['id'] as String, assignee['userId'] as String);
      _loadAssignees();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  bool _isAlreadyAssigned(String userId) =>
      _assignees.any((a) => (a as Map<String, dynamic>)['userId'] == userId);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false, initialChildSize: 0.75, maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: CustomScrollView(
            controller: ctrl,
            slivers: [
              // ── Handle + header + search ──────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Assign Users',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            Text('Coupon: ${widget.coupon['code'] ?? ''}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ]),
                        ),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _searchUsers,
                        decoration: InputDecoration(
                          hintText: 'Search users by name or phone…',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300)),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                          suffixIcon: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _p),
                                  ))
                              : null,
                        ),
                      ),
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _searchResults.map((u) {
                            final user    = u as Map<String, dynamic>;
                            final already = _isAlreadyAssigned(user['id'] as String);
                            return ListTile(
                              dense: true,
                              title: Text(user['fullName'] as String? ?? '',
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text(user['phone'] as String? ?? '',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: already
                                  ? Text('Assigned',
                                      style: TextStyle(fontSize: 11, color: Colors.green.shade600))
                                  : TextButton(
                                      onPressed: () => _assign(user),
                                      child: const Text('Assign',
                                          style: TextStyle(fontSize: 12, color: _p)),
                                    ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              // ── Assigned users list ───────────────────────────────
              if (_loadingAssignees)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: _p, strokeWidth: 2)),
                )
              else if (_assignees.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text('No users assigned yet.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  sliver: SliverToBoxAdapter(
                    child: Text('Assigned (${_assignees.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final assignee = _assignees[i] as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _p.withValues(alpha: 0.1),
                              child: Text(
                                ((assignee['fullName'] as String?) ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                    color: _p, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(assignee['fullName'] as String? ?? '',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(assignee['phone'] as String? ?? '',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ])),
                            IconButton(
                              onPressed: () => _remove(assignee),
                              icon: Icon(Icons.person_remove_outlined,
                                  size: 18, color: Colors.red.shade400),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Remove',
                            ),
                          ]),
                        );
                      },
                      childCount: _assignees.length,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
