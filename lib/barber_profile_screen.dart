import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/api_service.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/loading_widget.dart';
import 'widgets/star_rating.dart';

class BarberProfileScreen extends StatefulWidget {
  final String barberId;
  final String barberName;

  const BarberProfileScreen({
    super.key,
    required this.barberId,
    required this.barberName,
  });

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _hasError = false;
  bool _following = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final results = await Future.wait([
        ApiService.getBarberProfile(widget.barberId),
        ApiService.getFollowedBarbers(),
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      final followed = results[1] as List<dynamic>;
      if (mounted) {
        setState(() {
          _profile = profile;
          _following = followed.any((b) => b['id'] == widget.barberId);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    try {
      if (_following) {
        await ApiService.unfollowBarber(widget.barberId);
        if (mounted) {
          setState(() {
            _following = false;
            if (_profile != null) {
              _profile!['followersCount'] =
                  ((_profile!['followersCount'] as num?)?.toInt() ?? 1) - 1;
            }
          });
        }
      } else {
        await ApiService.followBarber(widget.barberId);
        if (mounted) {
          setState(() {
            _following = true;
            if (_profile != null) {
              _profile!['followersCount'] =
                  ((_profile!['followersCount'] as num?)?.toInt() ?? 0) + 1;
            }
          });
        }
      }
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _loading
          ? const AppLoadingIndicator(message: 'Loading profile…')
          : _hasError || _profile == null
              ? _buildError()
              : CustomScrollView(
                  slivers: [
                    _buildAppBar(primary),
                    SliverToBoxAdapter(
                      child: Column(children: [
                        _buildStatsBar(),
                        if ((_profile!['bio'] as String?)?.isNotEmpty == true)
                          _buildBioSection(),
                        _buildScheduleSection(primary),
                        _buildGallerySection(primary),
                        const SizedBox(height: 32),
                      ]),
                    ),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.person_off_outlined, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text('Could not load barber profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ]),
    );
  }

  Widget _buildAppBar(Color primary) {
    final name = _profile!['name'] as String? ?? widget.barberName;
    final spec = _profile!['specialization'] as String?;
    final photo = _profile!['photoUrl'] as String?;
    final rating = (_profile!['rating'] as num?)?.toDouble() ?? 0.0;
    final salonName = _profile!['salonName'] as String? ?? '';
    final city = _profile!['city'] as String? ?? '';
    final isAvailable = _profile!['isAvailable'] as bool? ?? true;
    final leaveUntil = _profile!['leaveUntil'] as String?;
    final breakUntil = _profile!['breakUntil'] as String?;

    String statusLabel = 'Available';
    Color statusColor = Colors.green.shade600;
    if (leaveUntil != null) {
      statusLabel = 'On Leave';
      statusColor = Colors.red.shade600;
    } else if (breakUntil != null) {
      statusLabel = 'On Break';
      statusColor = Colors.orange.shade600;
    } else if (!isAvailable) {
      statusLabel = 'Unavailable';
      statusColor = Colors.grey.shade600;
    }

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [primary.withValues(alpha: 0.85), Colors.white],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _barberAvatar(photo, name, primary, radius: 46),
                const SizedBox(height: 12),
                Text(name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                if (spec != null && spec.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(spec,
                        style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                ],
                const SizedBox(height: 6),
                if (salonName.isNotEmpty)
                  Text('$salonName${city.isNotEmpty ? ' · $city' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  StarRating(rating: rating, reviewCount: 0, compact: true,
                      starSize: 13),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11, color: statusColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _toggleFollow,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _following ? Colors.white : primary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _following ? primary : Colors.transparent),
              ),
              child: _followLoading
                  ? SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _following ? primary : Colors.white))
                  : Text(
                      _following ? 'Following' : 'Follow',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _following ? primary : Colors.white),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    final exp = (_profile!['experience'] as num?)?.toInt() ?? 0;
    final followers = (_profile!['followersCount'] as num?)?.toInt() ?? 0;
    final completed = (_profile!['completedBookings'] as num?)?.toInt() ?? 0;
    final rating = (_profile!['rating'] as num?)?.toDouble() ?? 0.0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('${exp}yr${exp == 1 ? '' : 's'}', 'Experience',
              Icons.workspace_premium_outlined),
          _divider(),
          _stat('$followers', 'Followers', Icons.people_outline),
          _divider(),
          _stat('$completed', 'Bookings', Icons.check_circle_outline),
          _divider(),
          _stat(rating.toStringAsFixed(1), 'Rating', Icons.star_outline),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon) {
    return Column(children: [
      Icon(icon, size: 20, color: Colors.grey.shade600),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      Text(label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]);
  }

  Widget _divider() => Container(
      height: 36, width: 1, color: Colors.grey.shade200);

  Widget _buildBioSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.format_quote, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          const Text('About', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Text(_profile!['bio'] as String,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade700, height: 1.5)),
      ]),
    );
  }

  Widget _buildScheduleSection(Color primary) {
    final openingTime = _profile!['openingTime'] as String?;
    final closingTime = _profile!['closingTime'] as String?;
    final rawDays = _profile!['workingDays'] as String? ?? '';
    final days = rawDays.isEmpty
        ? <String>[]
        : rawDays.split(',').map((d) => d.trim()).toList();
    final leaveUntil = _profile!['leaveUntil'] as String?;
    final breakUntil = _profile!['breakUntil'] as String?;

    final hasSchedule = openingTime != null || days.isNotEmpty;
    final hasStatusNote = leaveUntil != null || breakUntil != null;
    if (!hasSchedule && !hasStatusNote) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.schedule_outlined, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          const Text('Schedule', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        if (openingTime != null && closingTime != null)
          _scheduleRow(Icons.access_time, '$openingTime – $closingTime'),
        if (days.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: days.map((d) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(d, style: TextStyle(
                  fontSize: 11, color: primary, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
        if (leaveUntil != null) ...[
          const SizedBox(height: 10),
          _scheduleRow(Icons.event_busy_outlined,
              'On leave until ${_formatDate(leaveUntil)}',
              color: Colors.red.shade600),
        ],
        if (breakUntil != null) ...[
          const SizedBox(height: 10),
          _scheduleRow(Icons.pause_circle_outline,
              'On break until ${_formatDate(breakUntil)}',
              color: Colors.orange.shade600),
        ],
      ]),
    );
  }

  Widget _scheduleRow(IconData icon, String label, {Color? color}) {
    final c = color ?? Colors.grey.shade700;
    return Row(children: [
      Icon(icon, size: 16, color: c),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c))),
    ]);
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  Widget _buildGallerySection(Color primary) {
    final gallery = (_profile!['gallery'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (gallery.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.photo_library_outlined, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text('Portfolio (${gallery.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: gallery.length,
          itemBuilder: (context, i) {
            final item = gallery[i];
            final url = item['url'] as String? ?? '';
            return GestureDetector(
              onTap: () => _showPhotoViewer(context, url, item['caption'] as String?),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _networkImage(url),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _networkImage(String url) {
    if (url.isEmpty) return _imagePlaceholder();
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => _imagePlaceholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey.shade100,
          child: const Center(
            child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _imagePlaceholder() => Container(
    color: Colors.grey.shade100,
    child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 28),
  );

  Widget _barberAvatar(String? photo, String name, Color primary, {double radius = 36}) {
    if (photo != null && photo.isNotEmpty) {
      final fullUrl = photo.startsWith('http') ? photo : '${ApiService.baseUrl}$photo';
      return CircleAvatar(
        radius: radius,
        backgroundColor: primary.withValues(alpha: 0.2),
        backgroundImage: NetworkImage(fullUrl),
        onBackgroundImageError: (e, s) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.3),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      ),
    );
  }

  void _showPhotoViewer(BuildContext context, String url, String? caption) {
    if (url.isEmpty) return;
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Image.network(fullUrl, fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) =>
                      const Icon(Icons.broken_image, color: Colors.white, size: 48)),
            ),
          ),
          Positioned(
            top: 40, right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          if (caption != null && caption.isNotEmpty)
            Positioned(
              bottom: 40, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
        ]),
      ),
    );
  }
}
