import 'package:flutter/material.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';
import 'package:no_wait_app/widgets/loading_widget.dart';

class ManageBarbersScreen extends StatefulWidget {
  const ManageBarbersScreen({super.key});

  @override
  State<ManageBarbersScreen> createState() => _ManageBarbersScreenState();
}

class _ManageBarbersScreenState extends State<ManageBarbersScreen> {
  List<Map<String, dynamic>> _barbers = [];
  bool _loading = true;
  int _maxBarbers = 1;
  String _planLabel = 'Free';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getMyBarbers(),
      ApiService.getProfessionalSubscription(),
    ]);
    if (mounted) {
      final proSub   = results[1] as Map<String, dynamic>;
      final features = proSub['features'] as Map<String, dynamic>? ?? {};
      final raw      = features['maxBarbers'];
      final isUnlimited = raw == null || (raw is num && raw > 999);
      setState(() {
        _barbers    = (results[0] as List).cast<Map<String, dynamic>>();
        _maxBarbers = isUnlimited ? 999999 : (raw as num).toInt();
        _planLabel  = _formatPlanLabel(proSub['plan'] as String? ?? 'free');
        _loading    = false;
      });
    }
  }

  String _formatPlanLabel(String plan) {
    switch (plan) {
      case 'professional_starter': return 'Starter';
      case 'professional_growth':  return 'Growth';
      case 'professional_premium': return 'Premium';
      default: return 'Free';
    }
  }

  static const _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // ── Add Barber dialog ───────────────────────────────────────────────────────

  Future<void> _addBarber() async {
    final nameCtrl = TextEditingController();
    final expCtrl  = TextEditingController(text: '0');
    final specCtrl = TextEditingController();
    final bioCtrl  = TextEditingController();
    final primary  = Theme.of(context).colorScheme.primary;
    final selected = <String>{};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Barber',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(nameCtrl, 'Full Name',
                  capitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              _field(expCtrl, 'Experience (years)',
                  type: TextInputType.number),
              const SizedBox(height: 12),
              _field(specCtrl, 'Specialization (e.g. Fades, Beard)'),
              const SizedBox(height: 12),
              _field(bioCtrl, 'Short Bio', maxLines: 2),
              const SizedBox(height: 14),
              _daysPicker(selected, primary, setInner),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final result = await ApiService.addBarber(
                    name,
                    int.tryParse(expCtrl.text) ?? 0,
                    workingDays: selected.isEmpty ? null : selected.join(','),
                  );
                  // Update specialization + bio if provided
                  final spec = specCtrl.text.trim();
                  final bio  = bioCtrl.text.trim();
                  if ((spec.isNotEmpty || bio.isNotEmpty) && result['id'] != null) {
                    await ApiService.updateBarberProfile(
                      result['id'] as String,
                      specialization: spec.isEmpty ? null : spec,
                      bio: bio.isEmpty ? null : bio,
                    );
                  }
                  if (mounted) {
                    AppSnackbar.success(context, '$name added successfully.');
                    _load();
                  }
                } on ApiException catch (e) {
                  if (mounted) AppSnackbar.error(context, e.message);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose(); expCtrl.dispose();
    specCtrl.dispose(); bioCtrl.dispose();
  }

  // ── Edit Barber dialog ──────────────────────────────────────────────────────

  Future<void> _editBarber(Map<String, dynamic> barber) async {
    final id       = barber['id']   as String;
    final nameCtrl = TextEditingController(text: barber['name']           as String? ?? '');
    final expCtrl  = TextEditingController(
        text: ((barber['experience'] as num?)?.toInt() ?? 0).toString());
    final specCtrl = TextEditingController(text: barber['specialization'] as String? ?? '');
    final bioCtrl  = TextEditingController(text: barber['bio']            as String? ?? '');
    final primary  = Theme.of(context).colorScheme.primary;
    final raw      = barber['workingDays'] as String? ?? '';
    final selected = raw.isEmpty
        ? <String>{}
        : raw.split(',').map((d) => d.trim()).toSet();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Barber',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(nameCtrl, 'Full Name',
                  capitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              _field(expCtrl, 'Experience (years)',
                  type: TextInputType.number),
              const SizedBox(height: 12),
              _field(specCtrl, 'Specialization'),
              const SizedBox(height: 12),
              _field(bioCtrl, 'Short Bio', maxLines: 2),
              const SizedBox(height: 14),
              _daysPicker(selected, primary, setInner),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await Future.wait([
                    ApiService.updateBarber(
                      id, name, int.tryParse(expCtrl.text) ?? 0,
                      workingDays: selected.isEmpty ? null : selected.join(','),
                    ),
                    ApiService.updateBarberProfile(
                      id,
                      specialization: specCtrl.text.trim().isEmpty
                          ? null
                          : specCtrl.text.trim(),
                      bio: bioCtrl.text.trim().isEmpty
                          ? null
                          : bioCtrl.text.trim(),
                    ),
                  ]);
                  if (mounted) {
                    AppSnackbar.success(context, '$name updated successfully.');
                    _load();
                  }
                } on ApiException catch (e) {
                  if (mounted) AppSnackbar.error(context, e.message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose(); expCtrl.dispose();
    specCtrl.dispose(); bioCtrl.dispose();
  }

  // ── Availability dialog ─────────────────────────────────────────────────────

  Future<void> _editAvailability(Map<String, dynamic> barber) async {
    final id        = barber['id']   as String;
    final name      = barber['name'] as String? ?? 'Barber';
    final primary   = Theme.of(context).colorScheme.primary;
    bool available  = barber['isAvailable'] as bool? ?? true;
    String? leaveUntil = barber['leaveUntil'] as String?;
    String? breakUntil = barber['breakUntil'] as String?;

    String statusLabelFor(bool av, String? leave, String? brk) {
      if (leave != null) return 'On Leave';
      if (brk   != null) return 'On Break';
      return av ? 'Available' : 'Unavailable';
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final statusLabel = statusLabelFor(available, leaveUntil, breakUntil);
          final statusColor = leaveUntil != null
              ? Colors.red.shade600
              : breakUntil != null
                  ? Colors.orange.shade600
                  : available
                      ? Colors.green.shade600
                      : Colors.grey.shade600;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('$name — Availability',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.circle, size: 10, color: statusColor),
                  const SizedBox(width: 8),
                  Text(statusLabel,
                      style: TextStyle(
                          color: statusColor, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 16),
              // Available toggle
              _availabilityOption(
                icon: Icons.check_circle_outline,
                label: 'Available',
                subtitle: 'Barber is working normally',
                color: Colors.green.shade600,
                selected: available && leaveUntil == null && breakUntil == null,
                onTap: () => setInner(() {
                  available  = true;
                  leaveUntil = null;
                  breakUntil = null;
                }),
              ),
              const SizedBox(height: 8),
              // Break option
              _availabilityOption(
                icon: Icons.pause_circle_outline,
                label: 'On Break',
                subtitle: 'Temporarily unavailable today',
                color: Colors.orange.shade600,
                selected: breakUntil != null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(hours: 2)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    helpText: 'Break ends at',
                  );
                  if (picked != null) {
                    setInner(() {
                      available  = false;
                      leaveUntil = null;
                      breakUntil = picked.toIso8601String();
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              // Leave option
              _availabilityOption(
                icon: Icons.event_busy_outlined,
                label: 'On Leave',
                subtitle: 'Out for multiple days',
                color: Colors.red.shade600,
                selected: leaveUntil != null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    helpText: 'Leave ends on',
                  );
                  if (picked != null) {
                    setInner(() {
                      available  = false;
                      breakUntil = null;
                      leaveUntil = picked.toIso8601String();
                    });
                  }
                },
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiService.setBarberAvailability(
                      id,
                      isAvailable: available,
                      leaveUntil: leaveUntil,
                      breakUntil: breakUntil,
                    );
                    if (mounted) {
                      AppSnackbar.success(context, '$name availability updated.');
                      _load();
                    }
                  } on ApiException catch (e) {
                    if (mounted) AppSnackbar.error(context, e.message);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _availabilityOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? color : Colors.grey.shade500, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? color : Colors.black87)),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ),
          if (selected)
            Icon(Icons.check_circle, size: 18, color: color),
        ]),
      ),
    );
  }

  // ── Delete barber ───────────────────────────────────────────────────────────

  Future<void> _deleteBarber(String barberId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove Barber',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove $name from your salon?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteBarber(barberId);
      if (mounted) {
        AppSnackbar.success(context, '$name removed.');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      textCapitalization: capitalization,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
            horizontal: 12, vertical: maxLines > 1 ? 10 : 8),
      ),
    );
  }

  Widget _daysPicker(
    Set<String> selected,
    Color primary,
    void Function(void Function()) setInner,
  ) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Working Days',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      Text('Leave blank to follow salon schedule',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: _allDays.map((d) {
        final on = selected.contains(d);
        return GestureDetector(
          onTap: () => setInner(() =>
              on ? selected.remove(d) : selected.add(d)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: on ? primary : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: on ? primary : Colors.grey.shade300),
            ),
            child: Text(d,
                style: TextStyle(
                    fontSize: 12,
                    color: on ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500)),
          ),
        );
      }).toList()),
    ]);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final atLimit  = !_loading && _maxBarbers < 999999 && _barbers.length >= _maxBarbers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Barbers',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: atLimit ? _showUpgradePrompt : _addBarber,
        icon: Icon(atLimit ? Icons.lock_outline : Icons.person_add_outlined),
        label: Text(atLimit ? 'Upgrade to Add More' : 'Add Barber'),
        backgroundColor: atLimit ? Colors.grey.shade400 : primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const AppLoadingIndicator(message: 'Loading barbers…')
          : Column(
              children: [
                // Plan / barber count banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: Colors.grey.shade50,
                  child: Row(children: [
                    Icon(Icons.people_outline,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      _maxBarbers >= 999999
                          ? '${_barbers.length} barber${_barbers.length == 1 ? '' : 's'}  ·  $_planLabel plan (unlimited)'
                          : '${_barbers.length} / $_maxBarbers barber${_maxBarbers == 1 ? '' : 's'}  ·  $_planLabel plan',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500),
                    ),
                    if (atLimit) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text('Limit reached',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ),
                // List
                Expanded(
                  child: _barbers.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No barbers added yet',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Tap "+ Add Barber" to get started.',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13)),
                          ]),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 40 : 16, vertical: 16),
                          itemCount: _barbers.length,
                          separatorBuilder: (_, i) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _barberCard(_barbers[i], primary),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _barberCard(Map<String, dynamic> b, Color primary) {
    final id          = b['id']             as String;
    final name        = b['name']           as String? ?? 'Barber';
    final exp         = (b['experience']    as num?)?.toInt() ?? 0;
    final spec        = b['specialization'] as String?;
    final daysRaw     = b['workingDays']    as String? ?? '';
    final days        = daysRaw.isEmpty
        ? <String>[]
        : daysRaw.split(',').map((d) => d.trim()).toList();
    final isAvailable = b['isAvailable']    as bool? ?? true;
    final leaveUntil  = b['leaveUntil']     as String?;
    final breakUntil  = b['breakUntil']     as String?;

    final statusColor = leaveUntil != null
        ? Colors.red.shade500
        : breakUntil != null
            ? Colors.orange.shade500
            : isAvailable
                ? Colors.green.shade500
                : Colors.grey.shade400;
    final statusLabel = leaveUntil != null
        ? 'On Leave'
        : breakUntil != null
            ? 'On Break'
            : isAvailable
                ? 'Available'
                : 'Unavailable';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(name[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold,
                      color: primary)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(
                            fontSize: 10, color: statusColor,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              if (spec != null && spec.isNotEmpty)
                Text(spec,
                    style: TextStyle(fontSize: 12, color: primary,
                        fontWeight: FontWeight.w500)),
              Text(
                exp == 0 ? 'Experience not specified' : '$exp yr${exp == 1 ? '' : 's'} experience',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ]),
          ),
        ]),
        // Working days
        if (days.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 4, runSpacing: 4,
            children: days.map((d) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(d,
                  style: TextStyle(
                      fontSize: 10, color: primary,
                      fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text('Follows salon schedule',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic)),
        ],
        // Action row
        const SizedBox(height: 10),
        Row(children: [
          const Spacer(),
          _actionBtn(
            icon: Icons.schedule_outlined,
            label: 'Availability',
            color: statusColor,
            onTap: () => _editAvailability(b),
          ),
          const SizedBox(width: 8),
          _actionBtn(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: Colors.blue.shade600,
            onTap: () => _editBarber(b),
          ),
          const SizedBox(width: 8),
          _actionBtn(
            icon: Icons.delete_outline,
            label: 'Remove',
            color: Colors.red.shade400,
            onTap: () => _deleteBarber(id, name),
          ),
        ]),
      ]),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _showUpgradePrompt() {
    final limit = _maxBarbers >= 999999 ? 'unlimited' : '$_maxBarbers';
    AppSnackbar.warning(
      context,
      '$_planLabel plan allows up to $limit barber${_maxBarbers == 1 ? '' : 's'}. Upgrade your plan to add more.',
    );
  }
}
