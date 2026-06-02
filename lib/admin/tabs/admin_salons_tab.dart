import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:no_wait_app/admin/pages/admin_salon_detail_page.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';

const Color _p = Color(0xFF1565C0);

class AdminSalonsTab extends StatefulWidget {
  const AdminSalonsTab({super.key});

  @override
  State<AdminSalonsTab> createState() => _AdminSalonsTabState();
}

class _AdminSalonsTabState extends State<AdminSalonsTab> {
  final _searchCtrl = TextEditingController();
  String _status = '';
  List<dynamic> _salons = [];
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
    if (reset) setState(() { _loading = true; _page = 1; _salons = []; });
    try {
      final res = await ApiService.adminGetSalons(
        page: _page, search: _searchCtrl.text.trim(), status: _status,
      );
      if (mounted) {
        setState(() {
          final fetched = res['salons'] as List<dynamic>? ?? [];
          _salons = reset ? fetched : [..._salons, ...fetched];
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
    if (_loadingMore || _salons.length >= _total) return;
    setState(() { _page++; _loadingMore = true; });
    _load();
  }

  Future<void> _approve(String id) async {
    try {
      await ApiService.adminApproveSalon(id);
      if (mounted) AppSnackbar.success(context, 'Salon approved.');
      _load(reset: true);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _reject(String id) async {
    try {
      await ApiService.adminRejectSalon(id);
      if (mounted) AppSnackbar.success(context, 'Salon rejected.');
      _load(reset: true);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  void _showDetail(Map<String, dynamic> salon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSalonDetailPage(
          salonId:       salon['id']     as String,
          initialName:   salon['name']   as String? ?? '',
          initialStatus: salon['status'] as String? ?? '',
        ),
      ),
    ).then((_) => _load(reset: true));
  }

  void _showAddSalon() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddSalonSheet(onCreated: (code) {
        Navigator.pop(context);
        _load(reset: true);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Salon Created!',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Share this secret code with the professional for login:'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _p.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(code,
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold,
                          letterSpacing: 6, color: _p)),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Code'),
                ),
              ]),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _p, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusOptions = {
      '': 'All', 'pending': 'Pending', 'approved': 'Approved', 'rejected': 'Rejected',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _p,
        title: const Text('Salons',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: [
              TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _load(reset: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search name, city…',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () { _searchCtrl.clear(); _load(reset: true); })
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ...statusOptions.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _status == e.key ? Colors.white : Colors.black87)),
                      selected: _status == e.key,
                      onSelected: (_) {
                        setState(() => _status = e.key);
                        _load(reset: true);
                      },
                      selectedColor: _p,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: _status == e.key ? _p : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  )),
                  Text('$_total total',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSalon,
        backgroundColor: _p,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Salon'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _p))
          : _salons.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.store_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No salons found', style: TextStyle(color: Colors.grey.shade500)),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: _salons.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        if (i == _salons.length) {
                          return const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(color: _p, strokeWidth: 2)));
                        }
                        return _salonCard(_salons[i] as Map<String, dynamic>);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _salonCard(Map<String, dynamic> salon) {
    final status    = salon['status']           as String? ?? 'pending';
    final isBanned  = salon['isCurrentlyBanned'] as bool?  ?? (salon['isBanned'] as bool? ?? false);
    final statusColor = status == 'approved'
        ? Colors.green.shade600
        : status == 'pending'
            ? Colors.orange.shade600
            : Colors.red.shade500;

    return GestureDetector(
      onTap: () => _showDetail(salon),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isBanned ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isBanned
                  ? Colors.red.shade200
                  : status == 'pending'
                      ? Colors.orange.shade200
                      : Colors.transparent),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(salon['name'] as String? ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            if (isBanned) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.red.shade600, borderRadius: BorderRadius.circular(6)),
                child: const Text('BANNED',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 6),
            ],
            _statusBadge(status, statusColor),
          ]),
          const SizedBox(height: 4),
          Text('${salon['city']}, ${salon['state']}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Text(
              'Manager: ${salon['managerName'] ?? '—'}  ·  ${salon['managerPhone'] ?? ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => _reject(salon['id'] as String),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                child: const Text('Reject', style: TextStyle(fontSize: 12)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => _approve(salon['id'] as String),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                child: const Text('Approve', style: TextStyle(fontSize: 12)),
              )),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
  );
}

// ── Add salon sheet ────────────────────────────────────────────────────────────

class _AddSalonSheet extends StatefulWidget {
  final void Function(String secretCode) onCreated;
  const _AddSalonSheet({required this.onCreated});

  @override
  State<_AddSalonSheet> createState() => _AddSalonSheetState();
}

class _AddSalonSheetState extends State<_AddSalonSheet> {
  final _nameCtrl           = TextEditingController();
  final _addrCtrl           = TextEditingController();
  final _cityCtrl           = TextEditingController();
  final _stateCtrl          = TextEditingController();
  final _pincodeCtrl        = TextEditingController();
  final _phoneCtrl          = TextEditingController();
  final _mgrNameCtrl        = TextEditingController();
  final _mgrEmailCtrl       = TextEditingController();
  final _contactCtrl        = TextEditingController();
  final _franchiseSearchCtrl = TextEditingController();

  bool   _loading            = false;
  bool   _submitted          = false;
  bool   _isFranchise        = false;
  String _franchiseId        = '';
  String _franchiseName      = '';
  List<Map<String, dynamic>> _franchiseResults  = [];
  bool   _searchingFranchise = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _addrCtrl, _cityCtrl, _stateCtrl, _pincodeCtrl,
        _phoneCtrl, _mgrNameCtrl, _mgrEmailCtrl, _contactCtrl, _franchiseSearchCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _searchFranchise(String query) async {
    if (query.trim().isEmpty) { setState(() => _franchiseResults = []); return; }
    setState(() => _searchingFranchise = true);
    try {
      final results = await ApiService.searchFranchises(query.trim());
      if (mounted) {
        setState(() {
          _franchiseResults = results
              .map((e) => {'id': e['id'] as String, 'name': e['name'] as String})
              .toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _franchiseResults = []);
    } finally {
      if (mounted) setState(() => _searchingFranchise = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (_nameCtrl.text.trim().isEmpty || _addrCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty || _stateCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) { return; }

    if (_isFranchise && _franchiseId.isEmpty && _franchiseName.isEmpty) {
      AppSnackbar.error(context, 'Select a franchise or type a new franchise name.');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.adminCreateSalon({
        'name':          _nameCtrl.text.trim(),
        'address':       _addrCtrl.text.trim(),
        'city':          _cityCtrl.text.trim(),
        'state':         _stateCtrl.text.trim(),
        'pincode':       _pincodeCtrl.text.trim(),
        'managerPhone':  _phoneCtrl.text.trim(),
        'managerName':   _mgrNameCtrl.text.trim(),
        'managerEmail':  _mgrEmailCtrl.text.trim(),
        'contactNumber': _contactCtrl.text.trim(),
        'isFranchise':   _isFranchise,
        if (_isFranchise && _franchiseId.isNotEmpty) 'franchiseId': _franchiseId,
        if (_isFranchise && _franchiseName.isNotEmpty) 'franchiseName': _franchiseName,
      });
      final code = (res['salon'] as Map?)?['secretCode'] as String?
          ?? res['secretCode'] as String? ?? '';
      widget.onCreated(code);
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
        expand: false, initialChildSize: 0.85, maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                const Text('Add New Salon',
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
              _f('Salon Name *', _nameCtrl),
              _f('Address *', _addrCtrl),
              Row(children: [
                Expanded(child: _f('City *', _cityCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _f('State *', _stateCtrl)),
              ]),
              _f('Pincode', _pincodeCtrl, keyboard: TextInputType.number),
              const Divider(height: 24),
              const Text('Manager Info',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _f('Manager Phone *', _phoneCtrl, keyboard: TextInputType.phone),
              _f('Manager Name', _mgrNameCtrl),
              _f('Manager Email', _mgrEmailCtrl, keyboard: TextInputType.emailAddress),
              _f('Salon Contact Number', _contactCtrl, keyboard: TextInputType.phone),
              const Divider(height: 24),
              // ── Franchise ──────────────────────────────────────────────
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isFranchise,
                title: const Text('Is this salon part of a franchise?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                activeColor: _p,
                onChanged: (val) => setState(() {
                  _isFranchise = val ?? false;
                  if (!_isFranchise) {
                    _franchiseId = '';
                    _franchiseName = '';
                    _franchiseSearchCtrl.clear();
                    _franchiseResults = [];
                  }
                }),
              ),
              if (_isFranchise) ...[
                const SizedBox(height: 4),
                _franchiseSection(),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _p, foregroundColor: Colors.white,
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Create & Approve Salon',
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
      {TextInputType? keyboard}) {
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
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: empty ? Colors.red : Colors.grey.shade300)),
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

  Widget _franchiseSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_franchiseId.isNotEmpty || _franchiseName.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _p.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _p.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.business, color: _p, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              _franchiseName.isNotEmpty ? _franchiseName : _franchiseId,
              style: const TextStyle(fontWeight: FontWeight.w500),
            )),
            GestureDetector(
              onTap: () => setState(() {
                _franchiseId = '';
                _franchiseName = '';
                _franchiseSearchCtrl.clear();
                _franchiseResults = [];
              }),
              child: const Icon(Icons.close, size: 16),
            ),
          ]),
        ),
      TextField(
        controller: _franchiseSearchCtrl,
        onChanged: _searchFranchise,
        decoration: InputDecoration(
          hintText: 'Search franchise group (e.g. Image Salon)',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: const Icon(Icons.search, size: 18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
      const SizedBox(height: 4),
      if (_searchingFranchise)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: SizedBox(
              height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _p))),
        )
      else if (_franchiseResults.isNotEmpty)
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: _franchiseResults.map((f) => ListTile(
              dense: true,
              leading: const Icon(Icons.business_outlined, color: _p),
              title: Text(f['name'] as String),
              onTap: () => setState(() {
                _franchiseId   = f['id']   as String;
                _franchiseName = f['name'] as String;
                _franchiseSearchCtrl.text = f['name'] as String;
                _franchiseResults = [];
              }),
            )).toList(),
          ),
        )
      else if (_franchiseSearchCtrl.text.trim().isNotEmpty && !_searchingFranchise)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.add_circle_outline, color: _p),
          title: Text(
            'Create "${_franchiseSearchCtrl.text.trim()}" as new group',
            style: const TextStyle(fontSize: 13),
          ),
          onTap: () {
            final name = _franchiseSearchCtrl.text.trim();
            setState(() {
              _franchiseId   = '';
              _franchiseName = name;
              _franchiseResults = [];
            });
          },
        ),
    ]);
  }
}
