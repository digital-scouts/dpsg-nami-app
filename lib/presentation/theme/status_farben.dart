import 'package:flutter/material.dart';

/// Statusfarben fuer gueltig, bald ablaufend und abgelaufen bzw. kritisch.
/// Bewusst getrennt von den Stufenfarben (Woelflings-Orange ist keine
/// Warnung).
@immutable
class StatusFarben extends ThemeExtension<StatusFarben> {
  const StatusFarben({
    required this.gut,
    required this.warnung,
    required this.kritisch,
  });

  static const Color warnungHell = Color(0xFFB35C00);
  static const Color warnungDunkel = Color(0xFFFF9F2E);

  final Color gut;
  final Color warnung;
  final Color kritisch;

  static StatusFarben of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<StatusFarben>() ??
        StatusFarben(
          gut: theme.brightness == Brightness.dark
              ? const Color(0xFF22C65A)
              : const Color(0xFF00823C),
          warnung: theme.brightness == Brightness.dark
              ? warnungDunkel
              : warnungHell,
          kritisch: theme.colorScheme.error,
        );
  }

  @override
  StatusFarben copyWith({Color? gut, Color? warnung, Color? kritisch}) {
    return StatusFarben(
      gut: gut ?? this.gut,
      warnung: warnung ?? this.warnung,
      kritisch: kritisch ?? this.kritisch,
    );
  }

  @override
  StatusFarben lerp(ThemeExtension<StatusFarben>? other, double t) {
    if (other is! StatusFarben) {
      return this;
    }
    return StatusFarben(
      gut: Color.lerp(gut, other.gut, t)!,
      warnung: Color.lerp(warnung, other.warnung, t)!,
      kritisch: Color.lerp(kritisch, other.kritisch, t)!,
    );
  }
}
