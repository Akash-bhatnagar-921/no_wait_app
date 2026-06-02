import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/api_service.dart';

class WalkInQueueScreen extends StatefulWidget {
  const WalkInQueueScreen({super.key});

  @override
  State<WalkInQueueScreen> createState() => _WalkInQueueScreenState();
}

class _WalkInQueueScreenState extends State<WalkInQueueScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _walkIns = [];
  List<dynamic> _barbers = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getWalkIns(date: _dateStr),
        ApiService.getMyBarbers(),
      ]);
      setState(() {
        _walkIns = results[0];
        _barbers = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Future<void> _addWalkIn() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddWalkInDialog(barbers: _barbers),
    );
    if (result != null) {
      try {
        await ApiService.addWalkIn(result);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> walkIn, String status) async {
    try {
      await ApiService.updateWalkIn(walkIn['id'] as String, {'status': status});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove walk-in?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService.deleteWalkIn(id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == _dateStr;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Walk-in Queue'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWalkIn,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Walk-in'),
        backgroundColor: primary,
      ),
      body: Column(
        children: [
          _DateBar(
            date: _selectedDate,
            isToday: isToday,
            onTap: _pickDate,
            primary: primary,
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_walkIns.isEmpty)
            Expanded(child: _EmptyState(isToday: isToday))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _walkIns.length,
                  itemBuilder: (ctx, i) => _WalkInCard(
                    walkIn: _walkIns[i] as Map<String, dynamic>,
                    onStatusChange: (s) => _updateStatus(_walkIns[i] as Map<String, dynamic>, s),
                    onDelete: () => _delete((_walkIns[i] as Map<String, dynamic>)['id'] as String),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final VoidCallback onTap;
  final Color primary;

  const _DateBar({
    required this.date,
    required this.isToday,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: primary),
            const SizedBox(width: 8),
            Text(
              isToday ? 'Today — ${DateFormat('d MMM yyyy').format(date)}' : DateFormat('EEE, d MMM yyyy').format(date),
              style: TextStyle(fontWeight: FontWeight.w600, color: primary),
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: primary),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isToday;
  const _EmptyState({required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            isToday ? 'No walk-ins yet today' : 'No walk-ins on this date',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text('Tap + to add an offline customer', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}

class _WalkInCard extends StatelessWidget {
  final Map<String, dynamic> walkIn;
  final void Function(String) onStatusChange;
  final VoidCallback onDelete;

  const _WalkInCard({
    required this.walkIn,
    required this.onStatusChange,
    required this.onDelete,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'in_progress': return Colors.blue;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'in_progress': return 'In Progress';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return 'Waiting';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = walkIn['status'] as String? ?? 'waiting';
    final sc = _statusColor(status);
    final services = (walkIn['services'] as List<dynamic>?) ?? [];
    final barberName = walkIn['barberName'] as String?;
    final phone = walkIn['customerPhone'] as String?;
    final amount = double.tryParse(walkIn['totalAmount']?.toString() ?? '0') ?? 0;
    final duration = walkIn['totalDuration'] as int? ?? 0;
    final createdAt = walkIn['createdAt'] != null
        ? DateTime.tryParse(walkIn['createdAt'] as String)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: sc.withValues(alpha:0.15),
                  child: Text(
                    (walkIn['customerName'] as String? ?? '?').substring(0, 1).toUpperCase(),
                    style: TextStyle(color: sc, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        walkIn['customerName'] as String? ?? 'Customer',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (phone != null)
                        Text(phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(status), style: TextStyle(color: sc, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (services.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: services.map((s) {
                  final svc = s as Map<String, dynamic>;
                  return Chip(
                    label: Text('${svc['serviceName']} — ₹${svc['price']}', style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (barberName != null) ...[
                  Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(barberName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                ],
                if (duration > 0) ...[
                  Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${duration}m', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                ],
                if (amount > 0) ...[
                  Icon(Icons.currency_rupee, size: 14, color: Colors.grey.shade500),
                  Text(amount.toStringAsFixed(0), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
                const Spacer(),
                if (createdAt != null)
                  Text(DateFormat('h:mm a').format(createdAt.toLocal()), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
            if (status != 'completed' && status != 'cancelled') ...[
              const Divider(height: 16),
              Row(
                children: [
                  if (status == 'waiting')
                    _actionBtn(
                      icon: Icons.play_arrow,
                      label: 'Start',
                      color: Colors.blue,
                      onTap: () => onStatusChange('in_progress'),
                    ),
                  if (status == 'in_progress')
                    _actionBtn(
                      icon: Icons.check_circle_outline,
                      label: 'Complete',
                      color: Colors.green,
                      onTap: () => onStatusChange('completed'),
                    ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.cancel_outlined,
                    label: 'Cancel',
                    color: Colors.orange,
                    onTap: () => onStatusChange('cancelled'),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade300,
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AddWalkInDialog extends StatefulWidget {
  final List<dynamic> barbers;
  const _AddWalkInDialog({required this.barbers});

  @override
  State<_AddWalkInDialog> createState() => _AddWalkInDialogState();
}

class _AddWalkInDialogState extends State<_AddWalkInDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedBarberId;
  final List<Map<String, dynamic>> _services = [];
  bool _saving = false;

  void _addService() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service name')),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price (₹)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: durCtrl, decoration: const InputDecoration(labelText: 'Duration (min)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0;
              final dur = int.tryParse(durCtrl.text) ?? 0;
              if (name.isNotEmpty) {
                setState(() => _services.add({'serviceName': name, 'price': price, 'duration': dur}));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    Navigator.pop(context, {
      'customerName': _nameCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'customerPhone': _phoneCtrl.text.trim(),
      if (_selectedBarberId != null) 'barberId': _selectedBarberId,
      if (_services.isNotEmpty) 'services': _services,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _services.fold<double>(0, (s, i) => s + (i['price'] as double? ?? 0));

    return AlertDialog(
      title: const Text('Add Walk-in'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer name *', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              if (widget.barbers.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBarberId,
                  decoration: const InputDecoration(labelText: 'Assign barber', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No preference')),
                    ...widget.barbers.map((b) {
                      final barber = b as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: barber['id'] as String,
                        child: Text(barber['name'] as String? ?? ''),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedBarberId = v),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Services', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: _addService,
                  ),
                ],
              ),
              ..._services.asMap().entries.map((e) => ListTile(
                dense: true,
                title: Text(e.value['serviceName'] as String),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${e.value['price']}'),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _services.removeAt(e.key)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              )),
              if (total > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total: ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
