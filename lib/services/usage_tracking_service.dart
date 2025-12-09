import 'package:nami/presentation/format/date_formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

typedef NowProvider = DateTime Function();

class UsageTrackingService {
  final LoggerService logger;
  final NowProvider now;
  Duration resumeThreshold = const Duration(minutes: 1);

  DateTime? _start;
  DateTime? _pausedAt;
  Stopwatch? _pauseStopwatch;

  UsageTrackingService({required this.logger, NowProvider? nowProvider})
    : now = nowProvider ?? DateTime.now;

  void startSession() {
    _start = now();
    _pausedAt = null;
    // Für Diagnose lokal loggen
    // logger.log('usage', 'session_started at ${_start!.toIso8601String()}');
  }

  Future<void> endSession() async {
    final s = _start;
    if (s == null) return;
    final end = now();
    final duration = end.difference(s);
    final seconds = duration.inSeconds;
    await logger.trackAndLog('usage', 'session_duration', {
      'seconds': seconds,
      'start': DateFormatter.formatTecnicalShortDate(s),
      'end': DateFormatter.formatTecnicalShortDate(end),
    });
    _start = null;
    _pausedAt = null;
  }

  // Beim App-Start oder Resume: ausstehende Pause auswerten und ggf. Session-Ende senden
  Future<void> flushPendingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final startIso = prefs.getString('usage.pending_start_iso');
    final pausedIso = prefs.getString('usage.pending_paused_iso');
    if (startIso == null || pausedIso == null) {
      return;
    }
    final start = DateTime.tryParse(startIso);
    final paused = DateTime.tryParse(pausedIso);
    if (start == null || paused == null) {
      await prefs.remove('usage.pending_start_iso');
      await prefs.remove('usage.pending_paused_iso');
      return;
    }
    final delta = now().difference(paused);
    if (delta >= resumeThreshold) {
      final seconds = paused.difference(start).inSeconds;
      await logger.trackAndLog('usage', 'session_duration', {
        'seconds': seconds,
        'start': DateFormatter.formatTecnicalShortDate(start),
        'end': DateFormatter.formatTecnicalShortDate(paused),
      });
      // await logger.log('usage', 'flushed_pending_session seconds=$seconds');
      await prefs.remove('usage.pending_start_iso');
      await prefs.remove('usage.pending_paused_iso');
      // Nach dem Senden startet der Aufrufer (z. B. initState) eine neue Session
    } else {
      // Kurze Pause: keine Ende-Meldung, Aufräumen und Fortsetzung
      await prefs.remove('usage.pending_start_iso');
      await prefs.remove('usage.pending_paused_iso');
      // ignore: unused_local_variable
      final shortSec = delta.inSeconds;
      // await logger.log('usage', 'pending_pause_discarded after ${shortSec}s');
    }
  }

  // Aufrufen, wenn App in den Hintergrund geht
  void pause() {
    _pausedAt = now();
    _pauseStopwatch = Stopwatch()..start();
    // logger.log('usage', 'session_paused at ${_pausedAt!.toIso8601String()}');
    // Persistiere Snapshot für robustes Resume/Start-Entscheiden
    _persistPauseSnapshot();
  }

  // Aufrufen, wenn App wieder in den Vordergrund kommt
  Future<void> resume() async {
    final paused = _pausedAt;
    if (paused == null) {
      // Falls Snapshot aus vorheriger App-Instanz vorhanden, beim Resume auswerten
      await flushPendingSession();
      // Kein Pause-Zeitpunkt erfasst – normale Fortsetzung
      return;
    }
    // Einige Plattformen senden 'inactive/paused' direkt beim Öffnen.
    // Ignoriere Pausen kürzer als 1s als spurious, um 0s-Resumes zu vermeiden.
    final justPaused =
        _pauseStopwatch != null &&
        _pauseStopwatch!.elapsed < const Duration(seconds: 1);
    if (justPaused) {
      _pausedAt = null;
      _pauseStopwatch = null;
      return;
    }
    final delta = now().difference(paused);
    if (delta > resumeThreshold) {
      // Zu lange im Hintergrund: aktuelle Session beenden und neue starten
      await endSession();
      startSession();
    } else {
      // Fortsetzen: Pause zurücksetzen, Start bleibt erhalten
      // logger.log('usage', 'session_resumed after ${delta.inSeconds}s');
      _pausedAt = null;
      _pauseStopwatch = null;
      // Aufräumen eines evtl. gespeicherten Snapshots
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('usage.pending_start_iso');
      await prefs.remove('usage.pending_paused_iso');
    }
  }

  Future<void> _persistPauseSnapshot() async {
    if (_start == null || _pausedAt == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usage.pending_start_iso', _start!.toIso8601String());
    await prefs.setString(
      'usage.pending_paused_iso',
      _pausedAt!.toIso8601String(),
    );
  }
}
