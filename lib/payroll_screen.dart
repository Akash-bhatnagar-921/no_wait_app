import 'package:flutter/material.dart';
import 'services/api_service.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  List<dynamic> _payroll = [];
  List<dynamic> _attendance = [];
  List<dynamic> _barbers = [];
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getPayrollSummary(month: _month, year: _year),
        ApiService.getAttendance(month: _month, year: _year),
        ApiService.getMyBarbers(),
      ]);
      setState(() {
        _payroll = results[0];
        _attendance = results[1];
        _barbers = results[2];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickMonth() async {
    int tempMonth = _month;
    int tempYear = _year;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Select Month'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setInner(() { tempYear--; }),
                  ),
                  Text('$tempYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setInner(() { tempYear++; }),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (i) {
                  final active = tempMonth == i + 1;
                  return GestureDetector(
                    onTap: () => setInner(() => tempMonth = i + 1),
                    child: Container(
                      width: 56,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? Theme.of(ctx).colorScheme.primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _months[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() { _month = tempMonth; _year = tempYear; });
      _load();
    }
  }

  Future<void> _editPayrollSettings(Map<String, dynamic> barber) async {
    final salaryCtrl = TextEditingController(
      text: (double.tryParse(barber['baseSalary']?.toString() ?? '0') ?? 0).toStringAsFixed(0),
    );
    final commCtrl = TextEditingController(
      text: (double.tryParse(barber['commissionRate']?.toString() ?? '0') ?? 0).toStringAsFixed(1),
    );
    String salaryType = barber['salaryType'] as String? ?? 'fixed';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text('${barber['barberName']} — Payroll Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: salaryType,
                decoration: const InputDecoration(labelText: 'Salary type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'fixed', child: Text('Fixed salary')),
                  DropdownMenuItem(value: 'commission', child: Text('Commission only')),
                  DropdownMenuItem(value: 'hybrid', child: Text('Fixed + Commission')),
                ],
                onChanged: (v) => setInner(() => salaryType = v ?? 'fixed'),
              ),
              if (salaryType != 'commission') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: salaryCtrl,
                  decoration: const InputDecoration(labelText: 'Base salary (₹/month)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ],
              if (salaryType != 'fixed') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: commCtrl,
                  decoration: const InputDecoration(labelText: 'Commission rate (%)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await ApiService.updateBarberPayroll(barber['barberId'] as String, {
          'salaryType': salaryType,
          'baseSalary': double.tryParse(salaryCtrl.text) ?? 0,
          'commissionRate': double.tryParse(commCtrl.text) ?? 0,
        });
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

  Future<void> _markAttendance(String barberId, String barberName, String date) async {
    String status = 'present';
    final clockInCtrl = TextEditingController();
    final clockOutCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text('Attendance — $barberName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Date: $date', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Present')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent')),
                  DropdownMenuItem(value: 'leave', child: Text('Leave')),
                  DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                ],
                onChanged: (v) => setInner(() => status = v ?? 'present'),
              ),
              if (status == 'present' || status == 'half_day') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: clockInCtrl,
                  decoration: const InputDecoration(labelText: 'Clock in (HH:MM)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: clockOutCtrl,
                  decoration: const InputDecoration(labelText: 'Clock out (HH:MM)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.datetime,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await ApiService.markAttendance({
          'barberId': barberId,
          'date': date,
          'status': status,
          if (clockInCtrl.text.isNotEmpty) 'clockIn': clockInCtrl.text,
          if (clockOutCtrl.text.isNotEmpty) 'clockOut': clockOutCtrl.text,
        });
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Payroll & Attendance'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Payroll'),
            Tab(text: 'Attendance'),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text('${_months[_month - 1]} $_year'),
            onPressed: _pickMonth,
            style: TextButton.styleFrom(foregroundColor: primary),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _PayrollTab(
                      payroll: _payroll,
                      month: _month,
                      year: _year,
                      months: _months,
                      onEditSettings: _editPayrollSettings,
                    ),
                    _AttendanceTab(
                      attendance: _attendance,
                      barbers: _barbers,
                      month: _month,
                      year: _year,
                      onMark: _markAttendance,
                    ),
                  ],
                ),
    );
  }
}

// ── Payroll Tab ───────────────────────────────────────────────────────────────

class _PayrollTab extends StatelessWidget {
  final List<dynamic> payroll;
  final int month;
  final int year;
  final List<String> months;
  final void Function(Map<String, dynamic>) onEditSettings;

  const _PayrollTab({
    required this.payroll,
    required this.month,
    required this.year,
    required this.months,
    required this.onEditSettings,
  });

  double get _totalPay => payroll.fold(0,
      (s, p) => s + (double.tryParse((p as Map<String, dynamic>)['totalPay']?.toString() ?? '0') ?? 0));

  @override
  Widget build(BuildContext context) {
    if (payroll.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No barbers found', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(
          label: 'Total Payroll — ${months[month - 1]} $year',
          value: '₹${_totalPay.toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.indigo,
        ),
        const SizedBox(height: 12),
        ...payroll.map((p) => _PayrollCard(
          data: p as Map<String, dynamic>,
          onEditSettings: () => onEditSettings(p),
        )),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.85), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayrollCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEditSettings;

  const _PayrollCard({required this.data, required this.onEditSettings});

  @override
  Widget build(BuildContext context) {
    final baseSalary = double.tryParse(data['baseSalary']?.toString() ?? '0') ?? 0;
    final commission = double.tryParse(data['commissionEarned']?.toString() ?? '0') ?? 0;
    final totalPay = double.tryParse(data['totalPay']?.toString() ?? '0') ?? 0;
    final revenue = double.tryParse(data['revenue']?.toString() ?? '0') ?? 0;
    final commRate = double.tryParse(data['commissionRate']?.toString() ?? '0') ?? 0;
    final salaryType = data['salaryType'] as String? ?? 'fixed';
    final attendance = data['attendance'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    (data['barberName'] as String? ?? '?').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['barberName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        salaryType == 'fixed' ? 'Fixed Salary' : salaryType == 'commission' ? 'Commission Only' : 'Fixed + Commission',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: onEditSettings,
                  tooltip: 'Payroll settings',
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                _statCol('Revenue', '₹${revenue.toStringAsFixed(0)}', Colors.blue),
                if (salaryType != 'commission')
                  _statCol('Base Salary', '₹${baseSalary.toStringAsFixed(0)}', Colors.teal),
                if (salaryType != 'fixed' && commRate > 0)
                  _statCol('Commission (${ commRate.toStringAsFixed(0)}%)', '₹${commission.toStringAsFixed(0)}', Colors.purple),
                _statCol('Total Pay', '₹${totalPay.toStringAsFixed(0)}', Colors.green),
              ],
            ),
            if (attendance != null) ...[
              const Divider(height: 16),
              Row(
                children: [
                  _attendancePill('P', attendance['present'], Colors.green),
                  const SizedBox(width: 6),
                  _attendancePill('A', attendance['absent'], Colors.red),
                  const SizedBox(width: 6),
                  _attendancePill('L', attendance['leave'], Colors.orange),
                  const SizedBox(width: 6),
                  _attendancePill('½', attendance['halfDay'], Colors.blue),
                  const Spacer(),
                  Text(
                    '${data['totalWalkIns']} walk-ins',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _attendancePill(String label, dynamic count, Color color) {
    final n = count is int ? count : int.tryParse(count?.toString() ?? '0') ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $n',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Attendance Tab ────────────────────────────────────────────────────────────

class _AttendanceTab extends StatelessWidget {
  final List<dynamic> attendance;
  final List<dynamic> barbers;
  final int month;
  final int year;
  final Future<void> Function(String, String, String) onMark;

  const _AttendanceTab({
    required this.attendance,
    required this.barbers,
    required this.month,
    required this.year,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final today = '$year-${month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Mark Today\'s Attendance'),
                  onPressed: barbers.isEmpty ? null : () => _showMarkDialog(context, today),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: attendance.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_note_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No attendance records yet', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: attendance.length,
                  itemBuilder: (ctx, i) => _AttendanceRow(
                    row: attendance[i] as Map<String, dynamic>,
                    onEdit: () {
                      final row = attendance[i] as Map<String, dynamic>;
                      onMark(row['barberId'] as String, row['barberName'] as String? ?? '', row['date'] as String? ?? today);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showMarkDialog(BuildContext context, String today) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _MarkBulkDialog(
        barbers: barbers,
        date: today,
        onMark: onMark,
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onEdit;

  const _AttendanceRow({required this.row, required this.onEdit});

  Color _statusColor(String s) {
    switch (s) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'leave': return Colors.orange;
      case 'half_day': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'present': return 'Present';
      case 'absent': return 'Absent';
      case 'leave': return 'Leave';
      case 'half_day': return 'Half Day';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = row['status'] as String? ?? 'present';
    final sc = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: sc.withValues(alpha: 0.15),
          child: Text(
            (row['barberName'] as String? ?? '?').substring(0, 1).toUpperCase(),
            style: TextStyle(color: sc, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        title: Text(row['barberName'] as String? ?? '—', style: const TextStyle(fontSize: 13)),
        subtitle: Text(row['date'] as String? ?? '', style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_statusLabel(status), style: TextStyle(fontSize: 11, color: sc, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkBulkDialog extends StatefulWidget {
  final List<dynamic> barbers;
  final String date;
  final Future<void> Function(String, String, String) onMark;

  const _MarkBulkDialog({required this.barbers, required this.date, required this.onMark});

  @override
  State<_MarkBulkDialog> createState() => _MarkBulkDialogState();
}

class _MarkBulkDialogState extends State<_MarkBulkDialog> {
  late final Map<String, String> _statusMap;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _statusMap = {
      for (final b in widget.barbers) (b as Map<String, dynamic>)['id'] as String: 'present',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Attendance — ${widget.date}'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.barbers.map((b) {
              final barber = b as Map<String, dynamic>;
              final id = barber['id'] as String;
              final name = barber['name'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                    DropdownButton<String>(
                      value: _statusMap[id],
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'present', child: Text('Present', style: TextStyle(fontSize: 12, color: Colors.green))),
                        DropdownMenuItem(value: 'absent', child: Text('Absent', style: TextStyle(fontSize: 12, color: Colors.red))),
                        DropdownMenuItem(value: 'leave', child: Text('Leave', style: TextStyle(fontSize: 12, color: Colors.orange))),
                        DropdownMenuItem(value: 'half_day', child: Text('Half Day', style: TextStyle(fontSize: 12, color: Colors.blue))),
                      ],
                      onChanged: (v) => setState(() => _statusMap[id] = v ?? 'present'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : () async {
            setState(() => _saving = true);
            final nav = Navigator.of(context);
            try {
              for (final entry in _statusMap.entries) {
                final barber = widget.barbers.firstWhere(
                  (b) => (b as Map<String, dynamic>)['id'] == entry.key,
                ) as Map<String, dynamic>;
                await widget.onMark(entry.key, barber['name'] as String? ?? '', widget.date);
              }
              if (mounted) { nav.pop(); }
            } finally {
              if (mounted) { setState(() => _saving = false); }
            }
          },
          child: const Text('Save All'),
        ),
      ],
    );
  }
}
