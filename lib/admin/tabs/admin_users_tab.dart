import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';

const Color _p = Color(0xFF1565C0);

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _searchCtrl = TextEditingController();
  String _role = '';
  List<dynamic> _users = [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) { setState(() { _loading = true; _page = 1; _users = []; }); }
    try {
      final res = await ApiService.adminGetUsers(
        page: _page, search: _searchCtrl.text.trim(), role: _role,
      );
      if (mounted) {
        setState(() {
          final fetched = res['users'] as List<dynamic>? ?? [];
          _users = reset ? fetched : [..._users, ...fetched];
          _total = (res['total'] as num?)?.toInt() ?? 0;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _users.length >= _total) return;
    setState(() { _page++; _loadingMore = true; });
    _load();
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    final nowActive = user['isActive'] as bool? ?? true;
    final action = nowActive ? 'Ban' : 'Unban';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$action User', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('$action "${user['fullName'] ?? user['phone']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nowActive ? Colors.red.shade500 : Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.adminUpdateUser(user['id'] as String, {'isActive': !nowActive});
      if (mounted) AppSnackbar.success(context, 'User ${nowActive ? 'banned' : 'unbanned'}.');
      _load(reset: true);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Permanently delete "${user['fullName'] ?? user['phone']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade500, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.adminDeleteUser(user['id'] as String);
      if (mounted) AppSnackbar.success(context, 'User deleted.');
      _load(reset: true);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  void _showDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UserDetailSheet(
        user: user,
        onBan: () { Navigator.pop(context); _toggleBan(user); },
        onDelete: () { Navigator.pop(context); _deleteUser(user); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _p,
        title: const Text('Users', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: [
              // Search
              TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _load(reset: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search name, phone, email…',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () { _searchCtrl.clear(); _load(reset: true); },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              // Role filter chips
              Row(children: [
                for (final r in ['', 'customer', 'professional'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.isEmpty ? 'All' : r == 'customer' ? 'Customers' : 'Professionals',
                          style: TextStyle(fontSize: 12, color: _role == r ? Colors.white : Colors.white70)),
                      selected: _role == r,
                      onSelected: (_) { setState(() => _role = r); _load(reset: true); },
                      selectedColor: Colors.white.withValues(alpha: 0.3),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                const Spacer(),
                Text('$_total total', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ]),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _p))
          : _users.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No users found', style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) _loadMore();
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    color: _p,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        if (i == _users.length) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(color: _p, strokeWidth: 2),
                          ));
                        }
                        return _userCard(_users[i] as Map<String, dynamic>);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final name    = user['fullName'] as String? ?? '';
    final phone   = user['phone']   as String? ?? '';
    final role    = user['role']    as String? ?? 'customer';
    final active  = user['isActive'] as bool? ?? true;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : phone.isNotEmpty ? phone[0] : '?';
    final roleColor = role == 'professional' ? Colors.teal.shade600 : Colors.blue.shade600;

    return GestureDetector(
      onTap: () => _showDetail(user),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? Colors.transparent : Colors.red.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: roleColor.withValues(alpha: 0.12),
            child: Text(initial, style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name.isNotEmpty ? name : phone,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                      color: active ? Colors.black87 : Colors.grey.shade500))),
              const SizedBox(width: 6),
              _roleBadge(role, roleColor),
              if (!active) ...[const SizedBox(width: 6), _badge('Banned', Colors.red.shade400)],
            ]),
            Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text('${user['bookingCount'] ?? 0} bookings  ·  Joined ${_fmtDate(user['createdAt'])}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ]),
      ),
    );
  }

  Widget _roleBadge(String role, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(role, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
  );

  String _fmtDate(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('d MMM yy').format(dt) : '';
  }
}

// ── User detail bottom sheet ─────────────────────────────────────────────────

class _UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onBan;
  final VoidCallback onDelete;

  const _UserDetailSheet({required this.user, required this.onBan, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name    = user['fullName'] as String? ?? '';
    final phone   = user['phone']   as String? ?? '';
    final email   = user['email']   as String? ?? '—';
    final role    = user['role']    as String? ?? '';
    final active  = user['isActive'] as bool? ?? true;
    final bookings = user['recentBookings'] as List<dynamic>? ?? [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(controller: ctrl, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              // Header
              Row(children: [
                CircleAvatar(radius: 28, backgroundColor: Colors.blue.shade50,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isNotEmpty ? name : phone,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text(role.toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.blue.shade600, fontWeight: FontWeight.bold)),
                  if (!active)
                    Text('BANNED', style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.bold)),
                ])),
              ]),
              const SizedBox(height: 20),

              // Details grid
              _row(Icons.phone, 'Phone', phone),
              _row(Icons.email_outlined, 'Email', email),
              _row(Icons.person_outline, 'Gender', user['gender'] as String? ?? '—'),
              _row(Icons.cake_outlined, 'Age', '${user['age'] ?? '—'}'),
              _row(Icons.calendar_today_outlined, 'Joined',
                  _fmtDate(user['createdAt'])),
              _row(Icons.shopping_bag_outlined, 'Total Bookings',
                  '${(user['recentBookings'] as List?)?.length ?? 0}'),

              if (bookings.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Recent Bookings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...bookings.take(5).map((b) => _bookingRow(b as Map<String, dynamic>)),
              ],

              const SizedBox(height: 24),
              // Actions
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBan,
                    icon: Icon(active ? Icons.block : Icons.check_circle_outline, size: 16),
                    label: Text(active ? 'Ban User' : 'Unban User'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: active ? Colors.red : Colors.green.shade700,
                      side: BorderSide(color: active ? Colors.red : Colors.green.shade700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade500, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.grey.shade400),
      const SizedBox(width: 10),
      Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _bookingRow(Map<String, dynamic> b) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Expanded(child: Text(b['salonName'] as String? ?? '',
          style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      Text(_fmtDate(b['scheduledAt']), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      const SizedBox(width: 6),
      _statusChip(b['status'] as String? ?? ''),
    ]),
  );

  Widget _statusChip(String status) {
    final colors = {
      'completed': Colors.green, 'confirmed': Colors.blue,
      'cancelled': Colors.grey, 'rejected': Colors.red, 'pending': Colors.orange,
    };
    final c = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold)),
    );
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('d MMM yy').format(dt) : '—';
  }
}
