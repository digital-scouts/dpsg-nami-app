import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/map_tile_cache_service.dart';
import '../../services/network_access_policy.dart';

/// Hinweis, dass „Mobile Daten einschränken“ einen Ladevorgang zurueckhaelt,
/// mit einem Knopf, der ihn nach Bestaetigung ueber mobile Daten startet.
class MobileDatenHinweis extends StatelessWidget {
  const MobileDatenHinweis({
    super.key,
    required this.icon,
    required this.titel,
    required this.text,
    required this.knopf,
    required this.onLaden,
    this.kompakt = false,
  });

  final IconData icon;
  final String titel;
  final String text;
  final String knopf;
  final VoidCallback onLaden;

  /// Eine Zeile fuer kleine Karten; der Text entfaellt.
  final bool kompakt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final symbol = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: scheme.onPrimaryContainer),
    );
    if (kompakt) {
      return Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          child: Row(
            children: [
              symbol,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onLaden,
                child: Text(
                  AppLocalizations.of(context).t('mobile_daten_laden_kurz'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            symbol,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: onLaden, child: Text(knopf)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liefert die Kartenkacheln einer Karte. Bei „Mobile Daten einschränken“
/// ohne WLAN kommen sie nur aus dem Kachel-Cache, und auf der Karte liegt
/// ein [MobileDatenHinweis]. Nach „Laden“ gilt die Freigabe, bis die Karte
/// verschwindet.
class KartenKacheln extends StatefulWidget {
  const KartenKacheln({
    super.key,
    required this.trigger,
    required this.builder,
    this.maxZoom = 19,
    this.tileCacheService,
    this.networkAccessPolicy,
  });

  final String trigger;
  final double maxZoom;

  /// Baut die Karte; [kacheln] ist ihr Tile-Layer.
  final Widget Function(BuildContext context, Widget kacheln) builder;

  final MapTileCacheService? tileCacheService;
  final NetworkAccessPolicy? networkAccessPolicy;

  @override
  State<KartenKacheln> createState() => _KartenKachelnState();
}

class _KartenKachelnState extends State<KartenKacheln> {
  /// `null`, solange die Quelle noch bestimmt wird.
  Widget? _kacheln;
  bool _nurSpeicher = false;
  bool _freigegeben = false;
  int _lauf = 0;

  @override
  void initState() {
    super.initState();
    _bestimmeQuelle();
  }

  T? _lies<T>() {
    try {
      return Provider.of<T>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _bestimmeQuelle() async {
    final lauf = ++_lauf;
    final policy = widget.networkAccessPolicy ?? _lies<NetworkAccessPolicy>();
    final cache = widget.tileCacheService ?? _lies<MapTileCacheService>();
    final decision = await policy?.evaluateAccess(
      trigger: widget.trigger,
      feature: 'Karte',
      allowMobileDataOverride: _freigegeben,
    );
    final netzErlaubt = decision?.allowed ?? true;
    Widget kacheln;
    if (netzErlaubt) {
      // Wie bisher direkt aus dem Netz; ob diese Karten den Kachel-Cache
      // fuellen, entscheidet #196.
      kacheln = _netzLayer();
    } else if (cache == null) {
      kacheln = const SizedBox.shrink();
    } else {
      try {
        kacheln = TileLayer(
          key: const ValueKey('kacheln-speicher'),
          urlTemplate: MapTileCacheService.tileUrlTemplate,
          userAgentPackageName: MapTileCacheService.userAgentPackageName,
          tileProvider: await cache.tileProvider(allowNetwork: false),
          maxZoom: widget.maxZoom,
        );
      } catch (_) {
        kacheln = const SizedBox.shrink();
      }
    }
    if (!mounted || lauf != _lauf) {
      return;
    }
    setState(() {
      _kacheln = kacheln;
      _nurSpeicher = decision?.isBlockedByNoMobileData ?? false;
    });
  }

  Widget _netzLayer() => TileLayer(
    key: const ValueKey('kacheln-netz'),
    urlTemplate: MapTileCacheService.tileUrlTemplate,
    userAgentPackageName: MapTileCacheService.userAgentPackageName,
    maxZoom: widget.maxZoom,
  );

  void _laden() {
    setState(() => _freigegeben = true);
    _bestimmeQuelle();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final karte = widget.builder(context, _kacheln ?? const SizedBox.shrink());
    if (!_nurSpeicher) {
      return karte;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final kompakt = constraints.maxHeight < 320;
        return Stack(
          children: [
            Positioned.fill(child: karte),
            // Klein oben, damit Knoepfe am unteren Rand frei bleiben.
            Positioned(
              left: kompakt ? 8 : 12,
              right: kompakt ? 8 : 12,
              top: kompakt ? 8 : null,
              bottom: kompakt ? null : 12,
              child: SafeArea(
                top: false,
                child: MobileDatenHinweis(
                  key: const Key('mobile-daten-karte-hinweis'),
                  icon: Icons.signal_cellular_alt,
                  titel: t.t('mobile_daten_karte_titel'),
                  text: t.t('mobile_daten_karte_text'),
                  knopf: t.t('mobile_daten_laden'),
                  kompakt: kompakt,
                  onLaden: _laden,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
