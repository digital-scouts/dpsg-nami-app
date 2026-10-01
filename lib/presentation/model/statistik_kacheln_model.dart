import 'package:flutter/foundation.dart';

import '../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../domain/statistiks/statistik_kachel_typen.dart';
import '../statistics/statistik_stamm_ansicht.dart';

/// Kachel-Belegung des Statistik-Überblicks je Stamm (Layer).
///
/// Jede Änderung wird sofort gespeichert; „Bearbeiten“ ist nur ein
/// Anzeigemodus. Eigene Kacheln ohne Eintrag bleiben bis zum Ende des
/// Bearbeitens erhalten, damit „Rückgängig“ sie wiederherstellen kann.
class StatistikKachelnModel extends ChangeNotifier {
  StatistikKachelnModel(this._repository, {String Function()? neueId})
    : _neueId = neueId ?? _zeitId;

  final StatistikKachelRepository _repository;
  final String Function() _neueId;

  int? _layerId;
  bool _entsorgt = false;
  bool _isLoading = false;
  bool _bearbeiten = false;
  StatistikKachelEinstellungen _einstellungen =
      const StatistikKachelEinstellungen();

  int? get layerId => _layerId;
  bool get isLoading => _isLoading;
  bool get bearbeiten => _bearbeiten;
  StatistikKachelEinstellungen get einstellungen => _einstellungen;

  @override
  void dispose() {
    _entsorgt = true;
    super.dispose();
  }

  /// Späte Aufrufe, z. B. „Bearbeiten beenden“ nach dem Abbau einer Seite,
  /// laufen ins Leere statt zu werfen.
  @override
  void notifyListeners() {
    if (!_entsorgt) super.notifyListeners();
  }

  static int _zaehler = 0;
  static String _zeitId() =>
      'k${DateTime.now().microsecondsSinceEpoch}-${_zaehler++}';

  /// Lädt die Belegung eines Stamms; ein Wechsel beendet das Bearbeiten.
  ///
  /// Mit [teilsicht] (nur einzelne Gruppen lesbar) gilt eine eigene
  /// Standardbelegung, solange nichts gespeichert ist.
  Future<void> ensureLoadedForLayer(
    int? layerId, {
    bool teilsicht = false,
  }) async {
    _teilsicht = teilsicht;
    if (layerId == null || _layerId == layerId) {
      _standardFuerTeilsichtAnwenden();
      return;
    }
    _layerId = layerId;
    _bearbeiten = false;
    _isLoading = true;
    _einstellungen = const StatistikKachelEinstellungen();
    notifyListeners();
    StatistikKachelEinstellungen geladen;
    try {
      geladen = await _repository.loadForLayer(layerId);
    } catch (_) {
      geladen = const StatistikKachelEinstellungen();
    }
    // Inzwischen auf einen anderen Stamm gewechselt.
    if (_layerId != layerId) return;
    _einstellungen = geladen;
    _isLoading = false;
    _standardFuerTeilsichtAnwenden(benachrichtigen: false);
    notifyListeners();
  }

  bool _teilsicht = false;

  /// Bei Teilsicht ohne gespeicherte Belegung die passende Standardbelegung.
  void _standardFuerTeilsichtAnwenden({bool benachrichtigen = true}) {
    if (!_teilsicht || !_einstellungen.hatStandardUeberblick) return;
    _einstellungen = _einstellungen.copyWith(
      ueberblick: StatistikKachelEinstellungen.standardUeberblickTeilsicht,
    );
    if (benachrichtigen) notifyListeners();
  }

  /// Stellt die Standardbelegung des Überblicks wieder her. Eigene Kacheln
  /// bleiben am Ende erhalten, Zielwerte bleiben unverändert.
  void zuruecksetzen() {
    final standard = _teilsicht
        ? StatistikKachelEinstellungen.standardUeberblickTeilsicht
        : StatistikKachelEinstellungen.standardUeberblick;
    final eigene = [
      for (final k in _einstellungen.eigeneKacheln)
        KachelEintrag(
          id: _neueId(),
          typId: StatistikKachelTypen.eigene,
          groesse: KachelGroesse.klein,
          eigeneKachelId: k.id,
        ),
    ];
    _aendern(
      _einstellungen.copyWith(
        ueberblick: List.unmodifiable([...standard, ...eigene]),
        stufenSichtbar: true,
        entwicklungSichtbar: true,
      ),
    );
  }

  void bearbeitenStarten() {
    if (_bearbeiten || _layerId == null) return;
    _bearbeiten = true;
    notifyListeners();
  }

  /// Beendet das Bearbeiten und räumt eigene Kacheln ohne Eintrag auf.
  void bearbeitenBeenden() {
    if (!_bearbeiten) return;
    _bearbeiten = false;
    final benutzt = {
      for (final e in _einstellungen.ueberblick)
        if (e.eigeneKachelId != null) e.eigeneKachelId,
    };
    final eigene = _einstellungen.eigeneKacheln
        .where((k) => benutzt.contains(k.id))
        .toList(growable: false);
    if (eigene.length != _einstellungen.eigeneKacheln.length) {
      _aendern(_einstellungen.copyWith(eigeneKacheln: eigene));
    } else {
      notifyListeners();
    }
  }

  /// Verschiebt den Eintrag an [von] auf die Position [nach].
  void verschieben(int von, int nach) {
    final liste = [..._einstellungen.ueberblick];
    if (von < 0 || von >= liste.length) return;
    final ziel = nach.clamp(0, liste.length - 1);
    if (ziel == von) return;
    liste.insert(ziel, liste.removeAt(von));
    _ueberblickSetzen(liste);
  }

  /// Setzt die Größe, wenn sie für den Kacheltyp erlaubt ist.
  void groesseSetzen(String id, KachelGroesse groesse) {
    final liste = [
      for (final e in _einstellungen.ueberblick)
        e.id == id &&
                e.groesse != groesse &&
                StatistikKachelTypen.groessenFuer(e.typId).contains(groesse)
            ? e.copyWith(groesse: groesse)
            : e,
    ];
    if (listEquals(liste, _einstellungen.ueberblick)) return;
    _ueberblickSetzen(liste);
  }

  /// Entfernt einen Eintrag und liefert ihn samt Position für
  /// [wiederherstellen].
  (KachelEintrag, int)? entfernen(String id) {
    final liste = [..._einstellungen.ueberblick];
    final index = liste.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final eintrag = liste.removeAt(index);
    _ueberblickSetzen(liste);
    return (eintrag, index);
  }

  void wiederherstellen(KachelEintrag eintrag, int index) {
    if (_einstellungen.ueberblick.any((e) => e.id == eintrag.id)) return;
    if (eintrag.typId == StatistikKachelTypen.eigene &&
        _einstellungen.eigeneKachel(eintrag.eigeneKachelId) == null) {
      return;
    }
    final liste = [..._einstellungen.ueberblick];
    liste.insert(index.clamp(0, liste.length), eintrag);
    _ueberblickSetzen(liste);
  }

  /// Hängt eine Katalog-Kachel an; die Größe rastet auf eine erlaubte ein.
  KachelEintrag? hinzufuegen(String typId, KachelGroesse groesse) {
    if (typId == StatistikKachelTypen.eigene ||
        !StatistikKachelTypen.istBekannt(typId)) {
      return null;
    }
    final eintrag = KachelEintrag(
      id: _neueId(),
      typId: typId,
      groesse: _erlaubt(typId, groesse),
    );
    _ueberblickSetzen([..._einstellungen.ueberblick, eintrag]);
    return eintrag;
  }

  /// Speichert eine eigene Kachel. Neue Kacheln werden angehängt,
  /// bestehende in allen Einträgen aktualisiert.
  void eigeneKachelSpeichern(
    EigeneKachel kachel, {
    KachelGroesse groesse = KachelGroesse.klein,
  }) {
    final vorhanden = _einstellungen.eigeneKachel(kachel.id) != null;
    final eigene = vorhanden
        ? [
            for (final k in _einstellungen.eigeneKacheln)
              k.id == kachel.id ? kachel : k,
          ]
        : [..._einstellungen.eigeneKacheln, kachel];
    final ueberblick = vorhanden
        ? _einstellungen.ueberblick
        : [
            ..._einstellungen.ueberblick,
            KachelEintrag(
              id: _neueId(),
              typId: StatistikKachelTypen.eigene,
              groesse: _erlaubt(StatistikKachelTypen.eigene, groesse),
              eigeneKachelId: kachel.id,
            ),
          ];
    _aendern(
      _einstellungen.copyWith(
        eigeneKacheln: List.unmodifiable(eigene),
        ueberblick: List.unmodifiable(ueberblick),
      ),
    );
  }

  void themaSichtbar(StatistikThema thema, bool sichtbar) {
    switch (thema) {
      case StatistikThema.ueberblick:
        return;
      case StatistikThema.stufen:
        if (_einstellungen.stufenSichtbar == sichtbar) return;
        _aendern(_einstellungen.copyWith(stufenSichtbar: sichtbar));
      case StatistikThema.entwicklung:
        if (_einstellungen.entwicklungSichtbar == sichtbar) return;
        _aendern(_einstellungen.copyWith(entwicklungSichtbar: sichtbar));
    }
  }

  void zieleSpeichern(StatistikZielwerte ziele) {
    if (ziele == _einstellungen.ziele) return;
    _aendern(_einstellungen.copyWith(ziele: ziele));
  }

  /// Neue, eindeutige ID, z. B. für eine eigene Kachel.
  String neueId() => _neueId();

  static KachelGroesse _erlaubt(String typId, KachelGroesse groesse) {
    final erlaubt = StatistikKachelTypen.groessenFuer(typId);
    return erlaubt.contains(groesse)
        ? groesse
        : naechsteErlaubteGroesse(erlaubt, groesse.spalten, groesse.zeilen);
  }

  void _ueberblickSetzen(List<KachelEintrag> liste) =>
      _aendern(_einstellungen.copyWith(ueberblick: List.unmodifiable(liste)));

  void _aendern(StatistikKachelEinstellungen neu) {
    final layerId = _layerId;
    if (layerId == null) return;
    _einstellungen = neu;
    notifyListeners();
    _repository.saveForLayer(layerId, neu).catchError((_) {});
  }
}
