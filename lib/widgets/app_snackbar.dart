import 'package:flutter/material.dart';
import '../theme/theme_manager.dart';

/// Themed snackbar that adapts to the active gender theme.
///
/// Context-based variants (use BEFORE any await):
///   AppSnackbar.success(context, 'Saved!');
///   AppSnackbar.error(context, 'Something went wrong.');
///
/// Messenger-based variants (safe AFTER await gaps):
///   AppSnackbar.successM(messenger, 'Done!');
///   AppSnackbar.errorM(messenger, 'Failed.');
class AppSnackbar {
  AppSnackbar._();

  // ── Context-based ─────────────────────────────────────────────────────────

  static void success(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      _show(context, message, _Type.success,
          actionLabel: actionLabel, onAction: onAction);

  static void error(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      _show(context, message, _Type.error,
          actionLabel: actionLabel, onAction: onAction);

  static void warning(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      _show(context, message, _Type.warning,
          actionLabel: actionLabel, onAction: onAction);

  static void info(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      _show(context, message, _Type.info,
          actionLabel: actionLabel, onAction: onAction);

  // ── Messenger-based (safe across async gaps) ───────────────────────────────

  static void successM(ScaffoldMessengerState m, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      _showM(m, message, _Type.success,
          actionLabel: actionLabel, onAction: onAction);

  static void errorM(ScaffoldMessengerState m, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      _showM(m, message, _Type.error,
          actionLabel: actionLabel, onAction: onAction);

  static void warningM(ScaffoldMessengerState m, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      _showM(m, message, _Type.warning,
          actionLabel: actionLabel, onAction: onAction);

  static void infoM(ScaffoldMessengerState m, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      _showM(m, message, _Type.info,
          actionLabel: actionLabel, onAction: onAction);

  // ── Internal ───────────────────────────────────────────────────────────────

  static void _show(BuildContext context, String message, _Type type,
      {String? actionLabel, VoidCallback? onAction}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          _build(message, type, isDark, actionLabel: actionLabel, onAction: onAction));
  }

  static void _showM(ScaffoldMessengerState m, String message, _Type type,
      {String? actionLabel, VoidCallback? onAction}) {
    final isDark = ThemeManager.instance.isDark;
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(
          _build(message, type, isDark, actionLabel: actionLabel, onAction: onAction));
  }

  static SnackBar _build(
    String message,
    _Type type,
    bool isDark, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final cfg = _cfg(type, isDark);

    return SnackBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 4),
      content: _SnackCard(
        cfg: cfg,
        message: message,
        isDark: isDark,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  static _Cfg _cfg(_Type type, bool isDark) {
    // All themes are currently light — isDark kept for future-proofing.
    switch (type) {
      case _Type.success:
        return _Cfg(
          color: const Color(0xFF3B8B5E),   // brand success green
          icon: Icons.check_circle_rounded,
          label: 'Success',
        );
      case _Type.error:
        return _Cfg(
          color: const Color(0xFFD32F2F),
          icon: Icons.error_rounded,
          label: 'Error',
        );
      case _Type.warning:
        return _Cfg(
          color: const Color(0xFFB8892D),   // brand warning amber
          icon: Icons.warning_rounded,
          label: 'Warning',
        );
      case _Type.info:
        return _Cfg(
          color: const Color(0xFF1565C0),
          icon: Icons.info_rounded,
          label: 'Info',
        );
    }
  }
}

enum _Type { success, error, warning, info }

class _Cfg {
  final Color color;
  final IconData icon;
  final String label;
  const _Cfg({required this.color, required this.icon, required this.label});
}

// ─── Card widget ───────────────────────────────────────────────────────────────

class _SnackCard extends StatelessWidget {
  final _Cfg cfg;
  final String message;
  final bool isDark;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SnackCard({
    required this.cfg,
    required this.message,
    required this.isDark,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF252525) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Coloured glow from the type accent
            BoxShadow(
              color: cfg.color.withValues(alpha: isDark ? 0.25 : 0.18),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            // Neutral depth shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          // Thin border on light theme for card definition
          border: isDark
              ? Border.all(
                  color: cfg.color.withValues(alpha: 0.25), width: 0.8)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Left accent bar ──────────────────────────────────────
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cfg.color,
                        cfg.color.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // ── Icon ─────────────────────────────────────────────────
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cfg.icon, color: cfg.color, size: 20),
                ),

                const SizedBox(width: 10),

                // ── Text ─────────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cfg.label.toUpperCase(),
                          style: TextStyle(
                            color: cfg.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          message,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Action ───────────────────────────────────────────────
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction ?? () {},
                    style: TextButton.styleFrom(
                      foregroundColor: cfg.color,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),

                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
