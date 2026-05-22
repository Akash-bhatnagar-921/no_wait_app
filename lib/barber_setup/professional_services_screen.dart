import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/loading_widget.dart';

class ProfessionalServicesScreen extends StatefulWidget {
  const ProfessionalServicesScreen({super.key});

  @override
  State<ProfessionalServicesScreen> createState() =>
      _ProfessionalServicesScreenState();
}

class _ProfessionalServicesScreenState
    extends State<ProfessionalServicesScreen> {
  // Loaded from API
  List<_ServiceRow> _services   = [];
  List<_AmenityRow> _amenities  = [];

  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final s in _services) {
      s.priceCtrl.dispose();
      s.durationCtrl.dispose();
    }
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final config = await ApiService.getMySalonConfig();
      if (!mounted) return;

      final svcs = config['services'] as List? ?? [];
      final amts = config['amenities'] as List? ?? [];

      setState(() {
        _services = svcs.map((s) => _ServiceRow(
          id:       s['id'] as String,
          name:     s['name'] as String,
          enabled:  s['enabled'] as bool? ?? false,
          price:    (s['price'] as num?)?.toDouble(),
          duration: (s['duration'] as num?)?.toInt(),
        )).toList();

        _amenities = amts.map((a) => _AmenityRow(
          id:      a['id'] as String,
          name:    a['name'] as String,
          enabled: a['enabled'] as bool? ?? false,
        )).toList();

        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.error(context, 'Failed to load salon config.');
      }
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Validate: every enabled service must have a price
    for (final s in _services.where((s) => s.enabled)) {
      final price = double.tryParse(s.priceCtrl.text.trim());
      if (price == null || price <= 0) {
        AppSnackbar.warning(
            context, '"${s.name}" is enabled — please enter a valid price.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final enabledServices = _services
          .where((s) => s.enabled)
          .map((s) => {
                // Only send serviceId if it looks like a real UUID (not custom_xxx)
                if (!s.id.startsWith('custom_')) 'serviceId': s.id,
                'serviceName': s.name,
                'price':    double.tryParse(s.priceCtrl.text.trim()) ?? 0,
                'duration': int.tryParse(s.durationCtrl.text.trim()),
              })
          .toList();

      final enabledAmenities = _amenities
          .where((a) => a.enabled)
          .map((a) => {
                if (!a.id.startsWith('custom_')) 'amenityId': a.id,
                'amenityName': a.name,
              })
          .toList();

      await ApiService.updateSalonServices(enabledServices);
      await ApiService.updateSalonAmenities(enabledAmenities);

      if (mounted) {
        AppSnackbar.success(context, 'Services & amenities saved!');
        Navigator.pop(context, true); // signal caller to refresh
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Save failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Add custom service ──────────────────────────────────────────────────────

  Future<void> _addCustomService() async {
    String name = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Custom Service'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Service name'),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (confirmed != true || name.trim().isEmpty) return;
    setState(() => _services.add(_ServiceRow(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: name.trim(),
          enabled: true,
        )));
  }

  Future<void> _addCustomAmenity() async {
    String name = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Custom Amenity'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Amenity name'),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (confirmed != true || name.trim().isEmpty) return;
    setState(() => _amenities.add(_AmenityRow(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: name.trim(),
          enabled: true,
        )));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services & Pricing'),
        centerTitle: true,
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading
          ? const AppLoadingIndicator(message: 'Loading salon config…')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info banner ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 16, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enable services and set a price for each. '
                          'Salons without priced services cannot accept bookings.',
                          style: TextStyle(
                              fontSize: 12, color: primary),
                        ),
                      ),
                    ]),
                  ),

                  // ── Services ────────────────────────────────────────────
                  _sectionHeader(primary, Icons.content_cut, 'Services'),
                  const SizedBox(height: 12),
                  ..._services.map((s) => _buildServiceRow(s, primary)),
                  const SizedBox(height: 8),

                  // Add custom service
                  OutlinedButton.icon(
                    onPressed: _addCustomService,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Custom Service'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary),
                      foregroundColor: primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Amenities ────────────────────────────────────────────
                  _sectionHeader(primary, Icons.spa_outlined, 'Amenities'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        _amenities.map((a) => _buildAmenityChip(a, primary)).toList(),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _addCustomAmenity,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Custom Amenity'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary),
                      foregroundColor: primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ── Save button (bottom) ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(Color primary, IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(width: 8),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  letterSpacing: 0.5)),
        ],
      );

  // ── Service row ─────────────────────────────────────────────────────────────

  Widget _buildServiceRow(_ServiceRow s, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: s.enabled
            ? primary.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: s.enabled ? primary.withValues(alpha: 0.3) : Colors.grey.shade200,
        ),
      ),
      child: Column(children: [
        // Service name + toggle
        Row(children: [
          Expanded(
            child: Text(s.name,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: s.enabled ? Colors.black87 : Colors.grey)),
          ),
          Switch(
            value: s.enabled,
            onChanged: (v) => setState(() => s.enabled = v),
            activeThumbColor: primary,
          ),
        ]),
        if (s.enabled) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              flex: 2,
              child: _numField(
                controller: s.priceCtrl,
                hint: 'Price (₹)',
                prefix: '₹',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _numField(
                controller: s.durationCtrl,
                hint: 'Duration (min)',
                suffix: 'min',
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  // ── Amenity chip ────────────────────────────────────────────────────────────

  Widget _buildAmenityChip(_AmenityRow a, Color primary) {
    return GestureDetector(
      onTap: () => setState(() => a.enabled = !a.enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: a.enabled ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: a.enabled ? primary : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            a.enabled ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 15,
            color: a.enabled ? Colors.white : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(a.name,
              style: TextStyle(
                  color: a.enabled ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String hint,
    String? prefix,
    String? suffix,
  }) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          suffixText: suffix,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
      );
}

// ── Row models ────────────────────────────────────────────────────────────────

class _ServiceRow {
  final String id;
  final String name;
  bool enabled;
  final TextEditingController priceCtrl;
  final TextEditingController durationCtrl;

  _ServiceRow({
    required this.id,
    required this.name,
    this.enabled = false,
    double? price,
    int? duration,
  })  : priceCtrl =
            TextEditingController(text: price != null ? '$price' : ''),
        durationCtrl = TextEditingController(
            text: duration != null ? '$duration' : '');
}

class _AmenityRow {
  final String id;
  final String name;
  bool enabled;
  _AmenityRow({required this.id, required this.name, this.enabled = false});
}
