import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../../domain/statistiks/statistik_kachel_typen.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_page_header.dart';
import 'kachel_bearbeiten.dart';
import 'kachel_daten.dart';
import 'kachel_katalog.dart';
import 'kachel_raster_packer.dart';

/// Raster aus Kacheln mit festen Größen, dicht gepackt. Die Zeilenhöhe
/// wächst mit der Textskalierung; verschobene Kacheln gleiten an ihren
/// neuen Platz (nur die Position wird animiert, nie die Größe).
///
/// Mit [bearbeitung] wackeln die Kacheln leicht (nicht bei reduzierter
/// Bewegung), lassen sich nach langem Drücken ziehen, über den Eckgriff in
/// der Größe ändern und über das rote Minus entfernen. Alle Gesten gibt es
/// auch als Semantics-Aktionen.
class KachelRaster extends StatefulWidget {
  const KachelRaster({
    super.key,
    required this.eintraege,
    required this.daten,
    this.bearbeitung,
  });

  final List<KachelEintrag> eintraege;
  final StatistikKachelDaten daten;
  final KachelRasterBearbeitung? bearbeitung;

  /// Zieht der Finger erst nach dieser Zeit, wird sortiert statt gescrollt.
  static const Duration ziehenNach = Duration(milliseconds: 180);

  /// Rand, um den das Raster im Bearbeiten-Modus auf jeder Seite wächst.
  static const double bearbeitenRand = 16;

  @override
  State<KachelRaster> createState() => _KachelRasterState();
}

class _KachelRasterState extends State<KachelRaster>
    with SingleTickerProviderStateMixin {
  /// Zusätzlicher Rand je Kachel im Bearbeiten-Modus: Das Minus sitzt
  /// mittig auf der Ecke.
  static const double _rand = KachelEntfernenKnopf.ziel / 2;

  /// Im Bearbeiten-Modus wird das Raster um diesen Rand größer gezeichnet,
  /// damit Ziele an den Außenkacheln antippbar bleiben. Die Kacheln liegen
  /// an derselben Stelle wie in der Ansicht; der Aufrufer nimmt dafür
  /// seinen Innenabstand zurück.
  static const double _innen = KachelRaster.bearbeitenRand;

  final GlobalKey _rasterKey = GlobalKey();
  late final AnimationController _wackeln = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 0.5,
  );

  KachelRasterMetrik? _metrik;

  // Sortieren
  List<KachelEintrag>? _reihenfolge;
  String? _gezogenId;
  int _gezogenVon = 0;
  Offset _fingerGlobal = Offset.zero;
  Offset _griff = Offset.zero;
  EdgeDraggingAutoScroller? _autoScroller;

  // Größe
  String? _groesseId;
  KachelGroesse? _neueGroesse;

  bool get _bearbeiten => widget.bearbeitung != null;

  @override
  void didUpdateWidget(covariant KachelRaster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_bearbeiten || !_gleicheIds(oldWidget.eintraege, widget.eintraege)) {
      _ziehenAbbrechen();
      _groesseId = null;
      _neueGroesse = null;
    }
  }

  @override
  void dispose() {
    _autoScroller?.stopAutoScroll();
    _wackeln.dispose();
    super.dispose();
  }

  static bool _gleicheIds(List<KachelEintrag> a, List<KachelEintrag> b) =>
      a.length == b.length &&
      a.map((e) => e.id).toSet().containsAll(b.map((e) => e.id));

  bool _sollWackeln(bool bewegungAus) =>
      _bearbeiten && !bewegungAus && _gezogenId == null;

  void _wackelnAbgleichen(bool bewegungAus) {
    if (_sollWackeln(bewegungAus) == _wackeln.isAnimating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final an = _sollWackeln(
        MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      );
      if (an && !_wackeln.isAnimating) {
        _wackeln.repeat(reverse: true);
      } else if (!an && _wackeln.isAnimating) {
        _wackeln
          ..stop()
          ..value = 0.5;
      }
    });
  }

  Offset get _versatz =>
      _bearbeiten ? const Offset(_innen, _innen) : Offset.zero;

  /// Globale Position in Rasterkoordinaten (ohne Innenrand).
  Offset _imRaster(Offset global) {
    final box = _rasterKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global) - _versatz;
  }

  // ------------------------------------------------------------ Sortieren

  void _ziehenStarten(KachelEintrag eintrag, Offset global) {
    final metrik = _metrik;
    if (metrik == null) return;
    final index = widget.eintraege.indexWhere((e) => e.id == eintrag.id);
    if (index < 0) return;
    final packung = packeKacheln([
      for (final e in widget.eintraege) e.groesse,
    ], spalten: metrik.spalten);
    final rect = metrik.rechteck(packung.plaetze[index]);
    setState(() {
      _reihenfolge = [...widget.eintraege];
      _gezogenId = eintrag.id;
      _gezogenVon = index;
      _fingerGlobal = global;
      _griff = _imRaster(global) - rect.topLeft;
    });
    final scrollable = Scrollable.maybeOf(context);
    _autoScroller = scrollable == null
        ? null
        : EdgeDraggingAutoScroller(
            scrollable,
            onScrollViewScrolled: () => _ziehenBewegen(_fingerGlobal),
            velocityScalar: 30,
          );
  }

  void _ziehenBewegen(Offset global) {
    final metrik = _metrik;
    final reihenfolge = _reihenfolge;
    if (metrik == null || reihenfolge == null || !mounted) return;
    _fingerGlobal = global;
    final zeiger = _imRaster(global);
    final gezogen = reihenfolge.indexWhere((e) => e.id == _gezogenId);
    if (gezogen < 0) return;
    final ziel = besteZielPosition(
      groessen: [for (final e in reihenfolge) e.groesse],
      gezogen: gezogen,
      zeiger: zeiger,
      metrik: metrik,
    );
    setState(() {
      if (ziel != null) {
        reihenfolge.insert(ziel, reihenfolge.removeAt(gezogen));
      }
    });
    final groesse = metrik.groesse(reihenfolge[ziel ?? gezogen].groesse);
    final box = _rasterKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final oben = box.localToGlobal(zeiger - _griff + _versatz);
      _autoScroller?.startAutoScrollIfNecessary(oben & groesse);
    }
  }

  void _ziehenBeenden() {
    final reihenfolge = _reihenfolge;
    final id = _gezogenId;
    _ziehenAbbrechen();
    if (reihenfolge == null || id == null) return;
    final nach = reihenfolge.indexWhere((e) => e.id == id);
    if (nach >= 0 && nach != _gezogenVon) {
      widget.bearbeitung?.onVerschieben(_gezogenVon, nach);
    }
  }

  void _ziehenAbbrechen() {
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    if (_gezogenId == null && _reihenfolge == null) return;
    void zuruecksetzen() {
      _gezogenId = null;
      _reihenfolge = null;
    }

    if (mounted) {
      setState(zuruecksetzen);
    } else {
      zuruecksetzen();
    }
  }

  // ---------------------------------------------------------------- Größe

  Drag? _groesseStarten(KachelEintrag eintrag, Rect rect, Offset start) {
    setState(() {
      _groesseId = eintrag.id;
      _neueGroesse = eintrag.groesse;
    });
    return _GroessenZug(
      start: start,
      onUpdate: (global) => _groesseBewegen(eintrag, rect, global),
      onEnde: (abgebrochen) => _groesseBeenden(eintrag, abgebrochen),
    );
  }

  void _groesseBewegen(KachelEintrag eintrag, Rect rect, Offset global) {
    final metrik = _metrik;
    if (metrik == null || !mounted) return;
    final p = _imRaster(global) - rect.topLeft;
    const luecke = KachelRasterMetrik.luecke;
    final spalten = ((p.dx + luecke / 2) / (metrik.spaltenBreite + luecke))
        .ceil()
        .clamp(1, math.min(2, metrik.spalten))
        .toInt();
    final zeilen = ((p.dy + luecke / 2) / (metrik.zeilenHoehe + luecke))
        .ceil()
        .clamp(1, 2)
        .toInt();
    final neu = naechsteErlaubteGroesse(
      StatistikKachelTypen.groessenFuer(eintrag.typId),
      spalten,
      zeilen,
    );
    if (neu != _neueGroesse) setState(() => _neueGroesse = neu);
  }

  void _groesseBeenden(KachelEintrag eintrag, bool abgebrochen) {
    final neu = _neueGroesse;
    if (mounted) {
      setState(() {
        _groesseId = null;
        _neueGroesse = null;
      });
    }
    if (!abgebrochen && neu != null && neu != eintrag.groesse) {
      widget.bearbeitung?.onGroesse(eintrag, neu);
    }
  }

  // ---------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    final bewegungAus = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _wackelnAbgleichen(bewegungAus);
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrik = KachelRasterMetrik.aus(
          breite: constraints.maxWidth - 2 * _versatz.dx,
          textSkala: AppPageHeader.textScaleOf(context),
          maxTextSkala: AppPageHeader.maxTextScaleFactor,
        );
        _metrik = metrik;
        final eintraege = _reihenfolge ?? widget.eintraege;
        final packung = packeKacheln([
          for (final e in eintraege) e.groesse,
        ], spalten: metrik.spalten);
        final dauer = bewegungAus
            ? Duration.zero
            : const Duration(milliseconds: 200);
        Widget? schwebend;
        Widget? geist;
        final kinder = <Widget>[];
        for (var i = 0; i < eintraege.length; i++) {
          final eintrag = eintraege[i];
          final rect = metrik.rechteck(packung.plaetze[i]);
          final gezogen = eintrag.id == _gezogenId;
          final aussen = _bearbeiten
              ? rect.inflate(_rand).shift(_versatz)
              : rect;
          kinder.add(
            AnimatedPositioned(
              key: ValueKey(eintrag.id),
              duration: dauer,
              curve: Curves.easeOutCubic,
              left: aussen.left,
              top: aussen.top,
              // Die Größe springt sofort, damit der Inhalt nie in
              // Zwischengrößen gelayoutet wird.
              child: SizedBox.fromSize(
                size: aussen.size,
                child: _bearbeiten
                    ? _bearbeitbar(context, eintrag, i, rect, gezogen)
                    : RepaintBoundary(
                        child: KachelKatalog.kachel(
                          context,
                          widget.daten,
                          eintrag,
                        ),
                      ),
              ),
            ),
          );
          if (gezogen) {
            final oben = _imRaster(_fingerGlobal) - _griff + _versatz;
            schwebend = Positioned(
              left: oben.dx,
              top: oben.dy,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: 1.03,
                  child: Material(
                    type: MaterialType.transparency,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox.fromSize(
                      size: rect.size,
                      child: KachelKatalog.kachel(
                        context,
                        widget.daten,
                        eintrag,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final neueGroesse = _neueGroesse;
          if (eintrag.id == _groesseId && neueGroesse != null) {
            final groesse = metrik.groesse(neueGroesse);
            geist = (Positioned(
              left: rect.left + _versatz.dx,
              top: rect.top + _versatz.dy,
              width: groesse.width,
              height: groesse.height,
              child: KachelGroessenGeist(groesse: neueGroesse),
            ));
          }
        }
        return SizedBox(
          key: _rasterKey,
          height: metrik.hoehe(packung.zeilen) + 2 * _versatz.dy,
          child: Stack(
            clipBehavior: Clip.none,
            // Geist und gezogene Kachel liegen über allen anderen.
            children: [...kinder, ?geist, ?schwebend],
          ),
        );
      },
    );
  }

  Widget _bearbeitbar(
    BuildContext context,
    KachelEintrag eintrag,
    int index,
    Rect rect,
    bool gezogen,
  ) {
    final t = AppLocalizations.of(context);
    final bearbeitung = widget.bearbeitung!;
    final titel = KachelKatalog.titelFuer(t, widget.daten, eintrag);
    final erlaubt = StatistikKachelTypen.groessenFuer(eintrag.typId);
    final anzahl = widget.eintraege.length;
    final antippen = eintrag.typId == StatistikKachelTypen.eigene
        ? bearbeitung.onAntippen
        : null;
    final amplitude =
        (eintrag.groesse == KachelGroesse.klein ? 0.45 : 0.18) * math.pi / 180;
    final kachel = AnimatedBuilder(
      animation: _wackeln,
      builder: (context, child) => Transform.rotate(
        angle: (_wackeln.value * 2 - 1) * amplitude * (index.isEven ? 1 : -1),
        child: child,
      ),
      // Inhalt nimmt im Bearbeiten-Modus keine Gesten an (z. B. Karte).
      child: IgnorePointer(
        child: RepaintBoundary(
          child: KachelKatalog.kachel(context, widget.daten, eintrag),
        ),
      ),
    );
    return Semantics(
      container: true,
      label: titel,
      customSemanticsActions: {
        if (index > 0)
          CustomSemanticsAction(
            label: t.t('statistics_edit_move_earlier'),
          ): () =>
              bearbeitung.onVerschieben(index, index - 1),
        if (index < anzahl - 1)
          CustomSemanticsAction(label: t.t('statistics_edit_move_later')): () =>
              bearbeitung.onVerschieben(index, index + 1),
        for (final g in erlaubt)
          if (g != eintrag.groesse)
            CustomSemanticsAction(
              label: t.t('statistics_edit_size', {'size': groesseText(g)}),
            ): () =>
                bearbeitung.onGroesse(eintrag, g),
        CustomSemanticsAction(label: t.t('statistics_edit_remove')): () =>
            bearbeitung.onEntfernen(eintrag),
        if (antippen != null)
          CustomSemanticsAction(
            label: t.t('statistics_edit_custom', {'title': titel}),
          ): () =>
              antippen(eintrag),
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _rand,
            top: _rand,
            right: _rand,
            bottom: _rand,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                if (antippen != null)
                  TapGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        TapGestureRecognizer
                      >(
                        TapGestureRecognizer.new,
                        (r) => r.onTap = () => antippen(eintrag),
                      ),
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(
                        duration: KachelRaster.ziehenNach,
                      ),
                      (r) {
                        r.onLongPressStart = (d) =>
                            _ziehenStarten(eintrag, d.globalPosition);
                        r.onLongPressMoveUpdate = (d) =>
                            _ziehenBewegen(d.globalPosition);
                        r.onLongPressEnd = (_) => _ziehenBeenden();
                        r.onLongPressCancel = _ziehenAbbrechen;
                      },
                    ),
              },
              child: gezogen ? const KachelPlatzhalter() : kachel,
            ),
          ),
          if (!gezogen) ...[
            if (erlaubt.length > 1)
              Positioned(
                right: _rand,
                bottom: _rand,
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    ImmediateMultiDragGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          ImmediateMultiDragGestureRecognizer
                        >(
                          ImmediateMultiDragGestureRecognizer.new,
                          (r) =>
                              r.onStart = (start) =>
                                  _groesseStarten(eintrag, rect, start),
                        ),
                  },
                  child: const KachelGroessenGriff(),
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              child: KachelEntfernenKnopf(
                label: t.t('statistics_edit_remove_named', {'title': titel}),
                onPressed: () => bearbeitung.onEntfernen(eintrag),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Zug am Größengriff. Summiert die Deltas, weil das erste Update nach dem
/// Überschreiten der Schwelle noch die Startposition meldet.
class _GroessenZug extends Drag {
  _GroessenZug({
    required Offset start,
    required this.onUpdate,
    required this.onEnde,
  }) : _zeiger = start;

  final ValueChanged<Offset> onUpdate;
  final ValueChanged<bool> onEnde;
  Offset _zeiger;

  @override
  void update(DragUpdateDetails details) {
    _zeiger += details.delta;
    onUpdate(_zeiger);
  }

  @override
  void end(DragEndDetails details) => onEnde(false);

  @override
  void cancel() => onEnde(true);
}
