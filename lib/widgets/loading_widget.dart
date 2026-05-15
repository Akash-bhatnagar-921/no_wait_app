import 'package:flutter/material.dart';

/// Full-screen dialog loader — use inside showDialog().
///
/// Example:
///   showDialog(context: context, barrierDismissible: false,
///     builder: (_) => const LoadingWidget());
///   ...later: Navigator.of(context, rootNavigator: true).pop();
class LoadingWidget extends StatefulWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: -22, end: 22).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated scissors + brush
            AnimatedBuilder(
              animation: _anim,
              builder: (ctx, child) {
                final primary = Theme.of(ctx).colorScheme.primary;
                return SizedBox(
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(_anim.value, 0),
                        child: Icon(Icons.content_cut,
                            size: 36, color: primary),
                      ),
                      Transform.translate(
                        offset: Offset(-_anim.value, 0),
                        child: Icon(Icons.brush,
                            size: 36, color: primary),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            Text(
              widget.message ?? 'Please wait…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Inline page loader ───────────────────────────────────────────────────────

/// Inline loader for page bodies (replaces raw CircularProgressIndicator).
///
/// Example:
///   body: isLoading
///       ? const AppLoadingIndicator(message: 'Loading profile…')
///       : _buildContent(),
class AppLoadingIndicator extends StatefulWidget {
  final String? message;
  const AppLoadingIndicator({super.key, this.message});

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: -16, end: 16).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (ctx, child) {
              final primary = Theme.of(ctx).colorScheme.primary;
              return SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(_anim.value, 0),
                      child: Icon(Icons.content_cut,
                          size: 30, color: primary),
                    ),
                    Transform.translate(
                      offset: Offset(-_anim.value, 0),
                      child: Icon(Icons.brush,
                          size: 30, color: primary),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 14),
            Text(
              widget.message!,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
