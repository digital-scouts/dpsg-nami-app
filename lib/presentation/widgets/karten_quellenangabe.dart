import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/maps_env.dart';

/// Quellenangabe der Kartenkacheln unten links. OpenStreetMap und MapTiler
/// verlangen sie sichtbar auf jeder Karte, nicht hinter einem Schalter.
class KartenQuellenangabe extends StatelessWidget {
  const KartenQuellenangabe({super.key, this.text});

  /// Nur fuer Tests und Storybook; sonst aus der Kachel-Konfiguration.
  final String? text;

  static const String _osm = '© OpenStreetMap-Mitwirkende';
  static final Uri _osmCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  /// MapTiler-Kacheln brauchen beide Nennungen, der OSM-Rueckfall nur OSM.
  static String fuerKonfiguration() {
    final mitMapTiler =
        !MapsEnv.isUsingTileFallback &&
        MapsEnv.mapTileUrlTemplate.contains('maptiler.com');
    return mitMapTiler ? '© MapTiler $_osm' : _osm;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: colors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            key: const Key('karten-quellenangabe'),
            borderRadius: BorderRadius.circular(6),
            onTap: () =>
                launchUrl(_osmCopyright, mode: LaunchMode.externalApplication),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                text ?? fuerKonfiguration(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
