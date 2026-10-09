import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../services/logger_service.dart';
import '../theme/status_farben.dart';
import 'log_ausschnitt.dart';

/// Lesbare Ansicht des App-Logs: neueste Eintraege oben, nach Tagen
/// getrennt, Warnungen und Fehler farbig markiert. `key=value`-Paare stehen
/// als Text mit grauen Schluesseln, Folgezeilen (Stacktraces) sind
/// eingeklappt.
class AppLogView extends StatefulWidget {
  const AppLogView({
    super.key,
    required this.content,
    this.nowProvider,
    this.zeitfenster = LogZeitfenster.alles,
    this.zeitraumAuswahl,
    this.onAusschnitt,
  });

  final String content;

  /// Nur Eintraege in diesem Zeitfenster sind sichtbar.
  final LogZeitfenster zeitfenster;

  /// Bedienelement fuer den Zeitraum, rechts neben der Suche.
  final Widget? zeitraumAuswahl;

  /// Meldet den sichtbaren Ausschnitt, sobald er sich aendert.
  final ValueChanged<LogAusschnitt>? onAusschnitt;

  /// Fuer „Heute“ und „Gestern“; in Tests fest.
  final DateTime Function()? nowProvider;

  /// Haeufige Routinezeilen, die sich per Filter ausblenden lassen.
  static const Set<String> routineServices = <String>{'nav', 'http'};

  @override
  State<AppLogView> createState() => _AppLogViewState();
}

class _AppLogViewState extends State<AppLogView> {
  late List<AppLogEntry> _entries;
  bool _nurProbleme = false;
  bool _ohneRoutine = false;
  String _suche = '';
  final Set<int> _offen = <int>{};
  LogAusschnitt? _gemeldet;

  @override
  void initState() {
    super.initState();
    _entries = _parse(widget.content);
  }

  @override
  void didUpdateWidget(covariant AppLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _entries = _parse(widget.content);
      _offen.clear();
    }
  }

  static List<AppLogEntry> _parse(String content) =>
      AppLogEntry.parseAll(content).reversed.toList(growable: false);

  bool _passt(AppLogEntry entry) {
    if (!widget.zeitfenster.enthaelt(entry.timestamp)) {
      return false;
    }
    if (_nurProbleme && !entry.isProblem) {
      return false;
    }
    if (_ohneRoutine && AppLogView.routineServices.contains(entry.service)) {
      return false;
    }
    if (_suche.isEmpty) {
      return true;
    }
    final suche = _suche.toLowerCase();
    return entry.service.toLowerCase().contains(suche) ||
        entry.message.toLowerCase().contains(suche) ||
        entry.extraLines.any((line) => line.toLowerCase().contains(suche));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final imZeitfenster = _entries
        .where((entry) => widget.zeitfenster.enthaelt(entry.timestamp))
        .toList(growable: false);
    final problemAnzahl = imZeitfenster
        .where((entry) => entry.isProblem)
        .length;

    final items = <Object>[];
    DateTime? tag;
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (!_passt(entry)) {
        continue;
      }
      final ts = entry.timestamp;
      final eintragTag = DateTime(ts.year, ts.month, ts.day);
      if (eintragTag != tag) {
        tag = eintragTag;
        items.add(eintragTag);
      }
      items.add(index);
    }
    _melde(t, items);

    final kopf = <Widget>[
      Row(
        children: [
          Expanded(
            child: TextField(
              // Eingaben koennen Mitgliederdaten enthalten; die Tastatur soll sie
              // nicht lernen.
              enableIMEPersonalizedLearning: false,
              key: const Key('applog_search'),
              decoration: InputDecoration(
                hintText: t.t('debug_applog_search'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _suche = value.trim()),
            ),
          ),
          if (widget.zeitraumAuswahl != null) ...[
            const SizedBox(width: 8),
            widget.zeitraumAuswahl!,
          ],
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            key: const Key('applog_filter_all'),
            label: Text(
              '${t.t('debug_applog_filter_all')} ${imZeitfenster.length}',
            ),
            selected: !_nurProbleme,
            onSelected: (_) => setState(() => _nurProbleme = false),
          ),
          ChoiceChip(
            key: const Key('applog_filter_problems'),
            label: Text(
              '${t.t('debug_applog_filter_problems')} $problemAnzahl',
            ),
            selected: _nurProbleme,
            onSelected: (_) => setState(() => _nurProbleme = true),
          ),
          FilterChip(
            key: const Key('applog_filter_hide_routine'),
            label: Text(t.t('debug_applog_filter_hide_routine')),
            selected: _ohneRoutine,
            onSelected: (value) => setState(() => _ohneRoutine = value),
          ),
        ],
      ),
    ];

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          ...kopf,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              t.t(
                imZeitfenster.isEmpty
                    ? 'debug_applog_empty'
                    : 'debug_applog_empty_filtered',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final heute = _tagVon((widget.nowProvider ?? DateTime.now)());
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: items.length + 1,
      itemBuilder: (context, position) {
        if (position == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: kopf,
          );
        }
        final item = items[position - 1];
        if (item is DateTime) {
          return _DatumsTrenner(tag: item, heute: heute);
        }
        final index = item as int;
        final istErster = items[position - 2] is DateTime;
        final istLetzter =
            position == items.length || items[position] is DateTime;
        return _AppLogTile(
          entry: _entries[index],
          offen: _offen.contains(index),
          oben: istErster,
          unten: istLetzter,
          onToggle: () => setState(() {
            if (!_offen.remove(index)) {
              _offen.add(index);
            }
          }),
        );
      },
    );
  }

  /// Meldet den sichtbaren Ausschnitt nach dem Frame, wenn er sich
  /// geaendert hat; `items` ist neueste zuerst.
  void _melde(AppLocalizations t, List<Object> items) {
    final callback = widget.onAusschnitt;
    if (callback == null) {
      return;
    }
    final sichtbar = items.whereType<int>().toList(growable: false).reversed;
    final ausschnitt = LogAusschnitt(
      zeilen: [for (final index in sichtbar) ..._entries[index].rawLines],
      eintraege: sichtbar.length,
      filter: [
        if (_nurProbleme) t.t('debug_applog_filter_problems'),
        if (_ohneRoutine) t.t('debug_applog_filter_hide_routine'),
        if (_suche.isNotEmpty) '„$_suche“',
      ],
    );
    if (ausschnitt == _gemeldet) {
      return;
    }
    _gemeldet = ausschnitt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        callback(ausschnitt);
      }
    });
  }

  static DateTime _tagVon(DateTime ts) => DateTime(ts.year, ts.month, ts.day);
}

class _DatumsTrenner extends StatelessWidget {
  const _DatumsTrenner({required this.tag, required this.heute});

  final DateTime tag;
  final DateTime heute;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final abstand = heute.difference(tag).inDays;
    final text = switch (abstand) {
      0 => t.t('debug_applog_today'),
      1 => t.t('debug_applog_yesterday'),
      _ => DateFormat('dd.MM.yyyy').format(tag),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _AppLogTile extends StatelessWidget {
  const _AppLogTile({
    required this.entry,
    required this.offen,
    required this.oben,
    required this.unten,
    required this.onToggle,
  });

  static const TextStyle _mono = TextStyle(fontFamily: 'monospace');

  final AppLogEntry entry;
  final bool offen;
  final bool oben;
  final bool unten;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final farben = StatusFarben.of(context);
    final levelFarbe = switch (entry.level) {
      'error' => farben.kritisch,
      'warn' => farben.warnung,
      _ => null,
    };
    final parts = entry.parts;
    final fehler = parts.fields.where((field) => field.key == 'error');
    final felder = parts.fields.where((field) => field.key != 'error');
    const radius = Radius.circular(16);

    return Container(
      decoration: BoxDecoration(
        color: levelFarbe == farben.kritisch
            ? Color.alphaBlend(
                farben.kritisch.withValues(alpha: 0.05),
                scheme.surface,
              )
            : scheme.surface,
        borderRadius: BorderRadius.vertical(
          top: oben ? radius : Radius.zero,
          bottom: unten ? radius : Radius.zero,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: levelFarbe ?? Colors.transparent, width: 3),
            bottom: unten
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (entry.level != 'info') ...[
                  _LevelBadge(
                    text: t.t('debug_applog_level_${entry.level}'),
                    farbe: levelFarbe ?? scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _BereichPill(service: entry.service),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('HH:mm:ss').format(entry.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (parts.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(parts.text, style: theme.textTheme.bodyMedium),
              ),
            if (felder.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (final feld in felder) ...[
                        TextSpan(
                          text: '${feld.key}=',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        TextSpan(text: '${feld.value}  '),
                      ],
                    ],
                  ),
                  style: _mono.copyWith(fontSize: 12, color: scheme.onSurface),
                ),
              ),
            for (final feld in fehler)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  feld.value,
                  style: _mono.copyWith(fontSize: 12, color: scheme.error),
                ),
              ),
            if (entry.extraLines.isNotEmpty) ...[
              if (offen)
                Container(
                  key: const Key('applog_details'),
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    entry.extraLines.join('\n'),
                    style: _mono.copyWith(
                      fontSize: 11.5,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onToggle,
                child: Text(
                  offen
                      ? t.t('debug_applog_stack_hide')
                      : t.t('debug_applog_stack_show', {
                          'count': entry.extraLines.length,
                        }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.text, required this.farbe});

  final String text;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: farbe,
        ),
      ),
    );
  }
}

class _BereichPill extends StatelessWidget {
  const _BereichPill({required this.service});

  final String service;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        service,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
