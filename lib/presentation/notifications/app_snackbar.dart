import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum AppSnackbarType { success, warning, error, info, help }

class AppSnackbar {
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    BuildContext context, {
    required String message,
    required AppSnackbarType type,
    String? title,
    Duration? duration,
    bool replaceCurrent = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return null;
    }
    return showOnMessenger(
      messenger: messenger,
      context: context,
      message: message,
      type: type,
      title: title,
      duration: duration,
      replaceCurrent: replaceCurrent,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  showOnMessenger({
    required ScaffoldMessengerState? messenger,
    required BuildContext context,
    required String message,
    required AppSnackbarType type,
    String? title,
    Duration? duration,
    bool replaceCurrent = false,
  }) {
    if (messenger == null) {
      return null;
    }
    if (replaceCurrent) {
      messenger.hideCurrentSnackBar();
    }
    return messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: duration ?? const Duration(seconds: 4),
        content: AppSnackbarContent(
          title: title ?? _defaultTitle(AppLocalizations.of(context), type),
          message: message,
          type: type,
        ),
      ),
    );
  }

  static void hideCurrent(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }

  static String _defaultTitle(AppLocalizations t, AppSnackbarType type) {
    return switch (type) {
      AppSnackbarType.success => t.t('snackbar_success_title'),
      AppSnackbarType.warning => t.t('snackbar_warning_title'),
      AppSnackbarType.error => t.t('snackbar_error_title'),
      AppSnackbarType.info => t.t('snackbar_info_title'),
      AppSnackbarType.help => t.t('snackbar_help_title'),
    };
  }
}

class AppSnackbarContent extends StatelessWidget {
  const AppSnackbarContent({
    super.key,
    required this.title,
    required this.message,
    required this.type,
  });

  final String title;
  final String message;
  final AppSnackbarType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _AppSnackbarPalette.of(type);
    final closeTooltip = MaterialLocalizations.of(context).closeButtonTooltip;

    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        color: palette.backgroundColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -12,
            left: 18,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: palette.shadowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(palette.icon, color: Colors.white, size: 24),
            ),
          ),
          Positioned(
            top: 18,
            right: -18,
            child: _SnackbarAccentCircle(
              size: 76,
              color: palette.accentColor.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -12,
            child: _SnackbarAccentCircle(
              size: 68,
              color: palette.accentColor.withValues(alpha: 0.14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(74, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.96),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: closeTooltip,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnackbarAccentCircle extends StatelessWidget {
  const _SnackbarAccentCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _AppSnackbarPalette {
  const _AppSnackbarPalette({
    required this.backgroundColor,
    required this.accentColor,
    required this.shadowColor,
    required this.icon,
  });

  final Color backgroundColor;
  final Color accentColor;
  final Color shadowColor;
  final IconData icon;

  static _AppSnackbarPalette of(AppSnackbarType type) {
    return switch (type) {
      AppSnackbarType.success => const _AppSnackbarPalette(
        backgroundColor: Color(0xFF1F8A4C),
        accentColor: Color(0xFF166534),
        shadowColor: Color(0x33166534),
        icon: Icons.check_circle_rounded,
      ),
      AppSnackbarType.warning => const _AppSnackbarPalette(
        backgroundColor: Color(0xFFC67C00),
        accentColor: Color(0xFF9A6700),
        shadowColor: Color(0x339A6700),
        icon: Icons.warning_amber_rounded,
      ),
      AppSnackbarType.error => const _AppSnackbarPalette(
        backgroundColor: Color(0xFFC53030),
        accentColor: Color(0xFF9B2C2C),
        shadowColor: Color(0x339B2C2C),
        icon: Icons.error_rounded,
      ),
      AppSnackbarType.info => const _AppSnackbarPalette(
        backgroundColor: Color(0xFF2563EB),
        accentColor: Color(0xFF1D4ED8),
        shadowColor: Color(0x331D4ED8),
        icon: Icons.info_rounded,
      ),
      AppSnackbarType.help => const _AppSnackbarPalette(
        backgroundColor: Color(0xFF0F766E),
        accentColor: Color(0xFF115E59),
        shadowColor: Color(0x33115E59),
        icon: Icons.help_rounded,
      ),
    };
  }
}
