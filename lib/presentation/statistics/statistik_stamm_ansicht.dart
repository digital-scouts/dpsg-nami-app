import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/app_page_header.dart';
import 'kacheln/kachel_daten.dart';
import 'kacheln/kachel_raster.dart';

enum StatistikThema { ueberblick, stufen, entwicklung }

/// Inhalt des Stamm-Tabs: Themenleiste (Überblick, Stufen, Entwicklung) und
/// darunter das Kachelraster des gewählten Themas. Stufen und Entwicklung
/// sind fest zusammengestellt und lassen sich ausblenden; ohne sie entfällt
/// die Leiste.
class StatistikStammAnsicht extends StatefulWidget {
  const StatistikStammAnsicht({
    super.key,
    required this.daten,
    this.unterUeberblick,
    this.initialesThema = StatistikThema.ueberblick,
  });

  final StatistikKachelDaten daten;

  /// Thema beim ersten Aufbau; fällt auf den Überblick zurück, wenn es
  /// ausgeblendet ist.
  final StatistikThema initialesThema;

  /// Wird unter dem Überblick angezeigt, z. B. der Knopf „Bearbeiten“.
  final Widget? unterUeberblick;

  @override
  State<StatistikStammAnsicht> createState() => _StatistikStammAnsichtState();
}

class _StatistikStammAnsichtState extends State<StatistikStammAnsicht>
    with TickerProviderStateMixin {
  TabController? _controller;
  List<StatistikThema> _themen = const [];
  StatistikThema _aktiv = StatistikThema.ueberblick;

  List<StatistikThema> _sichtbareThemen() {
    final e = widget.daten.einstellungen;
    return [
      StatistikThema.ueberblick,
      if (e.stufenSichtbar) StatistikThema.stufen,
      if (e.entwicklungSichtbar) StatistikThema.entwicklung,
    ];
  }

  void _themenAbgleichen() {
    final themen = _sichtbareThemen();
    if (_controller != null && listEquals(themen, _themen)) return;
    if (!themen.contains(_aktiv)) _aktiv = StatistikThema.ueberblick;
    _controller?.dispose();
    _themen = themen;
    _controller = TabController(
      length: themen.length,
      initialIndex: themen.indexOf(_aktiv),
      vsync: this,
    )..addListener(_controllerGeaendert);
  }

  void _controllerGeaendert() {
    final controller = _controller;
    if (controller == null || controller.indexIsChanging) return;
    final thema = _themen[controller.index];
    if (thema != _aktiv) setState(() => _aktiv = thema);
  }

  @override
  void initState() {
    super.initState();
    _aktiv = widget.initialesThema;
    _themenAbgleichen();
  }

  @override
  void didUpdateWidget(covariant StatistikStammAnsicht oldWidget) {
    super.didUpdateWidget(oldWidget);
    _themenAbgleichen();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<KachelEintrag> _eintraege(StatistikThema thema) => switch (thema) {
    StatistikThema.ueberblick => widget.daten.einstellungen.ueberblick,
    StatistikThema.stufen => StatistikKachelEinstellungen.stufenTab,
    StatistikThema.entwicklung => StatistikKachelEinstellungen.entwicklungTab,
  };

  String _titel(AppLocalizations t, StatistikThema thema) => switch (thema) {
    StatistikThema.ueberblick => t.t('statistics_theme_overview'),
    StatistikThema.stufen => t.t('statistics_theme_stages'),
    StatistikThema.entwicklung => t.t('statistics_theme_development'),
  };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: AppPageHeader.maxTextScaleFactor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_themen.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: TabBar.secondary(
                controller: _controller,
                // Inhalt sofort wechseln, nicht erst nach der Indikator-Animation.
                onTap: (index) {
                  final thema = _themen[index];
                  if (thema != _aktiv) setState(() => _aktiv = thema);
                },
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelColor: scheme.onSurface,
                unselectedLabelColor: scheme.outlineVariant,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  for (final thema in _themen) Tab(text: _titel(t, thema)),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              key: PageStorageKey('statistik-thema-${_aktiv.name}'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                KachelRaster(
                  eintraege: _eintraege(_aktiv),
                  daten: widget.daten,
                ),
                if (_aktiv == StatistikThema.ueberblick &&
                    widget.unterUeberblick != null) ...[
                  const SizedBox(height: 20),
                  widget.unterUeberblick!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
