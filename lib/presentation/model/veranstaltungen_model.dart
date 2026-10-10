import 'package:flutter/foundation.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/auth/auth_session.dart';
import '../../domain/veranstaltung/bestimme_suchgruppen_usecase.dart';
import '../../domain/veranstaltung/filtere_veranstaltungen_usecase.dart';
import '../../domain/veranstaltung/veranstaltung.dart';
import '../../domain/veranstaltung/veranstaltungs_filter.dart';
import '../../services/hitobito_api_exception.dart';
import '../../services/hitobito_events_service.dart';
import '../../services/network_access_policy.dart';

typedef VeranstaltungenRemoteAccessExecutor =
    Future<T?> Function<T>({
      required String trigger,
      required Future<T> Function(AuthSession session) action,
    });

enum VeranstaltungenLadezustand {
  initial,
  laedt,
  geladen,

  /// Kein Netz oder mobile Daten gesperrt.
  offline,

  /// Die Sitzung braucht eine neue Anmeldung.
  anmeldungNoetig,
  fehler,
}

/// Suche ueber Kurse und Veranstaltungen. Laedt nur auf Abruf, nicht im
/// Hintergrund-Sync, und haelt die Ergebnisse je Ebene fuer
/// [cacheDauer] im Speicher. Nichts davon wird auf dem Geraet gespeichert.
class VeranstaltungenModel extends ChangeNotifier {
  VeranstaltungenModel({
    required HitobitoEventsService service,
    required VeranstaltungenRemoteAccessExecutor remoteAccessExecutor,
    required ArbeitskontextReadModel? Function() readModel,
    int Function()? sessionGeneration,
    Uri? Function(Veranstaltung veranstaltung)? webSeite,
    DateTime Function()? jetzt,
  }) : _service = service,
       _remoteAccess = remoteAccessExecutor,
       _readModel = readModel,
       _sessionGeneration = sessionGeneration,
       _webSeite = webSeite,
       _jetzt = jetzt ?? DateTime.now,
       _generation = sessionGeneration?.call();

  static const Duration cacheDauer = Duration(minutes: 15);
  static const _suchgruppen = BestimmeSuchgruppenUseCase();
  static const _filtere = FiltereVeranstaltungenUseCase();

  final HitobitoEventsService _service;
  final VeranstaltungenRemoteAccessExecutor _remoteAccess;
  final ArbeitskontextReadModel? Function() _readModel;
  final int Function()? _sessionGeneration;
  final Uri? Function(Veranstaltung veranstaltung)? _webSeite;
  final DateTime Function() _jetzt;

  VeranstaltungsFilter _filter = VeranstaltungsFilter.standard;
  VeranstaltungenLadezustand _zustand = VeranstaltungenLadezustand.initial;
  final Map<String, _CacheEintrag> _cache = {};
  final Map<int, String> _geladeneGruppenNamen = {};
  final Map<int, Veranstaltung> _details = {};
  List<Veranstaltung> _veranstaltungen = const [];
  int? _generation;
  int _anfrage = 0;

  VeranstaltungsFilter get filter => _filter;
  VeranstaltungenLadezustand get zustand => _zustand;
  DateTime get heute => _jetzt();

  /// Gefiltert und nach erstem Termin sortiert.
  List<Veranstaltung> get treffer => _filtere(
    _veranstaltungen,
    filter: _filter,
    heute: _jetzt(),
    gruppenNamen: gruppenNamen,
  );

  /// Trefferzahl fuer einen Filter im Filterfenster; `null`, wenn dessen
  /// Ebene noch nicht geladen ist.
  int? trefferAnzahl(VeranstaltungsFilter filter) {
    final quelle = filter.ebene == _filter.ebene
        ? _veranstaltungen
        : _cache[_cacheSchluessel(filter.ebene)]?.veranstaltungen;
    if (quelle == null) {
      return null;
    }
    return _filtere(
      quelle,
      filter: filter,
      heute: _jetzt(),
      gruppenNamen: gruppenNamen,
    ).length;
  }

  String _cacheSchluessel(EbenenFilter ebene) {
    final gruppen = _suchgruppen(_readModel(), ebene);
    return gruppen == null ? 'alle' : (gruppen.toList()..sort()).join(',');
  }

  /// Alle geladenen Events der gewaehlten Ebene, ohne lokale Filter.
  int get geladenAnzahl => _veranstaltungen.length;

  /// Kategorien der geladenen Kurse, nach Name sortiert.
  List<KursartKategorie> get kategorien {
    final kategorien = <int, KursartKategorie>{};
    for (final veranstaltung in _veranstaltungen) {
      final kategorie = veranstaltung.kursart?.kategorie;
      if (kategorie != null) {
        kategorien[kategorie.id] = kategorie;
      }
    }
    return kategorien.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
  }

  /// Namen aus dem Arbeitskontext, ergaenzt um nachgeladene Gruppen.
  Map<int, String> get gruppenNamen {
    final readModel = _readModel();
    return {
      ..._geladeneGruppenNamen,
      if (readModel != null) ...{
        for (final layer in readModel.arbeitskontext.verfuegbareLayer)
          layer.id: layer.name,
        readModel.arbeitskontext.aktiverLayer.id:
            readModel.arbeitskontext.aktiverLayer.name,
        for (final gruppe in readModel.gruppen) gruppe.id: gruppe.name,
      },
    };
  }

  /// Name der veranstaltenden Gruppe(n), `null` wenn keiner bekannt ist.
  String? veranstalter(Veranstaltung veranstaltung) {
    final namen = gruppenNamen;
    final bekannt = [for (final id in veranstaltung.gruppenIds) ?namen[id]];
    return bekannt.isEmpty ? null : bekannt.join(', ');
  }

  /// Oeffentliche Anmeldeseite, sonst die Eventseite in Hitobito; `null`,
  /// wenn es keine gibt (z. B. im Demo).
  Uri? webLink(Veranstaltung veranstaltung) =>
      veranstaltung.anmeldeLinkExtern ?? _webSeite?.call(veranstaltung);

  /// Details (Beschreibung, Kontakt, Leitung), sofern schon geladen.
  Veranstaltung? detail(int id) => _details[id];

  void setzeFilter(VeranstaltungsFilter filter) {
    if (filter == _filter) {
      return;
    }
    final neueEbene = filter.ebene != _filter.ebene;
    _filter = filter;
    notifyListeners();
    if (neueEbene) {
      laden();
    }
  }

  void filterZuruecksetzen() => setzeFilter(VeranstaltungsFilter.standard);

  /// Laedt die Events der gewaehlten Ebene, aus dem Cache solange er frisch
  /// ist.
  Future<void> laden({bool erzwingen = false}) async {
    sitzungPruefen();
    final gruppen = _suchgruppen(_readModel(), _filter.ebene);
    final schluessel = _cacheSchluessel(_filter.ebene);
    final jetzt = _jetzt();
    final eintrag = _cache[schluessel];
    if (!erzwingen &&
        eintrag != null &&
        jetzt.difference(eintrag.geladenAm) < cacheDauer) {
      _veranstaltungen = eintrag.veranstaltungen;
      _zustand = VeranstaltungenLadezustand.geladen;
      notifyListeners();
      return;
    }

    final anfrage = ++_anfrage;
    _zustand = VeranstaltungenLadezustand.laedt;
    notifyListeners();

    try {
      final ergebnis = await _remoteAccess<_Ladeergebnis>(
        trigger: 'veranstaltungen_suche',
        action: (session) async {
          final veranstaltungen = await _service.fetchVeranstaltungen(
            session.accessToken,
            abTag: jetzt,
            gruppenIds: gruppen,
          );
          final bekannt = gruppenNamen.keys.toSet();
          final fehlend = {
            for (final veranstaltung in veranstaltungen)
              ...veranstaltung.gruppenIds,
          }.difference(bekannt);
          Map<int, String> namen = const {};
          if (fehlend.isNotEmpty) {
            try {
              namen = await _service.fetchGruppenNamen(
                session.accessToken,
                fehlend,
              );
            } on HitobitoApiException {
              // Ohne Namen bleibt die Liste nutzbar.
            }
          }
          return _Ladeergebnis(veranstaltungen, namen);
        },
      );
      if (anfrage != _anfrage) {
        return;
      }
      if (ergebnis == null) {
        _zustand = VeranstaltungenLadezustand.anmeldungNoetig;
      } else {
        _geladeneGruppenNamen.addAll(ergebnis.gruppenNamen);
        _cache[schluessel] = _CacheEintrag(jetzt, ergebnis.veranstaltungen);
        _veranstaltungen = ergebnis.veranstaltungen;
        _zustand = VeranstaltungenLadezustand.geladen;
      }
    } on NetworkAccessBlockedException {
      if (anfrage == _anfrage) {
        _zustand = VeranstaltungenLadezustand.offline;
      }
    } catch (_) {
      if (anfrage == _anfrage) {
        _zustand = VeranstaltungenLadezustand.fehler;
      }
    }
    if (anfrage == _anfrage) {
      notifyListeners();
    }
  }

  /// Laedt Beschreibung, Kontakt und Leitung eines Events nach. Fehler
  /// lassen die Listendaten stehen.
  Future<Veranstaltung?> ladeDetail(int id) async {
    sitzungPruefen();
    final vorhanden = _details[id];
    if (vorhanden != null) {
      return vorhanden;
    }
    try {
      final detail = await _remoteAccess<Veranstaltung>(
        trigger: 'veranstaltung_detail',
        action: (session) =>
            _service.fetchVeranstaltung(session.accessToken, id: id),
      );
      if (detail != null) {
        _details[id] = detail;
        notifyListeners();
      }
      return detail;
    } catch (_) {
      return null;
    }
  }

  /// Verwirft alles Geladene, sobald sich die Sitzung geaendert hat
  /// (Abmelden, anderes Konto). Haengt in der App am AuthSessionModel.
  void sitzungPruefen() {
    final generation = _sessionGeneration?.call();
    if (generation == _generation) {
      return;
    }
    final hatteDaten = _cache.isNotEmpty || _details.isNotEmpty;
    _generation = generation;
    _anfrage++;
    _cache.clear();
    _details.clear();
    _geladeneGruppenNamen.clear();
    _veranstaltungen = const [];
    _filter = VeranstaltungsFilter.standard;
    _zustand = VeranstaltungenLadezustand.initial;
    if (hatteDaten) {
      notifyListeners();
    }
  }
}

class _CacheEintrag {
  const _CacheEintrag(this.geladenAm, this.veranstaltungen);

  final DateTime geladenAm;
  final List<Veranstaltung> veranstaltungen;
}

class _Ladeergebnis {
  const _Ladeergebnis(this.veranstaltungen, this.gruppenNamen);

  final List<Veranstaltung> veranstaltungen;
  final Map<int, String> gruppenNamen;
}
