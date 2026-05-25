import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';

const Color _p = Color(0xFF1565C0);

class AdminDashboardTab extends StatefulWidget {
  final String adminName;
  const AdminDashboardTab({super.key, required this.adminName});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<dynamic> _pendingSalons = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.adminGetStats();
      if (mounted) {
        setState(() {
          _stats = (res['stats'] as Map<String, dynamic>?) ?? {};
          _pendingSalons = (res['pendingSalons'] as List<dynamic>?) ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(String id) async {
    try {
      await ApiService.adminApproveSalon(id);
      if (mounted) AppSnackbar.success(context, 'Salon approved.');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _reject(String id) async {
    try {
      await ApiService.adminRejectSalon(id);
      if (mounted) AppSnackbar.success(context, 'Salon rejected.');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _p,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 110,
              backgroundColor: _p,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, ${widget.adminName.split(' ').first}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(DateFormat('EEEE, d MMM').format(DateTime.now()),
                        style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _load,
                ),
              ],
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _p)),
              )
            else ...[
              // ── Stats grid ──────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _statCard('Customers',    '${_stats['totalCustomers'] ?? 0}',    Icons.person_outline,         Colors.blue.shade700),
                    _statCard('Professionals', '${_stats['totalProfessionals'] ?? 0}', Icons.content_cut,           Colors.teal.shade600),
                    _statCard('Active Salons', '${_stats['approvedSalons'] ?? 0}',   Icons.store_outlined,          Colors.green.shade600),
                    _statCard('Pending',       '${_stats['pendingSalons'] ?? 0}',    Icons.hourglass_top_outlined,  Colors.orange.shade600),
                    _statCard("Today's Bkgs",  '${_stats['todayBookings'] ?? 0}',   Icons.calendar_today_outlined,  Colors.purple.shade600),
                    _statCard('Month Revenue', '₹${_fmt(_stats['monthRevenue'])}',   Icons.currency_rupee,           Colors.indigo.shade600),
                  ],
                ),
              ),

              // ── Total revenue banner ─────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_p, Colors.blue.shade400]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 32),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total Platform Revenue',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('₹${_fmt(_stats['totalRevenue'])}',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${_stats['completedBookings'] ?? 0}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('completed', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ]),
                  ),
                ),
              ),

              // ── Pending salons ───────────────────────────────────────────
              if (_pendingSalons.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(children: [
                      Container(
                        width: 4, height: 18,
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 8),
                      Text('Pending Approvals (${_pendingSalons.length})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _pendingCard(_pendingSalons[i]),
                      childCount: _pendingSalons.length,
                    ),
                  ),
                ),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const Spacer(),
        ]),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _pendingCard(Map<String, dynamic> salon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(salon['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text('${salon['city']}, ${salon['state']}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text('Manager: ${salon['managerName'] ?? 'Unknown'}  ·  ${salon['managerPhone'] ?? ''}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _reject(salon['id'] as String),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Reject', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _approve(salon['id'] as String),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Approve', style: TextStyle(fontSize: 13)),
            ),
          ),
        ]),
      ]),
    );
  }

  String _fmt(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000)   return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}
