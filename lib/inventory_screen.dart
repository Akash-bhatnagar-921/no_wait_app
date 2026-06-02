import 'package:flutter/material.dart';
import 'services/api_service.dart';

const _categories = ['shampoo', 'color', 'cream', 'tools', 'consumables', 'other'];
const _units = ['units', 'ml', 'liters', 'grams', 'kg', 'pcs'];

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ApiService.getInventory();
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<dynamic> get _filtered {
    if (_filterCategory == 'all') return _items;
    return _items.where((i) => (i as Map<String, dynamic>)['category'] == _filterCategory).toList();
  }

  List<dynamic> get _lowStock => _items.where((i) {
    final item = i as Map<String, dynamic>;
    final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
    final min = double.tryParse(item['minStock']?.toString() ?? '0') ?? 0;
    return min > 0 && qty <= min;
  }).toList();

  Future<void> _openItemDialog({Map<String, dynamic>? existing}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ItemDialog(existing: existing),
    );
    if (result == null) return;
    try {
      if (existing != null) {
        await ApiService.updateInventoryItem(existing['id'] as String, result);
      } else {
        await ApiService.addInventoryItem(result);
      }
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
        title: const Text('Delete item?'),
        content: const Text('This will permanently remove the inventory item.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService.deleteInventoryItem(id);
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

  Future<void> _adjustQty(Map<String, dynamic> item) async {
    final ctrl = TextEditingController(
      text: (double.tryParse(item['quantity']?.toString() ?? '0') ?? 0).toStringAsFixed(1),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update quantity — ${item['name']}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantity (${item['unit'] ?? 'units'})',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService.updateInventoryItem(item['id'] as String, {
          'quantity': double.tryParse(ctrl.text) ?? 0,
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
        title: const Text('Inventory'),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    if (_lowStock.isNotEmpty) _LowStockBanner(count: _lowStock.length),
                    _CategoryFilter(
                      selected: _filterCategory,
                      onChanged: (v) => setState(() => _filterCategory = v),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? _EmptyState(filterCategory: _filterCategory)
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) {
                                  final item = _filtered[i] as Map<String, dynamic>;
                                  return _InventoryCard(
                                    item: item,
                                    onEdit: () => _openItemDialog(existing: item),
                                    onDelete: () => _delete(item['id'] as String),
                                    onAdjustQty: () => _adjustQty(item),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  final int count;
  const _LowStockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            '$count item${count > 1 ? 's' : ''} running low on stock',
            style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;

  const _CategoryFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final chips = ['all', ..._categories];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, si) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final cat = chips[i];
          final active = selected == cat;
          return GestureDetector(
            onTap: () => onChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active ? primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? primary : Colors.grey.shade300),
              ),
              child: Text(
                cat == 'all' ? 'All' : cat[0].toUpperCase() + cat.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filterCategory;
  const _EmptyState({required this.filterCategory});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            filterCategory == 'all' ? 'No inventory items yet' : 'No items in this category',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text('Tap + to add products and track stock', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdjustQty;

  const _InventoryCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjustQty,
  });

  bool get _isLow {
    final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
    final min = double.tryParse(item['minStock']?.toString() ?? '0') ?? 0;
    return min > 0 && qty <= min;
  }

  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'shampoo': return Colors.blue;
      case 'color': return Colors.purple;
      case 'cream': return Colors.teal;
      case 'tools': return Colors.indigo;
      case 'consumables': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
    final min = double.tryParse(item['minStock']?.toString() ?? '0') ?? 0;
    final cost = double.tryParse(item['costPerUnit']?.toString() ?? '0');
    final cat = item['category'] as String?;
    final catColor = _categoryColor(cat);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.inventory_2_outlined, color: catColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      if (_isLow)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red.shade600),
                              const SizedBox(width: 2),
                              Text('Low', style: TextStyle(fontSize: 10, color: Colors.red.shade600, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (cat != null) ...[
                        Text(
                          cat[0].toUpperCase() + cat.substring(1),
                          style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (cost != null)
                        Text('₹${cost.toStringAsFixed(2)}/${item['unit'] ?? 'unit'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onAdjustQty,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isLow ? Colors.red.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${qty % 1 == 0 ? qty.toInt() : qty} ${item['unit'] ?? ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _isLow ? Colors.red.shade600 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                if (min > 0)
                  Text('min: ${ min % 1 == 0 ? min.toInt() : min}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'qty', child: Text('Update quantity')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) {
                if (v == 'edit') { onEdit(); }
                else if (v == 'qty') { onAdjustQty(); }
                else if (v == 'delete') { onDelete(); }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ItemDialog({this.existing});

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _notesCtrl;
  String? _category;
  String _unit = 'units';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name'] as String? ?? '');
    _qtyCtrl = TextEditingController(
      text: (double.tryParse(e?['quantity']?.toString() ?? '0') ?? 0).toString(),
    );
    _minCtrl = TextEditingController(
      text: (double.tryParse(e?['minStock']?.toString() ?? '0') ?? 0).toString(),
    );
    _costCtrl = TextEditingController(
      text: e?['costPerUnit'] != null ? (double.tryParse(e!['costPerUnit'].toString()) ?? '').toString() : '',
    );
    _notesCtrl = TextEditingController(text: e?['notes'] as String? ?? '');
    _category = e?['category'] as String?;
    _unit = e?['unit'] as String? ?? 'units';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Item' : 'Add Inventory Item'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Item name *', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select category')),
                  ..._categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c[0].toUpperCase() + c.substring(1)),
                  )),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _unit = v ?? 'units'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minCtrl,
                decoration: const InputDecoration(labelText: 'Minimum stock (alert threshold)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _costCtrl,
                decoration: const InputDecoration(labelText: 'Cost per unit (₹)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'name': _nameCtrl.text.trim(),
              if (_category != null) 'category': _category,
              'quantity': double.tryParse(_qtyCtrl.text) ?? 0,
              'unit': _unit,
              'minStock': double.tryParse(_minCtrl.text) ?? 0,
              if (_costCtrl.text.trim().isNotEmpty)
                'costPerUnit': double.tryParse(_costCtrl.text),
              if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
            });
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
