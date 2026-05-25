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
      final proSub  = results[1] as Map<String, dynamic>;
      final features = proSub['features'] as Map<String, dynamic>? ?? {};
      final raw     = features['maxBarbers'];
      final isUnlimited = raw == null || (raw is num && raw > 999);
      setState(() {
        _barbers   = (results[0] as List).cast<Map<String, dynamic>>();
        _maxBarbers = isUnlimited ? 999999 : (raw as num).toInt();
        _planLabel  = _formatPlanLabel(proSub['plan'] as String? ?? 'free');
        _loading   = false;
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

  Future<void> _addBarber() async {
    final nameCtrl = TextEditingController();
    final expCtrl  = TextEditingController(text: '0');
    final primary  = Theme.of(context).colorScheme.primary;
    final selected = <String>{};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Barber',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Experience (years)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            _daysPicker(selected, primary, setInner),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ApiService.addBarber(
                    name,
                    int.tryParse(expCtrl.text) ?? 0,
                    workingDays: selected.isEmpty
                        ? null
                        : selected.join(','),
                  );
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
    nameCtrl.dispose();
    expCtrl.dispose();
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
              border: Border.all(
                  color: on ? primary : Colors.grey.shade300),
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

  Future<void> _editBarber(Map<String, dynamic> barber) async {
    final id       = barber['id']   as String;
    final nameCtrl = TextEditingController(text: barber['name'] as String? ?? '');
    final expCtrl  = TextEditingController(
        text: ((barber['experience'] as num?)?.toInt() ?? 0).toString());
    final primary  = Theme.of(context).colorScheme.primary;
    // Pre-fill existing working days
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
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: expCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Experience (years)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          _daysPicker(selected, primary, setInner),
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiService.updateBarber(
                  id, name, int.tryParse(expCtrl.text) ?? 0,
                  workingDays: selected.isEmpty ? null : selected.join(','),
                );
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
      ),     // AlertDialog
      ),     // StatefulBuilder
    );       // showDialog
    nameCtrl.dispose();
    expCtrl.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final atLimit = !_loading && _maxBarbers < 999999 && _barbers.length >= _maxBarbers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Barbers',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: atLimit ? _showUpgradePrompt : _addBarber,
        icon: Icon(atLimit
            ? Icons.lock_outline
            : Icons.person_add_outlined),
        label: Text(atLimit ? 'Upgrade to Add More' : 'Add Barber'),
        backgroundColor: atLimit ? Colors.grey.shade400 : primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const AppLoadingIndicator(message: 'Loading barbers…')
          : Column(
              children: [
                // ── Plan / barber count banner ──────────────────────────────
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
                          border:
                              Border.all(color: Colors.orange.shade200),
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
                // ── List ───────────────────────────────────────────────────
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
                        style:
                            TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ]),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 40 : 16, vertical: 16),
                  itemCount: _barbers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final b           = _barbers[i];
                    final id          = b['id']           as String;
                    final name        = b['name']         as String? ?? 'Barber';
                    final exp         = (b['experience']  as num?)?.toInt() ?? 0;
                    final daysRaw     = b['workingDays']  as String? ?? '';
                    final days        = daysRaw.isEmpty
                        ? <String>[]
                        : daysRaw.split(',').map((d) => d.trim()).toList();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(name[0].toUpperCase(),
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primary)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                exp == 0
                                    ? 'Experience not specified'
                                    : '$exp yr${exp == 1 ? '' : 's'} experience',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 4),
                              if (days.isEmpty)
                                Text('Follows salon schedule',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                        fontStyle: FontStyle.italic))
                              else
                                Wrap(
                                  spacing: 4, runSpacing: 4,
                                  children: days.map((d) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(d,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: primary,
                                            fontWeight: FontWeight.w600)),
                                  )).toList(),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _editBarber(b),
                          icon: Icon(Icons.edit_outlined,
                              color: Colors.blue.shade400),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _deleteBarber(id, name),
                          icon: Icon(Icons.delete_outline,
                              color: Colors.red.shade400),
                          tooltip: 'Remove',
                        ),
                      ]),
                    );
                  },
                ),     // ListView.separated
              ),       // Expanded
            ],         // Column children
          ),           // Column
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
