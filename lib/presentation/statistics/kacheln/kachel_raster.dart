import 'package:flutter/material.dart';

import '../../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../widgets/app_page_header.dart';
import 'kachel_daten.dart';
import 'kachel_katalog.dart';
import 'kachel_raster_packer.dart';

/// Raster aus Kacheln mit festen Größen, dicht gepackt. Die Zeilenhöhe
/// wächst mit der Textskalierung; verschobene Kacheln gleiten an ihren
/// neuen Platz (nur die Position wird animiert, nie die Größe).
class KachelRaster extends StatelessWidget {
  const KachelRaster({
    super.key,
    required this.eintraege,
    required this.daten,
    this.kachelBauer,
  });

  final List<KachelEintrag> eintraege;
  final StatistikKachelDaten daten;

  /// Ersetzt die Kachel eines Eintrags, z. B. im Bearbeiten-Modus.
  final Widget Function(
    BuildContext context,
    KachelEintrag eintrag,
    Widget kachel,
  )?
  kachelBauer;

  @override
  Widget build(BuildContext context) {
    final bewegungAus = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrik = KachelRasterMetrik.aus(
          breite: constraints.maxWidth,
          textSkala: AppPageHeader.textScaleOf(context),
          maxTextSkala: AppPageHeader.maxTextScaleFactor,
        );
        final packung = packeKacheln([
          for (final e in eintraege) e.groesse,
        ], spalten: metrik.spalten);
        return SizedBox(
          height: metrik.hoehe(packung.zeilen),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < eintraege.length; i++)
                () {
                  final rect = metrik.rechteck(packung.plaetze[i]);
                  final kachel = RepaintBoundary(
                    child: KachelKatalog.kachel(context, daten, eintraege[i]),
                  );
                  return AnimatedPositioned(
                    key: ValueKey(eintraege[i].id),
                    duration: bewegungAus
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    left: rect.left,
                    top: rect.top,
                    // Die Größe springt sofort, damit der Inhalt nie in
                    // Zwischengrößen gelayoutet wird.
                    child: SizedBox.fromSize(
                      size: rect.size,
                      child:
                          kachelBauer?.call(context, eintraege[i], kachel) ??
                          kachel,
                    ),
                  );
                }(),
            ],
          ),
        );
      },
    );
  }
}
