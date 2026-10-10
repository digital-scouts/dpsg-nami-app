import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/app_update/sicherheits_update_regel.dart';
import '../../services/app_update_service.dart';
import '../../services/logger_service.dart';

typedef SicherheitsTimerFactory =
    Timer Function(Duration dauer, void Function() callback);

/// Steuert Nachfrage, Countdown und Sperre eines Sicherheitsupdates.
/// Normale Updates unter `min_supported` sperren nie; das hier gilt nur fuer
/// den Block `security` im Versions-Manifest (`/app/version`).
class SicherheitsUpdateModel extends ChangeNotifier {
  SicherheitsUpdateModel({
    required AppUpdateService updateService,
    Future<SharedPreferences> Function()? preferencesProvider,
    DateTime Function()? now,
    SicherheitsTimerFactory? timerFactory,
    Future<void> Function()? onDatenLoeschen,
    LoggerService? logger,
  }) : _updateService = updateService,
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _timerFactory = timerFactory ?? Timer.new,
       _onDatenLoeschen = onDatenLoeschen,
       _logger = logger;

  static const String standKey = 'app_update_security_state';
  static const SicherheitsUpdateRegel _regel = SicherheitsUpdateRegel();

  final AppUpdateService _updateService;
  final Future<SharedPreferences> Function() _preferencesProvider;
  final DateTime Function() _now;
  final SicherheitsTimerFactory _timerFactory;
  final Future<void> Function()? _onDatenLoeschen;
  final LoggerService? _logger;

  SicherheitsUpdateInfo? _info;
  SicherheitsUpdateStand _stand = SicherheitsUpdateStand.leer;
  SicherheitsUpdateLage _lage = SicherheitsUpdateLage.keine;
  Timer? _timer;
  bool _datenGeloescht = false;

  SicherheitsUpdateInfo? get info => _info;
  SicherheitsUpdateLage get lage => _lage;
  bool get istGesperrt => _lage.art == SicherheitsUpdateLageArt.gesperrt;

  /// Beim Sperren wurden die Mitgliederdaten geloescht; kein Notfallzugang.
  bool get datenGeloescht => _datenGeloescht;

  /// Laedt das Manifest (offline aus dem Cache) und berechnet die Lage neu.
  Future<void> pruefe({bool forceRefresh = false}) async {
    try {
      _info = await _updateService.pruefeSicherheitsupdate(
        forceRefresh: forceRefresh,
      );
    } catch (error) {
      // Ohne Manifest bleibt der bekannte Stand; eine Sperre haelt also auch
      // offline.
      await _logger?.logWarn(
        'update',
        'Sicherheitsupdate-Pruefung fehlgeschlagen: ${error.runtimeType}',
      );
      if (_info == null) {
        await _ladeStand();
        _aktualisiere();
        return;
      }
    }
    await _ladeStand();
    if (_info == null) {
      // Update installiert oder Vorgabe zurueckgenommen.
      if (!_stand.istLeer) {
        await _speichere(SicherheitsUpdateStand.leer);
      }
      _datenGeloescht = false;
    }
    await _aktualisiere();
  }

  /// „In 3 Stunden erinnern“.
  Future<void> spaeter() async {
    if (_info == null) {
      return;
    }
    await _speichere(_regel.spaeter(_stand, now: _now()));
    await _aktualisiere();
  }

  Future<void> _aktualisiere() async {
    _timer?.cancel();
    _timer = null;
    if (_info == null) {
      _lage = SicherheitsUpdateLage.keine;
      notifyListeners();
      return;
    }
    final now = _now();
    final neu = _regel.mitSperreWennFaellig(_stand, now: now);
    if (!identical(neu, _stand)) {
      await _speichere(neu);
      await _logger?.logWarn('update', 'App wegen Sicherheitsupdate gesperrt');
    }
    _lage = _regel.lage(_stand, now: now);
    if (istGesperrt &&
        (_info?.vorgabe.datenLoeschen ?? false) &&
        !_datenGeloescht) {
      _datenGeloescht = true;
      await _onDatenLoeschen?.call();
    }
    final ab = _lage.ab;
    if (ab != null) {
      _timer = _timerFactory(ab.difference(now), () {
        unawaited(_aktualisiere());
      });
    }
    notifyListeners();
  }

  Future<void> _ladeStand() async {
    final prefs = await _preferencesProvider();
    final raw = prefs.getString(standKey);
    if (raw == null) {
      _stand = SicherheitsUpdateStand.leer;
      return;
    }
    try {
      _stand = SicherheitsUpdateStand.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      _stand = SicherheitsUpdateStand.leer;
    }
  }

  Future<void> _speichere(SicherheitsUpdateStand stand) async {
    _stand = stand;
    final prefs = await _preferencesProvider();
    if (stand.istLeer) {
      await prefs.remove(standKey);
    } else {
      await prefs.setString(standKey, jsonEncode(stand.toJson()));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
