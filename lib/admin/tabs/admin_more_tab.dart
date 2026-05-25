import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/admin/admin_login_screen.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';

const Color _p = Color(0xFF1565C0);

class AdminMoreTab extends StatefulWidget {
  final String adminName;
  const AdminMoreTab({super.key, required this.adminName});

  @override
  State<AdminMoreTab> createState() => _AdminMoreTabState();
}

class _AdminMoreTabState extends State<AdminMoreTab> {
  List<dynamic> _offers = [];
  int _offersTotal = 0;
  bool _loadingOffers = true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _loadingOffers = true);
    try {
      final res = await ApiService.adminGetOffers(limit: 50);
      if (mounted) {
        setState(() {
          _offers = res['offers'] as List<dynamic>? ?? [];
          _offersTotal = (res['total'] as num?)?.toInt() ?? 0;
          _loadingOffers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOffers = false);
    }
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
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
            style: ElevatedButton.styleFrom(backgroundColor: _p, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) { return; }
    await ApiService.logout();
    if (!mounted) { return; }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _p,
        title: const Text('More', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOffers,
        color: _p,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Admin info card ──────────────────────────────────────────
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
                    widget.adminName.isNotEmpty ? widget.adminName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.adminName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  child: const Text('ADMIN',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Offers section ───────────────────────────────────────────
            Row(children: [
              Container(width: 4, height: 18,
                  decoration: BoxDecoration(color: _p, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              Text('All Offers ($_offersTotal)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
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
                child: Text('No offers found', style: TextStyle(color: Colors.grey.shade500)),
              ))
            else
              ...(_offers.map((o) => _offerCard(o as Map<String, dynamic>))),

            const SizedBox(height: 24),

            // ── Danger zone ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
              ),
              child: Column(children: [
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

  Widget _offerCard(Map<String, dynamic> offer) {
    final isActive    = offer['isActive'] as bool? ?? true;
    final disc        = (offer['discountPercent'] as num?)?.toInt() ?? 0;
    final validUntil  = offer['validUntil'] != null
        ? DateTime.tryParse(offer['validUntil'] as String) : null;
    final expired = validUntil != null && validUntil.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
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
            child: Text('$disc%', style: TextStyle(
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
              expired ? 'Expired' : 'Until ${DateFormat('d MMM yy').format(validUntil)}',
              style: TextStyle(fontSize: 11,
                  color: expired ? Colors.red.shade400 : Colors.grey.shade400),
            ),
        ])),
        if (!isActive)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
            child: Text('Paused', style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
          ),
        IconButton(
          onPressed: () => _deleteOffer(offer),
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Delete',
        ),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
