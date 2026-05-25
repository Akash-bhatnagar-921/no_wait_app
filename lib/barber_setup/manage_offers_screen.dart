import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';
import 'package:no_wait_app/widgets/loading_widget.dart';

class ManageOffersScreen extends StatefulWidget {
  const ManageOffersScreen({super.key});

  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getMyOffers();
      if (mounted) {
        setState(() {
          _offers  = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Add / Edit dialog ────────────────────────────────────────────────────────

  Future<void> _openDialog({Map<String, dynamic>? existing}) async {
    final primary     = Theme.of(context).colorScheme.primary;
    final titleCtrl   = TextEditingController(text: existing?['title'] as String? ?? '');
    final descCtrl    = TextEditingController(text: existing?['description'] as String? ?? '');
    final discCtrl    = TextEditingController(
        text: ((existing?['discountPercent'] as num?)?.toInt() ?? 0).toString());
    DateTime? validUntil = existing?['validUntil'] != null
        ? DateTime.tryParse(existing!['validUntil'] as String)
        : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existing == null ? 'Add Offer' : 'Edit Offer',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Title
              TextField(
                controller: titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Offer Title *',
                  hintText: 'e.g. 20% off on haircut',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              // Description
              TextField(
                controller: descCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Extra details about the offer',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              // Discount
              TextField(
                controller: discCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Discount % (0 = no discount)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 12),
              // Valid until
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: validUntil ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setInner(() => validUntil = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      validUntil == null
                          ? 'Valid until (optional)'
                          : 'Valid until: ${DateFormat('d MMM yyyy').format(validUntil!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: validUntil == null ? Colors.grey.shade500 : Colors.black87,
                      ),
                    ),
                    if (validUntil != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setInner(() => validUntil = null),
                        child: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
                      ),
                    ],
                  ]),
                ),
              ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final disc = int.tryParse(discCtrl.text) ?? 0;
                  final until = validUntil?.toIso8601String();
                  if (existing == null) {
                    await ApiService.createOffer(
                      title: title,
                      description: descCtrl.text.trim(),
                      discountPercent: disc.clamp(0, 100),
                      validUntil: until,
                    );
                    if (mounted) AppSnackbar.success(context, 'Offer created.');
                  } else {
                    await ApiService.updateOffer(
                      existing['id'] as String,
                      title: title,
                      description: descCtrl.text.trim(),
                      discountPercent: disc.clamp(0, 100),
                      validUntil: until,
                    );
                    if (mounted) AppSnackbar.success(context, 'Offer updated.');
                  }
                  _load();
                } on ApiException catch (e) {
                  if (mounted) AppSnackbar.error(context, e.message);
                }
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
    titleCtrl.dispose();
    descCtrl.dispose();
    discCtrl.dispose();
  }

  Future<void> _toggleActive(Map<String, dynamic> offer) async {
    final nowActive = offer['isActive'] as bool? ?? true;
    try {
      await ApiService.updateOffer(offer['id'] as String, isActive: !nowActive);
      _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Offer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Delete "${offer['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteOffer(offer['id'] as String);
      if (mounted) AppSnackbar.success(context, 'Offer deleted.');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers & Promotions',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Offer'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const AppLoadingIndicator(message: 'Loading offers…')
          : _offers.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.local_offer_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No offers yet',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Tap "+ Add Offer" to create your first promotion.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ]),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 40 : 16, vertical: 16),
                  itemCount: _offers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _offerCard(_offers[i], primary),
                ),
    );
  }

  Widget _offerCard(Map<String, dynamic> offer, Color primary) {
    final title       = offer['title'] as String? ?? '';
    final desc        = offer['description'] as String? ?? '';
    final disc        = (offer['discountPercent'] as num?)?.toInt() ?? 0;
    final isActive    = offer['isActive'] as bool? ?? true;
    final validUntil  = offer['validUntil'] != null
        ? DateTime.tryParse(offer['validUntil'] as String)
        : null;
    final expired     = validUntil != null && validUntil.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive && !expired
              ? primary.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Discount badge
          if (disc > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$disc% OFF',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primary)),
            ),
          if (disc > 0) const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          // Active toggle
          Switch(
            value: isActive,
            activeThumbColor: primary,
            activeTrackColor: primary.withValues(alpha: 0.4),
            onChanged: (_) => _toggleActive(offer),
          ),
        ]),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(desc,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 8),
        Row(children: [
          if (validUntil != null) ...[
            Icon(
              expired ? Icons.timer_off_outlined : Icons.access_time_outlined,
              size: 13,
              color: expired ? Colors.red.shade400 : Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              expired
                  ? 'Expired ${DateFormat('d MMM').format(validUntil)}'
                  : 'Valid till ${DateFormat('d MMM yyyy').format(validUntil)}',
              style: TextStyle(
                  fontSize: 11,
                  color: expired ? Colors.red.shade400 : Colors.grey.shade500),
            ),
          ],
          if (!isActive && !expired)
            Text('  ·  Paused',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade600)),
          const Spacer(),
          IconButton(
            onPressed: () => _openDialog(existing: offer),
            icon: Icon(Icons.edit_outlined, color: Colors.blue.shade400, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit',
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _delete(offer),
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Delete',
          ),
        ]),
      ]),
    );
  }
}
