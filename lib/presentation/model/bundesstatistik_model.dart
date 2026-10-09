import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/bundesstatistik/baue_stammes_kennzahlen_usecase.dart';
import '../../domain/bundesstatistik/bundesaggregat.dart';
import '../../domain/bundesstatistik/bundesstatistik_repository.dart';
import '../../domain/bundesstatistik/bundesstatistik_teilnahme.dart';
import '../../domain/bundesstatistik/ermittle_stammes_hierarchie_usecase.dart';
import '../../domain/bundesstatistik/installation_credentials.dart';
import '../../domain/bundesstatistik/stammes_snapshot.dart';
import '../../domain/bundesstatistik/statistik_abdeckung.dart';
import '../../services/logger_service.dart';
import '../../services/network_access_policy.dart';

enum BundesstatistikStatus {
  /// Kein Statistikserver konfiguriert.
  nichtVerfuegbar,
  keineEinwilligung,

  /// Arbeitskontext oder Rollen sind noch nicht geladen.
  wartetAufDaten,

  /// Der aktive Layer ist kein Stamm.
  keinStamm,

  /// Der Stamm hat keine Mitglieder in den Stufen.
  keineKennzahlen,

  /// Der Server erkennt noch keine Teilnahme (z. B. vor dem ersten Senden).
  nichtTeilnehmend,
  zuWenigTeilnahme,
  bereit,

  /// Der Server hat den Snapshot fachlich abgelehnt (App und Server passen
  /// nicht zusammen), kein Netzwerkproblem.
  abgelehnt,
  fehler,
}

/// Steuert Einwilligung, Senden des Stammes-Snapshots und Abruf des
/// Bundesaggregats. Ohne Einwilligung der aktuell angemeldeten Person wird
/// nichts gesendet und nichts abgerufen.
class BundesstatistikModel extends ChangeNotifier {
  BundesstatistikModel({
    required bool featureEnabled,
    required BundesstatistikRepository repository,
    required InstallationCredentialsRepository credentialsRepository,
    required BundesstatistikTeilnahmeRepository teilnahmeRepository,
    NetworkAccessPolicy? networkAccessPolicy,
    LoggerService? logger,
    Duration sendInterval = const Duration(days: 7),
    Duration aggregatRefreshInterval = const Duration(hours: 6),
    DateTime Function()? now,
    BaueStammesKennzahlenUseCase baueKennzahlen =
        const BaueStammesKennzahlenUseCase(),
    ErmittleStammesHierarchieUseCase ermittleHierarchie =
        const ErmittleStammesHierarchieUseCase(),
  }) : _featureEnabled = featureEnabled,
       _repository = repository,
       _credentialsRepository = credentialsRepository,
       _teilnahmeRepository = teilnahmeRepository,
       _networkAccessPolicy = networkAccessPolicy,
       _logger = logger,
       _sendInterval = sendInterval,
       _aggregatRefreshInterval = aggregatRefreshInterval,
       _now = now ?? DateTime.now,
       _baueKennzahlen = baueKennzahlen,
       _ermittleHierarchie = ermittleHierarchie;

  final bool _featureEnabled;
  final BundesstatistikRepository _repository;
  final InstallationCredentialsRepository _credentialsRepository;
  final BundesstatistikTeilnahmeRepository _teilnahmeRepository;
  final NetworkAccessPolicy? _networkAccessPolicy;
  final LoggerService? _logger;
  final Duration _sendInterval;
  final Duration _aggregatRefreshInterval;
  final DateTime Function() _now;
  final BaueStammesKennzahlenUseCase _baueKennzahlen;
  final ErmittleStammesHierarchieUseCase _ermittleHierarchie;

  BundesstatistikTeilnahme _teilnahme = BundesstatistikTeilnahme.leer;
  String? _personId;
  ArbeitskontextReadModel? _readModel;
  StatistikAbdeckung? _abdeckung;
  DateTime? _datenstand;
  StammesHierarchie? _hierarchie;
  StammesKennzahlen? _eigeneKennzahlen;
  Bundesaggregat? _aggregat;
  DateTime? _aggregatGeladenAm;
  bool _nichtTeilnehmend = false;
  BundesstatistikFehlerArt? _letzterFehler;
  bool _isBusy = false;
  bool _syncErneutAngefordert = false;

  /// Hoechstes Alter des Datenstands, mit dem noch gesendet wird.
  static const Duration maxDatenstandAlter = Duration(days: 7);

  bool get isAvailable => _featureEnabled;

  /// Name des aktiven Stammes fuer den Einwilligungsdialog.
  String? get stammName =>
      _hierarchie == null ? null : _readModel?.arbeitskontext.aktiverLayer.name;

  String? _installationsId;

  /// Installations-ID fuer Auskunft und Loeschung auf Anfrage. Erst bekannt,
  /// wenn diese Installation schon geteilt hat.
  String? get installationsId => _installationsId;

  /// Liest die ID nur, wenn bereits gesendet wurde; legt keine neue an.
  Future<void> ladeInstallationsId() async {
    if (_teilnahme.zuletztGesendetAm == null) {
      return;
    }
    _setzeInstallationsId((await _credentialsRepository.loadOrCreate()).id);
  }

  void _setzeInstallationsId(String id) {
    if (_installationsId != id) {
      _installationsId = id;
      notifyListeners();
    }
  }

  bool get isBusy => _isBusy;

  /// Einwilligung der angemeldeten Person fuer den aktiven Stamm. Wer mehrere
  /// Staemme sieht, gibt jeden einzeln frei.
  bool get hatEinwilligung {
    final personId = _personId;
    final stammId = _hierarchie?.stammId;
    return personId != null &&
        stammId != null &&
        _teilnahme.hatEinwilligungFuer(personId, stammId);
  }

  DateTime? get einwilligungAm {
    final personId = _personId;
    final stammId = _hierarchie?.stammId;
    return personId == null || stammId == null
        ? null
        : _teilnahme.einwilligungAm(personId, stammId);
  }

  Bundesaggregat? get aggregat => _aggregat;
  StammesKennzahlen? get eigeneKennzahlen => _eigeneKennzahlen;

  /// Ob die Person den ganzen Stamm oder nur einzelne Gruppen sieht; `null`,
  /// solange Rechte oder Daten fehlen.
  StatistikAbdeckung? get abdeckung => _abdeckung;

  /// Anzeigename einer Gruppe des aktiven Stamms, z. B. für geteilte Werte.
  String? gruppenName(int gruppenId) =>
      _readModel?.findeGruppe(gruppenId)?.anzeigename;
  BundesstatistikFehlerArt? get letzterFehler => _letzterFehler;

  /// Zuletzt fuer den aktuellen Stamm gesendeter Snapshot (Transparenz).
  StammesSnapshot? get zuletztGesendeterSnapshot {
    final stammId = _hierarchie?.stammId;
    final sendestand = stammId == null
        ? null
        : _teilnahme.sendestaende[stammId];
    final json = sendestand?.snapshotJson;
    if (json == null || stammId == null) {
      return null;
    }
    try {
      final snapshot = StammesSnapshot.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
        sentAt: sendestand?.am,
      );
      return snapshot.stammId == stammId ? snapshot : null;
    } catch (_) {
      return null;
    }
  }

  BundesstatistikStatus get status {
    if (!_featureEnabled) {
      return BundesstatistikStatus.nichtVerfuegbar;
    }
    // Die Einwilligung gilt je Stamm, deshalb zuerst den Stamm kennen.
    final readModel = _readModel;
    if (readModel == null ||
        !readModel.rolesSindGeladen ||
        _abdeckung == null) {
      return BundesstatistikStatus.wartetAufDaten;
    }
    if (_hierarchie == null) {
      return BundesstatistikStatus.keinStamm;
    }
    if (!hatEinwilligung) {
      return BundesstatistikStatus.keineEinwilligung;
    }
    final aggregat = _aggregat;
    if (aggregat != null && !_nichtTeilnehmend) {
      return aggregat.status == BundesaggregatStatus.ok
          ? BundesstatistikStatus.bereit
          : BundesstatistikStatus.zuWenigTeilnahme;
    }
    // Ohne plausible Zahlen wird ohne Werte teilgenommen; nur ohne jede
    // Stufengruppe gibt es nichts zu senden.
    if (_eigeneKennzahlen?.gruppen.isEmpty ?? true) {
      return BundesstatistikStatus.keineKennzahlen;
    }
    if (_letzterFehler == BundesstatistikFehlerArt.abgelehnt) {
      return BundesstatistikStatus.abgelehnt;
    }
    if (_letzterFehler != null) {
      return BundesstatistikStatus.fehler;
    }
    if (_nichtTeilnehmend) {
      return BundesstatistikStatus.nichtTeilnehmend;
    }
    return BundesstatistikStatus.wartetAufDaten;
  }

  Future<void> initialize() async {
    if (!_featureEnabled) {
      return;
    }
    _teilnahme = await _teilnahmeRepository.load();
    notifyListeners();
  }

  /// Vergisst nach einem App-Reset alles im Speicher, vor allem die
  /// Einwilligungen. Sonst schriebe das naechste Speichern sie zurueck.
  void zuruecksetzen() {
    _teilnahme = BundesstatistikTeilnahme.leer;
    _personId = null;
    _readModel = null;
    _abdeckung = null;
    _datenstand = null;
    _hierarchie = null;
    _eigeneKennzahlen = null;
    _aggregat = null;
    _aggregatGeladenAm = null;
    _nichtTeilnehmend = false;
    _letzterFehler = null;
    _installationsId = null;
    _syncErneutAngefordert = false;
    notifyListeners();
  }

  /// Wird bei Aenderungen an Anmeldung oder Arbeitskontext aufgerufen.
  Future<void> aktualisiereKontext({
    required String? personId,
    required ArbeitskontextReadModel? readModel,
    required DateTime? datenstand,
    required StatistikAbdeckung? abdeckung,
  }) async {
    if (!_featureEnabled) {
      return;
    }
    if (personId == _personId &&
        identical(readModel, _readModel) &&
        datenstand == _datenstand &&
        abdeckung == _abdeckung) {
      return;
    }

    if (personId != _personId) {
      _aggregat = null;
      _aggregatGeladenAm = null;
      _nichtTeilnehmend = false;
      _letzterFehler = null;
    }
    _personId = personId;
    _readModel = readModel;
    _abdeckung = abdeckung;
    _datenstand = datenstand;
    _berechneEigeneKennzahlen();
    notifyListeners();
    await _synchronisiere();
  }

  /// Erteilt oder widerruft die Einwilligung fuer den aktiven Stamm.
  Future<void> setzeEinwilligung(bool erteilt) async {
    final personId = _personId;
    final stammId = _hierarchie?.stammId;
    if (!_featureEnabled || personId == null || stammId == null) {
      return;
    }

    _teilnahme = erteilt
        ? _teilnahme.mitEinwilligung(personId, stammId, _now())
        : _teilnahme.ohneEinwilligung(stammId);
    if (!erteilt) {
      _aggregat = null;
      _aggregatGeladenAm = null;
      _nichtTeilnehmend = false;
      _letzterFehler = null;
    }
    await _teilnahmeRepository.save(_teilnahme);
    await _log(
      erteilt
          ? 'Einwilligung zur bundesweiten Statistik erteilt'
          : 'Einwilligung zur bundesweiten Statistik widerrufen',
    );
    notifyListeners();

    if (erteilt) {
      await _synchronisiere(aggregatErzwingen: true);
    }
  }

  /// Manuelles Aktualisieren, z. B. beim Oeffnen der Vergleichsseite.
  Future<void> aktualisieren() => _synchronisiere(aggregatErzwingen: true);

  void _berechneEigeneKennzahlen() {
    final readModel = _readModel;
    final abdeckung = _abdeckung;
    if (readModel == null || !readModel.rolesSindGeladen || abdeckung == null) {
      _hierarchie = null;
      _eigeneKennzahlen = null;
      return;
    }
    _hierarchie = _ermittleHierarchie(readModel);
    _eigeneKennzahlen = _hierarchie == null
        ? null
        : _baueKennzahlen(readModel, stichtag: _now(), abdeckung: abdeckung);
  }

  Future<void> _synchronisiere({bool aggregatErzwingen = false}) async {
    if (!_featureEnabled || !hatEinwilligung) {
      return;
    }
    if (_isBusy) {
      _syncErneutAngefordert = true;
      return;
    }

    _isBusy = true;
    notifyListeners();
    try {
      if (!await _netzwerkErlaubt()) {
        return;
      }

      var credentials = await _credentialsRepository.loadOrCreate();
      credentials = await _mitNeuenCredentialsBeiBedarf(
        credentials,
        _sendeWennFaellig,
      );
      if (_teilnahme.zuletztGesendetAm != null) {
        _setzeInstallationsId(credentials.id);
      }

      // Lesen darf nur, wer beigetragen hat; ohne eigene Sendung waere die
      // Antwort ohnehin 403.
      final hatGesendet = _teilnahme.zuletztGesendetAm != null;
      if (hatGesendet && (aggregatErzwingen || _aggregatFaellig())) {
        await _mitNeuenCredentialsBeiBedarf(credentials, (aktuelle) async {
          await _sendeWennFaellig(aktuelle);
          await _ladeAggregat(aktuelle);
        });
      }
      _letzterFehler = null;
    } on BundesstatistikException catch (error) {
      _letzterFehler = error.art;
      await _log(
        'Bundesstatistik fehlgeschlagen: ${error.art.name} (${error.code ?? '-'})',
      );
    } catch (error) {
      _letzterFehler = BundesstatistikFehlerArt.unbekannt;
      await _log('Bundesstatistik fehlgeschlagen: $error');
    } finally {
      _isBusy = false;
      notifyListeners();
    }

    if (_syncErneutAngefordert) {
      _syncErneutAngefordert = false;
      await _synchronisiere();
    }
  }

  /// Bei `invalid_sender_credentials` (z. B. nach Neuaufsetzen des Servers)
  /// neue Credentials erzeugen, den Sendestand verwerfen und die Aktion genau
  /// einmal mit den neuen Credentials wiederholen. Liefert die danach
  /// gueltigen Credentials.
  Future<InstallationCredentials> _mitNeuenCredentialsBeiBedarf(
    InstallationCredentials credentials,
    Future<void> Function(InstallationCredentials credentials) aktion,
  ) async {
    try {
      await aktion(credentials);
      return credentials;
    } on BundesstatistikException catch (error) {
      if (error.art != BundesstatistikFehlerArt.ungueltigeCredentials) {
        rethrow;
      }
      await _log('Installations-Credentials ungueltig, erzeuge neue');
      final neu = await _credentialsRepository.regenerate();
      _teilnahme = _teilnahme.ohneSendestand();
      await _teilnahmeRepository.save(_teilnahme);
      await aktion(neu);
      return neu;
    }
  }

  Future<void> _sendeWennFaellig(InstallationCredentials credentials) async {
    final hierarchie = _hierarchie;
    final eigene = _eigeneKennzahlen;
    if (hierarchie == null || eigene == null) {
      return;
    }
    // Waehrend des Syncs kann der Stamm gewechselt oder die Einwilligung
    // widerrufen worden sein. Bis zum Senden folgt kein await mehr, deshalb
    // gilt diese Pruefung fuer genau den Stamm, der gesendet wird.
    final personId = _personId;
    if (personId == null ||
        !_teilnahme.hatEinwilligungFuer(personId, hierarchie.stammId)) {
      return;
    }
    // Die Absicht zu teilen reicht: Ohne plausible Zahlen geht eine Teilnahme
    // ohne Werte raus. Ohne Stufengruppen gibt es nicht einmal eine Struktur.
    final kennzahlen = eigene.istPlausibel
        ? eigene
        : eigene.alsTeilnahmeOhneWerte;
    if (kennzahlen.gruppen.isEmpty) {
      return;
    }

    final now = _now();
    // Der Server nimmt nur Datenstaende an, die hoechstens sieben Tage alt
    // sind; ohne frische Synchronisierung geht nichts raus.
    final datenstand = _datenstand;
    if (datenstand == null || now.difference(datenstand) > maxDatenstandAlter) {
      return;
    }
    final zuletzt = _teilnahme.sendestaende[hierarchie.stammId]?.am;
    final faellig =
        zuletzt == null ||
        now.difference(zuletzt) >= _sendInterval ||
        _zuletztGesendeteAbdeckung(hierarchie.stammId) !=
            kennzahlen.abdeckung.alsGesendet;
    if (!faellig) {
      return;
    }

    final snapshot = StammesSnapshot(
      stammId: hierarchie.stammId,
      bezirkId: hierarchie.bezirkId,
      dvId: hierarchie.dvId,
      senderId: credentials.id,
      sentAt: now,
      sourceDataAsOf: datenstand.isAfter(now) ? now : datenstand,
      kennzahlen: kennzahlen,
    );

    await _repository.sendeSnapshot(snapshot, credentials);
    _teilnahme = _teilnahme.mitGesendetemSnapshot(
      am: now,
      stammId: hierarchie.stammId,
      snapshotJson: jsonEncode(snapshot.toJson()),
    );
    await _teilnahmeRepository.save(_teilnahme);
    _nichtTeilnehmend = false;
    // Nach neuem Beitrag das Aggregat frisch laden.
    _aggregatGeladenAm = null;
    await _log('Stammes-Snapshot fuer die bundesweite Statistik gesendet');
  }

  /// Abdeckung des zuletzt gesendeten Snapshots; aendern sich die Rechte,
  /// wird sofort neu gesendet.
  StatistikAbdeckung? _zuletztGesendeteAbdeckung(String stammId) {
    final json = _teilnahme.sendestaende[stammId]?.snapshotJson;
    if (json == null) {
      return null;
    }
    try {
      return StammesSnapshot.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      ).kennzahlen.abdeckung;
    } catch (_) {
      return null;
    }
  }

  bool _aggregatFaellig() {
    final geladenAm = _aggregatGeladenAm;
    return geladenAm == null ||
        _now().difference(geladenAm) >= _aggregatRefreshInterval;
  }

  Future<void> _ladeAggregat(
    InstallationCredentials credentials, {
    bool nachsendenErlaubt = true,
  }) async {
    final personId = _personId;
    try {
      final aggregat = await _repository.ladeBundesaggregat(credentials);
      // Hat sich die Person inzwischen geaendert oder die Einwilligung
      // zurueckgezogen, gehoert das Ergebnis nicht mehr in die Anzeige.
      if (_personId != personId || !hatEinwilligung) {
        return;
      }
      _aggregat = aggregat;
      _aggregatGeladenAm = _now();
      _nichtTeilnehmend = false;
    } on BundesstatistikException catch (error) {
      if (error.art != BundesstatistikFehlerArt.nichtTeilnehmend) {
        rethrow;
      }
      _nichtTeilnehmend = true;
      _aggregat = null;
      _aggregatGeladenAm = null;
      if (!nachsendenErlaubt || _teilnahme.zuletztGesendetAm == null) {
        return;
      }
      // Die App haelt sich fuer teilnehmend, der Server nicht (z. B. nach
      // Datenverlust): einmal neu senden und erneut lesen.
      _teilnahme = _teilnahme.ohneSendestand();
      await _teilnahmeRepository.save(_teilnahme);
      await _sendeWennFaellig(credentials);
      if (_teilnahme.zuletztGesendetAm != null) {
        await _ladeAggregat(credentials, nachsendenErlaubt: false);
      }
    }
  }

  Future<bool> _netzwerkErlaubt() async {
    final policy = _networkAccessPolicy;
    if (policy == null) {
      return true;
    }
    final decision = await policy.evaluateAccess(
      trigger: 'bundesstatistik',
      feature: 'Bundesweite Statistik',
    );
    return decision.allowed;
  }

  Future<void> _log(String message) async {
    await _logger?.log('bundesstatistik', message);
  }
}
