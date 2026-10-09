import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/rechtliches/anbieter.dart';
import '../../l10n/app_localizations.dart';
import '../../services/hitobito_traffic_log_service.dart';
import '../../services/logger_service.dart';
import '../../services/teilen_ordner.dart';
import '../notifications/app_snackbar.dart';
import '../widgets/app_log_view.dart';
import '../widgets/hitobito_traffic_log_view.dart';
import '../widgets/log_ausschnitt.dart';

/// Empfaenger fuer „Report Issue“; zugleich die Kontaktadresse aus der
/// Datenschutzerklaerung.
const String logReportRecipient = Anbieter.email;

typedef LogAnsichtBuilder =
    Widget Function(
      String content,
      LogZeitfenster zeitfenster,
      Widget zeitraumAuswahl,
      ValueChanged<LogAusschnitt> onAusschnitt,
    );

/// Zeitpunkt und Fehlerstatus eines Eintrags, fuer Zaehler und Zeitraum.
class LogEintragInfo {
  const LogEintragInfo(this.zeitpunkt, {this.fehler = false});

  final DateTime zeitpunkt;
  final bool fehler;
}

/// Ein Log mit allem, was die Seite zum Lesen, Zaehlen, Anzeigen und
/// Loeschen braucht.
class LogQuelle {
  const LogQuelle({
    required this.titelKey,
    required this.heuteKey,
    required this.dateiKennung,
    required this.lesen,
    required this.loeschen,
    required this.eintraege,
    required this.ansicht,
  });

  factory LogQuelle.app(LoggerService logger) => LogQuelle(
    titelKey: 'debug_logs_app_title',
    heuteKey: 'debug_logs_app_today',
    dateiKennung: 'app',
    lesen: () => logger.readLogs(),
    loeschen: logger.clearAllLogs,
    eintraege: (content) => [
      for (final entry in AppLogEntry.parseAll(content))
        LogEintragInfo(entry.timestamp, fehler: entry.level == 'error'),
    ],
    ansicht: (content, zeitfenster, zeitraumAuswahl, onAusschnitt) =>
        AppLogView(
          content: content,
          zeitfenster: zeitfenster,
          zeitraumAuswahl: zeitraumAuswahl,
          onAusschnitt: onAusschnitt,
        ),
  );

  factory LogQuelle.traffic(HitobitoTrafficLogService service) => LogQuelle(
    titelKey: 'debug_logs_traffic_title',
    heuteKey: 'debug_logs_traffic_today',
    dateiKennung: 'traffic',
    lesen: () => service.readLogs(),
    loeschen: service.clearAllLogs,
    eintraege: (content) => [
      for (final line in content.split('\n'))
        if (HitobitoTrafficLogEntry.tryParse(line) case final entry?)
          LogEintragInfo(entry.timestamp, fehler: entry.isError),
    ],
    ansicht: (content, zeitfenster, zeitraumAuswahl, onAusschnitt) =>
        HitobitoTrafficLogView(
          content: content,
          zeitfenster: zeitfenster,
          zeitraumAuswahl: zeitraumAuswahl,
          onAusschnitt: onAusschnitt,
        ),
  );

  final String titelKey;
  final String heuteKey;
  final String dateiKennung;
  final Future<String> Function() lesen;
  final Future<void> Function() loeschen;
  final List<LogEintragInfo> Function(String content) eintraege;
  final LogAnsichtBuilder ansicht;
}

enum LogZeitraumVorlage { zehnMinuten, stunde, heute, alles, eigener }

/// Gemeinsame Seite fuer App- und Traffic-Log: Zeitraum (Standard Heute),
/// die Filter der jeweiligen Ansicht und ein Menue mit Teilen, Report Issue
/// und Loeschen. Teilen und Report Issue nehmen den sichtbaren Ausschnitt,
/// Loeschen entfernt alle Tage.
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({
    super.key,
    required this.quelle,
    this.nowProvider,
    this.teilen,
    this.melden,
    this.temporaeresVerzeichnis,
    this.onAktion,
  });

  final LogQuelle quelle;
  final DateTime Function()? nowProvider;

  /// Ersetzt den System-Teilen-Dialog, etwa in Tests.
  final Future<void> Function(File datei, Rect? anker)? teilen;

  /// Ersetzt den Mail-Versand, etwa in Tests.
  final Future<void> Function(File datei)? melden;
  final Future<Directory> Function()? temporaeresVerzeichnis;
  final void Function(String aktion)? onAktion;

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  final GlobalKey _menueKey = GlobalKey();
  String? _content;
  List<LogEintragInfo> _infos = const <LogEintragInfo>[];
  LogZeitraumVorlage _vorlage = LogZeitraumVorlage.heute;
  LogZeitfenster _eigenes = LogZeitfenster.alles;
  LogAusschnitt _ausschnitt = LogAusschnitt.leer;

  DateTime get _jetzt => (widget.nowProvider ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final content = await widget.quelle.lesen();
    if (!mounted) {
      return;
    }
    setState(() {
      _content = content;
      _infos = widget.quelle.eintraege(content);
    });
  }

  LogZeitfenster _fensterFuer(LogZeitraumVorlage vorlage) {
    final jetzt = _jetzt;
    return switch (vorlage) {
      LogZeitraumVorlage.zehnMinuten => LogZeitfenster(
        von: jetzt.subtract(const Duration(minutes: 10)),
      ),
      LogZeitraumVorlage.stunde => LogZeitfenster(
        von: jetzt.subtract(const Duration(hours: 1)),
      ),
      LogZeitraumVorlage.heute => LogZeitfenster(
        von: DateTime(jetzt.year, jetzt.month, jetzt.day),
      ),
      LogZeitraumVorlage.alles => LogZeitfenster.alles,
      LogZeitraumVorlage.eigener => _eigenes,
    };
  }

  String _vorlageText(AppLocalizations t, LogZeitraumVorlage vorlage) {
    return switch (vorlage) {
      LogZeitraumVorlage.zehnMinuten => t.t('debug_logs_range_10min'),
      LogZeitraumVorlage.stunde => t.t('debug_logs_range_hour'),
      LogZeitraumVorlage.heute => t.t('debug_logs_range_today'),
      LogZeitraumVorlage.alles => t.t('debug_logs_range_all'),
      LogZeitraumVorlage.eigener => _eigenerText(),
    };
  }

  String _eigenerText() {
    final von = _eigenes.von;
    final bis = _eigenes.bis;
    if (von == null || bis == null) {
      return '';
    }
    final format = DateFormat('dd.MM. HH:mm');
    final gleicherTag =
        von.year == bis.year && von.month == bis.month && von.day == bis.day;
    return gleicherTag
        ? '${format.format(von)}–${DateFormat('HH:mm').format(bis)}'
        : '${format.format(von)}–${format.format(bis)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final content = _content;
    final zeitraumText = _vorlageText(t, _vorlage);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.t(widget.quelle.titelKey)),
            Text(
              '${t.t('debug_logs_entries', {'count': _ausschnitt.eintraege})} · $zeitraumText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [_menue(t, zeitraumText)],
      ),
      body: content == null
          ? const Center(child: CircularProgressIndicator())
          : widget.quelle.ansicht(
              content,
              _fensterFuer(_vorlage),
              ActionChip(
                key: const Key('log_range_chip'),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(zeitraumText),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
                onPressed: _zeitraumWaehlen,
              ),
              (ausschnitt) => setState(() => _ausschnitt = ausschnitt),
            ),
    );
  }

  Widget _menue(AppLocalizations t, String zeitraumText) {
    final hatAusschnitt = _ausschnitt.eintraege > 0;
    final hinweis = [
      t.t('debug_logs_entries', {'count': _ausschnitt.eintraege}),
      zeitraumText,
      ..._ausschnitt.filter,
    ].join(' · ');
    PopupMenuItem<String> eintrag({
      required String wert,
      required IconData icon,
      required String titel,
      required String untertitel,
      bool aktiv = true,
      bool rot = false,
    }) {
      final farbe = rot ? Theme.of(context).colorScheme.error : null;
      return PopupMenuItem<String>(
        key: Key('log_menu_$wert'),
        value: wert,
        enabled: aktiv,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: farbe),
          title: Text(titel, style: TextStyle(color: farbe)),
          subtitle: Text(untertitel),
        ),
      );
    }

    return PopupMenuButton<String>(
      key: _menueKey,
      tooltip: t.t('debug_logs_menu'),
      onSelected: (wert) => switch (wert) {
        'teilen' => _teilen(),
        'melden' => _melden(),
        _ => _loeschen(),
      },
      itemBuilder: (context) => [
        eintrag(
          wert: 'teilen',
          icon: Icons.adaptive.share,
          titel: t.t('debug_logs_share'),
          untertitel: hinweis,
          aktiv: hatAusschnitt,
        ),
        eintrag(
          wert: 'melden',
          icon: Icons.mail_outline,
          titel: t.t('debug_logs_report'),
          untertitel: t.t('debug_logs_report_hint'),
          aktiv: hatAusschnitt,
        ),
        eintrag(
          wert: 'loeschen',
          icon: Icons.delete_outline,
          titel: t.t('debug_logs_delete'),
          untertitel: t.t('debug_logs_delete_hint'),
          rot: true,
        ),
      ],
    );
  }

  Future<void> _zeitraumWaehlen() async {
    final t = AppLocalizations.of(context);
    final gewaehlt = await showModalBottomSheet<LogZeitraumVorlage>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  t.t('debug_logs_range_title'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final vorlage in LogZeitraumVorlage.values)
                ListTile(
                  key: Key('log_range_${vorlage.name}'),
                  leading: Icon(
                    vorlage == _vorlage
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: vorlage == _vorlage
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    vorlage == LogZeitraumVorlage.eigener
                        ? t.t('debug_logs_range_custom')
                        : _vorlageText(t, vorlage),
                  ),
                  trailing: vorlage == LogZeitraumVorlage.eigener
                      ? null
                      : Text(
                          '${_anzahlIn(_fensterFuer(vorlage))}',
                          style: theme.textTheme.bodySmall,
                        ),
                  onTap: () => Navigator.of(context).pop(vorlage),
                ),
            ],
          ),
        );
      },
    );
    if (gewaehlt == null || !mounted) {
      return;
    }
    if (gewaehlt == LogZeitraumVorlage.eigener) {
      await _vonBisWaehlen();
      return;
    }
    setState(() => _vorlage = gewaehlt);
  }

  int _anzahlIn(LogZeitfenster fenster) =>
      _infos.where((info) => fenster.enthaelt(info.zeitpunkt)).length;

  Future<void> _vonBisWaehlen() async {
    final t = AppLocalizations.of(context);
    final jetzt = _jetzt;
    var von =
        _fensterFuer(_vorlage).von ??
        (_infos.isEmpty
            ? DateTime(jetzt.year, jetzt.month, jetzt.day)
            : _infos.first.zeitpunkt);
    var bis = _fensterFuer(_vorlage).bis ?? jetzt;
    final ergebnis = await showModalBottomSheet<LogZeitfenster>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<DateTime?> waehle(DateTime start) async {
            final datum = await showDatePicker(
              context: context,
              initialDate: start,
              firstDate: jetzt.subtract(const Duration(days: 365)),
              lastDate: jetzt.add(const Duration(days: 1)),
            );
            if (datum == null || !context.mounted) {
              return null;
            }
            final zeit = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(start),
            );
            if (zeit == null) {
              return null;
            }
            return DateTime(
              datum.year,
              datum.month,
              datum.day,
              zeit.hour,
              zeit.minute,
            );
          }

          Widget zeile(String label, DateTime wert, String key, bool istVon) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 48, child: Text(label)),
                  Expanded(
                    child: OutlinedButton(
                      key: Key(key),
                      onPressed: () async {
                        final neu = await waehle(wert);
                        if (neu != null) {
                          setSheetState(() {
                            if (istVon) {
                              von = neu;
                            } else {
                              bis = neu;
                            }
                          });
                        }
                      },
                      child: Text(DateFormat('dd.MM.yyyy  HH:mm').format(wert)),
                    ),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.t('debug_logs_range_custom'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  zeile(
                    t.t('debug_logs_range_from'),
                    von,
                    'log_range_from',
                    true,
                  ),
                  zeile(t.t('debug_logs_range_to'), bis, 'log_range_to', false),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('log_range_apply'),
                    onPressed: () => Navigator.of(context).pop(
                      von.isAfter(bis)
                          ? LogZeitfenster(von: bis, bis: von)
                          : LogZeitfenster(von: von, bis: bis),
                    ),
                    child: Text(t.t('debug_logs_range_apply')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.t('debug_logs_range_cancel')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ergebnis == null || !mounted) {
      return;
    }
    setState(() {
      _eigenes = ergebnis;
      _vorlage = LogZeitraumVorlage.eigener;
    });
  }

  Future<File> _ausschnittDatei() async {
    final verzeichnis = await TeilenOrdner.verzeichnis(
      temp: widget.temporaeresVerzeichnis,
    );
    final stempel = DateFormat('yyyy-MM-dd_HHmm').format(_jetzt);
    final datei = File(
      '${verzeichnis.path}/nami-${widget.quelle.dateiKennung}-log_$stempel.log',
    );
    await datei.writeAsString('${_ausschnitt.zeilen.join('\n')}\n');
    return datei;
  }

  Future<void> _teilen() async {
    widget.onAktion?.call('share_logs');
    final datei = await _ausschnittDatei();
    final box = _menueKey.currentContext?.findRenderObject() as RenderBox?;
    final anker = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    if (!mounted) {
      return;
    }
    final t = AppLocalizations.of(context);
    final teilen =
        widget.teilen ??
        (File datei, Rect? anker) => SharePlus.instance.share(
          ShareParams(
            files: [XFile(datei.path)],
            subject: t.t('debug_logs_email_subject'),
            sharePositionOrigin: anker,
          ),
        );
    await teilen(datei, anker);
  }

  Future<void> _melden() async {
    widget.onAktion?.call('report_issue');
    final datei = await _ausschnittDatei();
    if (!mounted) {
      return;
    }
    final t = AppLocalizations.of(context);
    final melden =
        widget.melden ??
        (File datei) async {
          try {
            await FlutterEmailSender.send(
              Email(
                body: t.t('debug_logs_email_body'),
                attachmentPaths: [datei.path],
                subject: t.t('debug_logs_email_subject'),
                recipients: const [logReportRecipient],
              ),
            );
          } catch (_) {}
        };
    await melden(datei);
  }

  Future<void> _loeschen() async {
    final t = AppLocalizations.of(context);
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t.t('debug_logs_delete_title', {'name': t.t(widget.quelle.titelKey)}),
        ),
        content: Text(t.t('debug_logs_delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.t('debug_logs_delete_cancel')),
          ),
          TextButton(
            key: const Key('log_delete_confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.t('debug_logs_delete_confirm')),
          ),
        ],
      ),
    );
    if (bestaetigt != true || !mounted) {
      return;
    }
    widget.onAktion?.call('delete_logs');
    await widget.quelle.loeschen();
    await _laden();
    if (!mounted) {
      return;
    }
    AppSnackbar.show(
      context,
      message: t.t('debug_logs_deleted'),
      type: AppSnackbarType.success,
    );
  }
}
