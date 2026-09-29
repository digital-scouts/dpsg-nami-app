import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/presentation/theme/theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final light = la > lb ? la : lb;
  final dark = la > lb ? lb : la;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  test('Standardpalette entspricht den bisherigen DPSG-Farben', () {
    final light = buildTheme(AppPaletteId.standard, Brightness.light);
    final dark = buildTheme(AppPaletteId.standard, Brightness.dark);

    expect(light.colorScheme.primary, DPSGColors.primaryLight);
    expect(light.colorScheme.surface, DPSGColors.lightSurface);
    expect(light.colorScheme.onPrimaryContainer, DPSGColors.primaryLight);
    expect(light.scaffoldBackgroundColor, DPSGColors.lightBg);
    expect(dark.colorScheme.primary, DPSGColors.primaryDark);
    expect(dark.colorScheme.surfaceContainerHighest, DPSGColors.darkBorder);
    expect(dark.scaffoldBackgroundColor, DPSGColors.darkBg);
    expect(lightTheme.colorScheme, light.colorScheme);
    expect(darkTheme.colorScheme, dark.colorScheme);
  });

  test('alle Paletten sind lesbar (mindestens 4,5 : 1)', () {
    for (final id in AppPaletteId.values) {
      for (final brightness in Brightness.values) {
        final scheme = buildTheme(id, brightness).colorScheme;
        final reason = '${id.name} ${brightness.name}';
        expect(
          _contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: reason,
        );
        expect(
          _contrast(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: reason,
        );
        expect(
          _contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: reason,
        );
        expect(scheme.brightness, brightness, reason: reason);
      }
    }
  });
}
