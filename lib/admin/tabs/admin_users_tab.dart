import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/admin/pages/admin_user_detail_page.dart';
import 'package:no_wait_app/services/api_service.dart';

const Color _p = Color(0xFF1565C0);

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _searchCtrl = TextEditingController();
  String _role = '';
  String _dateFilter = '';
  DateTime? _customFrom;
  DateTime? _customTo;
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

  String? get _dateFrom {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'today':
        return DateFormat('yyyy-MM-dd').format(now);
      case 'week':
        return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6)));
      case 'month':
        return DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
      case 'year':
        return DateFormat('yyyy-MM-dd').format(DateTime(now.year, 1, 1));
      case 'custom':
        return _customFrom != null ? DateFormat('yyyy-MM-dd').format(_customFrom!) : null;
      default:
        return null;
    }
  }

  String? get _dateTo {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'today':
      case 'week':
      case 'month':
      case 'year':
        return DateFormat('yyyy-MM-dd').format(now);
      case 'custom':
        return _customTo != null ? DateFormat('yyyy-MM-dd').format(_customTo!) : null;
      default:
        return null;
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) { setState(() { _loading = true; _page = 1; _users = []; }); }
    try {
      final res = await ApiService.adminGetUsers(
        page: _page, search: _searchCtrl.text.trim(), role: _role,
        dateFrom: _dateFrom, dateTo: _dateTo,
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

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _customFrom != null && _customTo != null
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _p)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateFilter = 'custom';
        _customFrom = picked.start;
        _customTo = picked.end;
      });
      _load(reset: true);
    }
  }

  void _showDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailPage(
          userId:      user['id'] as String,
          initialName: user['fullName'] as String? ?? user['phone'] as String? ?? '',
          initialRole: user['role'] as String? ?? 'customer',
        ),
      ),
    ).then((_) => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    const dateOptions = {
      '': 'All Dates', 'today': 'Today', 'week': 'This Week',
      'month': 'This Month', 'year': 'This Year',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _p,
        title: const Text('Users',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(148),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: [
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              // Role filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final r in ['', 'customer', 'professional'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          r.isEmpty ? 'All' : r == 'customer' ? 'Customers' : 'Professionals',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _role == r ? Colors.white : Colors.black87),
                        ),
                        selected: _role == r,
                        onSelected: (_) { setState(() => _role = r); _load(reset: true); },
                        selectedColor: _p,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: _role == r ? _p : Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                    ),
                  Text('$_total total',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 8),
              // Date filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ...dateOptions.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: _dateFilter == e.key ? Colors.white : Colors.black87)),
                      selected: _dateFilter == e.key,
                      onSelected: (_) { setState(() => _dateFilter = e.key); _load(reset: true); },
                      selectedColor: _p,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: _dateFilter == e.key ? _p : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  )),
                  GestureDetector(
                    onTap: _pickCustomRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _dateFilter == 'custom' ? _p : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _dateFilter == 'custom' ? _p : Colors.grey.shade300),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.date_range, size: 11,
                            color: _dateFilter == 'custom' ? Colors.white : Colors.black87),
                        const SizedBox(width: 4),
                        Text(
                          _dateFilter == 'custom' && _customFrom != null
                              ? '${DateFormat('d MMM').format(_customFrom!)} – ${DateFormat('d MMM').format(_customTo ?? _customFrom!)}'
                              : 'Custom',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: _dateFilter == 'custom' ? Colors.white : Colors.black87),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
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
    final name         = user['fullName'] as String? ?? '';
    final phone        = user['phone']    as String? ?? '';
    final role         = user['role']     as String? ?? 'customer';
    final isBanned     = user['isBanned'] as bool?   ?? !(user['isActive'] as bool? ?? true);
    final initial      = name.isNotEmpty ? name[0].toUpperCase() : phone.isNotEmpty ? phone[0] : '?';
    final roleColor    = role == 'professional' ? Colors.teal.shade600 : Colors.blue.shade600;
    final bookingCount = int.tryParse(user['bookingCount']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () => _showDetail(user),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isBanned ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isBanned ? Colors.red.shade100 : Colors.transparent),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: roleColor.withValues(alpha: 0.12),
            child: Text(initial,
                style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name.isNotEmpty ? name : phone,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                      color: isBanned ? Colors.grey.shade500 : Colors.black87))),
              const SizedBox(width: 6),
              _roleBadge(role, roleColor),
              if (isBanned) ...[const SizedBox(width: 6), _badge('Banned', Colors.red.shade400)],
            ]),
            Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text('$bookingCount bookings  ·  Joined ${_fmtDate(user['createdAt'])}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ]),
      ),
    );
  }

  Widget _roleBadge(String role, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(role,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
  );

  String _fmtDate(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('d MMM yy').format(dt) : '';
  }
}
