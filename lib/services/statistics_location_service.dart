import 'package:latlong2/latlong.dart';

import '../data/maps/shared_prefs_address_map_location_repository.dart';
import '../domain/maps/address_map_location.dart';
import '../domain/maps/address_map_location_repository.dart';
import '../domain/member/member_address_utils.dart';
import '../domain/member/mitglied.dart';
import 'geoapify_address_map_service.dart';
import 'geoapify_env.dart';
import 'logger_service.dart';
import 'network_access_policy.dart';

/// Warum nicht alle Adressen aufgelöst werden konnten, nach Vorrang sortiert.
enum StandortHinweis { pausiert, keineMobilenDaten, offline, unvollstaendig }

class StatisticsResolvedLocations {
  const StatisticsResolvedLocations({
    required this.memberPoints,
    required this.stammPoint,
    this.hinweis,
  });

  final List<LatLng> memberPoints;
  final LatLng? stammPoint;

  /// `null`, wenn keine Adresse an Netz, Pause oder technischem Fehler
  /// gescheitert ist.
  final StandortHinweis? hinweis;
}

class StatisticsLocationService {
  StatisticsLocationService({
    AddressMapLocationRepository? repository,
    GeoapifyAddressMapService? mapService,
    LoggerService? logger,
    NetworkAccessPolicy? networkAccessPolicy,
    Duration? negativeCacheTtl,
    DateTime Function()? nowProvider,
    Duration anfrageAbstand = const Duration(milliseconds: 250),
    Duration fehlerSperre = const Duration(minutes: 30),
    Map<String, DateTime>? fehlerSperreBis,
  }) : _repository = repository ?? SharedPrefsAddressMapLocationRepository(),
       _mapService =
           mapService ??
           GeoapifyAddressMapService(
             logger: logger,
             networkAccessPolicy: networkAccessPolicy,
           ),
       _logger = logger,
       _negativeCacheTtl = negativeCacheTtl ?? GeoapifyEnv.negativeCacheTtl,
       _now = nowProvider ?? DateTime.now,
       _anfrageAbstand = anfrageAbstand,
       _fehlerSperre = fehlerSperre,
       _fehlerSperreBis = fehlerSperreBis ?? _geteilteFehlerSperre;

  /// Technische Fehler je Adresse, prozessweit. Verhindert, dass jeder
  /// Neuaufbau der Kachel dieselben Fehlanfragen wiederholt.
  static final Map<String, DateTime> _geteilteFehlerSperre =
      <String, DateTime>{};

  final AddressMapLocationRepository _repository;
  final GeoapifyAddressMapService _mapService;
  final LoggerService? _logger;
  final Duration _negativeCacheTtl;
  final DateTime Function() _now;
  final Duration _anfrageAbstand;
  final Duration _fehlerSperre;
  final Map<String, DateTime> _fehlerSperreBis;

  /// Löst Mitglieds- und Stammadresse auf.
  ///
  /// Mit [nurCache] geht keine Anfrage an Geoapify. [abgebrochen] beendet den
  /// Lauf vor der nächsten Anfrage, etwa wenn die Kachel neu aufgebaut wurde.
  Future<StatisticsResolvedLocations> resolveLocations({
    required Iterable<Mitglied> members,
    String? stammAddress,
    bool nurCache = false,
    bool Function()? abgebrochen,
  }) async {
    final lauf = _Lauf(nurCache: nurCache, abgebrochen: abgebrochen);
    final memberPoints = await _resolveMembers(members, lauf);
    final stammPoint = await _resolveText(stammAddress, lauf);
    return StatisticsResolvedLocations(
      memberPoints: memberPoints,
      stammPoint: stammPoint,
      hinweis: lauf.hinweis,
    );
  }

  Future<List<LatLng>> resolveMemberLocations(Iterable<Mitglied> members) =>
      _resolveMembers(members, _Lauf());

  Future<LatLng?> resolveAddressText(String? addressText) =>
      _resolveText(addressText, _Lauf());

  Future<List<LatLng>> _resolveMembers(
    Iterable<Mitglied> members,
    _Lauf lauf,
  ) async {
    final byFingerprint = <String, MitgliedKontaktAdresse>{};

    for (final member in members) {
      final address = member.primaryAddress;
      if (address == null) {
        continue;
      }
      final fingerprint = MemberAddressUtils.fingerprint(address);
      byFingerprint.putIfAbsent(fingerprint, () => address);
    }

    final points = <LatLng>[];
    final seenPoints = <String>{};

    for (final entry in byFingerprint.entries) {
      final location = await _resolve(
        fingerprint: entry.key,
        addressText: MemberAddressUtils.formatGeocodingAddress(entry.value),
        lauf: lauf,
        logLabel: 'Statistik-Adresse',
      );
      if (location == null) {
        continue;
      }
      final pointKey =
          '${location.latitude.toStringAsFixed(6)}:${location.longitude.toStringAsFixed(6)}';
      if (seenPoints.add(pointKey)) {
        points.add(location);
      }
    }

    return points;
  }

  Future<LatLng?> _resolveText(String? addressText, _Lauf lauf) {
    final normalizedAddress = (addressText ?? '').trim();
    if (normalizedAddress.isEmpty) {
      return Future<LatLng?>.value();
    }
    return _resolve(
      fingerprint: MemberAddressUtils.fingerprintFromText(normalizedAddress),
      addressText: normalizedAddress,
      lauf: lauf,
      logLabel: 'Stamm-Adresse',
    );
  }

  Future<LatLng?> _resolve({
    required String fingerprint,
    required String addressText,
    required _Lauf lauf,
    required String logLabel,
  }) async {
    final cached = await _repository.load(fingerprint);
    if (cached != null) {
      if (cached.addressNotFound) {
        if (cached.isFreshNegativeCache(now: _now(), ttl: _negativeCacheTtl)) {
          return null;
        }
        await _logger?.log(
          'statistics',
          'Negativ-Cache fuer $logLabel abgelaufen',
        );
      } else if (cached.hasCoordinates) {
        return LatLng(cached.latitude!, cached.longitude!);
      } else {
        return null;
      }
    }

    if (addressText.trim().isEmpty || !lauf.darfAnfragen) {
      return null;
    }
    final gesperrtBis = _fehlerSperreBis[fingerprint];
    if (gesperrtBis != null && gesperrtBis.isAfter(_now())) {
      lauf.melde(StandortHinweis.unvollstaendig);
      return null;
    }

    if (lauf.anfragen > 0 && _anfrageAbstand > Duration.zero) {
      await Future<void>.delayed(_anfrageAbstand);
      if (!lauf.darfAnfragen) {
        return null;
      }
    }
    lauf.anfragen++;

    final result = await _mapService.resolveAddress(addressText);
    if (result.addressNotFound) {
      await _repository.save(
        AddressMapLocation(
          cacheKey: fingerprint,
          resolvedAt: _now(),
          addressFingerprint: fingerprint,
          addressNotFound: true,
        ),
      );
      return null;
    }
    final location = result.location;
    if (location == null) {
      if (result.rateLimited) {
        lauf.netzSperren(StandortHinweis.pausiert);
      } else if (result.networkBlocked) {
        lauf.netzSperren(
          result.mobileDataBlocked
              ? StandortHinweis.keineMobilenDaten
              : StandortHinweis.offline,
        );
      } else {
        _fehlerSperreBis[fingerprint] = _now().add(_fehlerSperre);
        lauf.melde(StandortHinweis.unvollstaendig);
      }
      await _logger?.log(
        'statistics',
        '$logLabel konnte nicht aufgeloest werden: ${lauf.hinweis?.name}',
      );
      return null;
    }

    _fehlerSperreBis.remove(fingerprint);
    await _repository.save(
      AddressMapLocation(
        cacheKey: fingerprint,
        latitude: location.latitude,
        longitude: location.longitude,
        resolvedAt: _now(),
        addressFingerprint: fingerprint,
      ),
    );
    return location;
  }
}

/// Zustand eines Auflösungslaufs.
class _Lauf {
  _Lauf({this.nurCache = false, this.abgebrochen});

  final bool nurCache;
  final bool Function()? abgebrochen;
  int anfragen = 0;
  bool _netzGesperrt = false;
  StandortHinweis? hinweis;

  bool get darfAnfragen =>
      !nurCache && !_netzGesperrt && !(abgebrochen?.call() ?? false);

  /// Netz, Datenregel oder Pause gelten für alle weiteren Adressen.
  void netzSperren(StandortHinweis grund) {
    _netzGesperrt = true;
    melde(grund);
  }

  void melde(StandortHinweis grund) {
    final bisher = hinweis;
    if (bisher == null || grund.index < bisher.index) {
      hinweis = grund;
    }
  }
}
