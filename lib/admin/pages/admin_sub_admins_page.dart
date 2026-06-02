import 'package:flutter/material.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';

const Color _p = Color(0xFF1565C0);

const Map<String, String> kCategoryLabels = {
  'users':    'Users',
  'salons':   'Salons',
  'bookings': 'Bookings',
  'offers':   'Offers',
  'coupons':  'Coupons',
};

const Map<String, Map<String, String>> kGranularPermissions = {
  'users': {
    'view':          'View Users',
    'ban':           'Ban / Unban User',
    'changePlan':    'Change Plan',
    'assignCoupons': 'Assign Coupons',
  },
  'salons': {
    'view':    'View Salons',
    'approve': 'Approve Salon',
    'reject':  'Reject Salon',
    'delete':  'Delete Salon',
  },
  'bookings': {
    'view':   'View Bookings',
    'cancel': 'Cancel Booking',
  },
  'offers': {
    'view':   'View Offers',
    'create': 'Create Offer',
    'edit':   'Edit Offer',
    'delete': 'Delete Offer',
  },
  'coupons': {
    'view':   'View Coupons',
    'create': 'Create Coupon',
    'edit':   'Edit Coupon',
    'delete': 'Delete Coupon',
    'assign': 'Assign to Users',
  },
};

/// Normalises permissions from old flat-bool format or new nested format.
Map<String, Map<String, bool>> _normalisePerms(Map<String, dynamic> raw) {
  return {
    for (final cat in kGranularPermissions.keys)
      cat: () {
        final catVal = raw[cat];
        final actions = kGranularPermissions[cat]!;
        if (catVal is Map) {
          return {
            for (final a in actions.keys)
              a: (catVal as Map<String, dynamic>)[a] == true,
          };
        }
        final allOn = catVal == true;
        return { for (final a in actions.keys) a: allOn };
      }(),
  };
}

int _enabledActionCount(Map<String, Map<String, bool>> perms, String cat) =>
    (perms[cat]?.values ?? []).where((v) => v).length;

int _totalEnabledActions(Map<String, Map<String, bool>> perms) =>
    perms.values.expand((m) => m.values).where((v) => v).length;

// ─────────────────────────────────────────────────────────────────────────────

class AdminSubAdminsPage extends StatefulWidget {
  const AdminSubAdminsPage({super.key});

  @override
  State<AdminSubAdminsPage> createState() => _AdminSubAdminsPageState();
}

class _AdminSubAdminsPageState extends State<AdminSubAdminsPage> {
  List<dynamic> _subAdmins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.adminListSubAdmins();
      if (mounted) setState(() { _subAdmins = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Sub-Admin',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove "${admin['fullName']}" from the admin panel?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.adminDeleteSubAdmin(admin['id'] as String);
      if (mounted) AppSnackbar.success(context, 'Sub-admin removed.');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  void _showCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateSubAdminSheet(onCreated: () {
        Navigator.pop(context);
        _load();
      }),
    );
  }

  void _showEditPermissions(Map<String, dynamic> admin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPermissionsSheet(
        admin: admin,
        onUpdated: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _p,
        title: const Text('Sub-Admins',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreate,
        backgroundColor: _p,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Sub-Admin'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _p))
          : _subAdmins.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.manage_accounts_outlined,
                        size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No sub-admins yet.',
                        style:
                            TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text('Tap "Add Sub-Admin" to create one.',
                        style:
                            TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _p,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _subAdmins.length,
                    itemBuilder: (_, i) =>
                        _adminCard(_subAdmins[i] as Map<String, dynamic>),
                  ),
                ),
    );
  }

  Widget _adminCard(Map<String, dynamic> admin) {
    final rawPerms = (admin['permissions'] as Map<String, dynamic>?) ?? {};
    final perms    = _normalisePerms(rawPerms);
    final total    = _totalEnabledActions(perms);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _p.withValues(alpha: 0.1),
            child: Text(
              (admin['fullName'] as String? ?? 'A')[0].toUpperCase(),
              style: const TextStyle(
                  color: _p, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(admin['fullName'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(admin['phone'] as String? ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'edit') _showEditPermissions(admin);
              if (v == 'delete') _delete(admin);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('Edit Permissions'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 10),
        if (total == 0)
          Text('No permissions granted',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: kGranularPermissions.keys
                .where((cat) => _enabledActionCount(perms, cat) > 0)
                .map((cat) => _permChip(
                      kCategoryLabels[cat] ?? cat,
                      _enabledActionCount(perms, cat),
                    ))
                .toList(),
          ),
      ]),
    );
  }

  Widget _permChip(String label, int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: _p.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _p.withValues(alpha: 0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: _p, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
                color: _p, borderRadius: BorderRadius.circular(10)),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      );
}

// ── Create sub-admin sheet ────────────────────────────────────────────────────

class _CreateSubAdminSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateSubAdminSheet({required this.onCreated});

  @override
  State<_CreateSubAdminSheet> createState() => _CreateSubAdminSheetState();
}

class _CreateSubAdminSheetState extends State<_CreateSubAdminSheet> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading   = false;
  bool _submitted = false;

  final Map<String, Map<String, bool>> _perms = {
    for (final cat in kGranularPermissions.keys)
      cat: { for (final a in kGranularPermissions[cat]!.keys) a: false },
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty) return;

    setState(() => _loading = true);
    try {
      await ApiService.adminCreateSubAdmin({
        'fullName':    _nameCtrl.text.trim(),
        'phone':       _phoneCtrl.text.trim(),
        'password':    _passCtrl.text,
        'permissions': _perms,
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                const Text('Create Sub-Admin',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  _f('Full Name *', _nameCtrl, hint: 'e.g. Ravi Kumar'),
                  _f('Phone *', _phoneCtrl,
                      hint: '9876543210',
                      keyboard: TextInputType.phone),
                  _f('Password *', _passCtrl,
                      hint: '••••••••',
                      obscure: true,
                      keyboard: TextInputType.visiblePassword),
                  const SizedBox(height: 4),
                  const Text('Permissions',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Expand each section to set granular access.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  ..._buildPermissionTiles(),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _p,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text('Create Sub-Admin',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildPermissionTiles() {
    return kGranularPermissions.entries.map((catEntry) {
      final cat     = catEntry.key;
      final actions = catEntry.value;
      final catPerms = _perms[cat]!;
      final enabledCount = catPerms.values.where((v) => v).length;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding:
                const EdgeInsets.fromLTRB(14, 0, 14, 8),
            leading: Icon(
              _catIcon(cat),
              size: 20,
              color: enabledCount > 0 ? _p : Colors.grey.shade400,
            ),
            title: Text(
              kCategoryLabels[cat] ?? cat,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabledCount > 0 ? _p : Colors.grey.shade700),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (enabledCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _p,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$enabledCount/${actions.length}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18, color: Colors.grey),
            ]),
            children: actions.entries.map((aEntry) {
              return CheckboxListTile(
                title: Text(aEntry.value,
                    style: const TextStyle(fontSize: 12)),
                value: catPerms[aEntry.key] ?? false,
                onChanged: (v) => setState(
                    () => _perms[cat]![aEntry.key] = v ?? false),
                activeColor: _p,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
      );
    }).toList();
  }

  Widget _f(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard, bool obscure = false}) {
    final isRequired = label.endsWith('*');
    final empty = _submitted && isRequired && ctrl.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          obscureText: obscure,
          onChanged: (_) { if (_submitted) { setState(() {}); } },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 13),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: empty
                        ? Colors.red.shade400
                        : Colors.grey.shade300)),
            errorText: empty ? 'Required' : null,
          ),
        ),
      ]),
    );
  }
}

// ── Edit permissions sheet ────────────────────────────────────────────────────

class _EditPermissionsSheet extends StatefulWidget {
  final Map<String, dynamic> admin;
  final VoidCallback onUpdated;
  const _EditPermissionsSheet(
      {required this.admin, required this.onUpdated});

  @override
  State<_EditPermissionsSheet> createState() =>
      _EditPermissionsSheetState();
}

class _EditPermissionsSheetState extends State<_EditPermissionsSheet> {
  late Map<String, Map<String, bool>> _perms;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final existing =
        (widget.admin['permissions'] as Map<String, dynamic>?) ?? {};
    _perms = _normalisePerms(existing);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ApiService.adminUpdateSubAdminPermissions(
          widget.admin['id'] as String, _perms);
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Permissions',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        Text(widget.admin['fullName'] as String? ?? '',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ]),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text('Expand each section to configure access.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 10),
                  ..._buildPermissionTiles(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _p,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text('Save Permissions',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildPermissionTiles() {
    return kGranularPermissions.entries.map((catEntry) {
      final cat      = catEntry.key;
      final actions  = catEntry.value;
      final catPerms = _perms[cat]!;
      final enabledCount = catPerms.values.where((v) => v).length;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding:
                const EdgeInsets.fromLTRB(14, 0, 14, 8),
            leading: Icon(
              _catIcon(cat),
              size: 20,
              color: enabledCount > 0 ? _p : Colors.grey.shade400,
            ),
            title: Text(
              kCategoryLabels[cat] ?? cat,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabledCount > 0 ? _p : Colors.grey.shade700),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (enabledCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _p,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$enabledCount/${actions.length}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18, color: Colors.grey),
            ]),
            children: actions.entries.map((aEntry) {
              return CheckboxListTile(
                title: Text(aEntry.value,
                    style: const TextStyle(fontSize: 12)),
                value: catPerms[aEntry.key] ?? false,
                onChanged: (v) => setState(
                    () => _perms[cat]![aEntry.key] = v ?? false),
                activeColor: _p,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
      );
    }).toList();
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

IconData _catIcon(String cat) {
  switch (cat) {
    case 'users':    return Icons.people_outline;
    case 'salons':   return Icons.store_outlined;
    case 'bookings': return Icons.calendar_month_outlined;
    case 'offers':   return Icons.local_offer_outlined;
    case 'coupons':  return Icons.discount_outlined;
    default:         return Icons.lock_outline;
  }
}
