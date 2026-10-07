import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../services/hitobito_traffic_log_service.dart';
import '../notifications/app_snackbar.dart';
import '../theme/status_farben.dart';

/// Lesbare Ansicht des Hitobito-Traffic-Logs: neueste Anfrage oben, Status
/// als farbiges Kennzeichen, lange Feldlisten eingeklappt. Antippen zeigt die
/// vollstaendige URI. Zeilen in unbekanntem Format erscheinen als Klartext.
class HitobitoTrafficLogView extends StatefulWidget {
  const HitobitoTrafficLogView({super.key, required this.content});

  final String content;

  @override
  State<HitobitoTrafficLogView> createState() => _HitobitoTrafficLogViewState();
}

class _HitobitoTrafficLogViewState extends State<HitobitoTrafficLogView> {
  late List<_TrafficRow> _rows;
  bool _nurFehler = false;
  final Set<int> _offen = <int>{};

  @override
  void initState() {
    super.initState();
    _rows = _parse(widget.content);
  }

  @override
  void didUpdateWidget(covariant HitobitoTrafficLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _rows = _parse(widget.content);
      _offen.clear();
    }
  }

  static List<_TrafficRow> _parse(String content) {
    final lines = content
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    return <_TrafficRow>[
      for (var index = lines.length - 1; index >= 0; index--)
        _TrafficRow(
          index: index,
          raw: lines[index],
          entry: HitobitoTrafficLogEntry.tryParse(lines[index]),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final anfragen = _rows.where((row) => row.entry != null).length;
    final fehlerAnzahl = _rows.where((row) => row.isError).length;
    final sichtbar = _nurFehler
        ? _rows.where((row) => row.isError).toList(growable: false)
        : _rows;
    final mehrereTage =
        _rows
            .map((row) => row.entry?.timestamp)
            .whereType<DateTime>()
            .map((ts) => DateTime(ts.year, ts.month, ts.day))
            .toSet()
            .length >
        1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('traffic_filter_all'),
              label: Text('${t.t('debug_traffic_filter_all')} $anfragen'),
              selected: !_nurFehler,
              onSelected: (_) => setState(() => _nurFehler = false),
            ),
            ChoiceChip(
              key: const Key('traffic_filter_errors'),
              label: Text(
                '${t.t('debug_traffic_filter_errors')} $fehlerAnzahl',
              ),
              selected: _nurFehler,
              onSelected: (_) => setState(() => _nurFehler = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sichtbar.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              t.t(
                _nurFehler
                    ? 'debug_traffic_empty_errors'
                    : 'debug_traffic_empty',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < sichtbar.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  _TrafficRowTile(
                    row: sichtbar[i],
                    offen: _offen.contains(sichtbar[i].index),
                    mitDatum: mehrereTage,
                    onTap: sichtbar[i].entry == null
                        ? null
                        : () => setState(() {
                            final index = sichtbar[i].index;
                            if (!_offen.remove(index)) {
                              _offen.add(index);
                            }
                          }),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TrafficRow {
  const _TrafficRow({required this.index, required this.raw, this.entry});

  final int index;
  final String raw;
  final HitobitoTrafficLogEntry? entry;

  bool get isError => entry?.isError ?? false;
}

class _TrafficRowTile extends StatelessWidget {
  const _TrafficRowTile({
    required this.row,
    required this.offen,
    required this.mitDatum,
    this.onTap,
  });

  static const double _einzug = 52;
  static const TextStyle _mono = TextStyle(fontFamily: 'monospace');

  final _TrafficRow row;
  final bool offen;
  final bool mitDatum;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = row.entry;
    if (entry == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SelectableText(
          row.raw,
          style: _mono.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final t = AppLocalizations.of(context);
    final hinweis = _hinweis(t, entry);
    final parameter = entry.relevantQueryParameters;
    final versteckt = entry.hiddenQueryParameterCount;
    final zeit = DateFormat(
      mitDatum ? 'dd.MM. HH:mm:ss' : 'HH:mm:ss',
    ).format(entry.timestamp);

    return Material(
      color: offen
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(entry: entry),
                  const SizedBox(width: 10),
                  Text(
                    entry.method,
                    style: _mono.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: entry.method == 'GET'
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _QuellenPill(source: entry.source),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    zeit,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: _einzug, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.path, style: _mono.copyWith(fontSize: 13)),
                    if (parameter.isNotEmpty || versteckt > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: [
                            for (final p in parameter) _ParameterChip(text: p),
                            if (versteckt > 0)
                              Text(
                                t.t(
                                  versteckt == 1
                                      ? 'debug_traffic_hidden_field'
                                      : 'debug_traffic_hidden_fields',
                                  {'count': versteckt},
                                ),
                                style: _mono.copyWith(
                                  fontSize: 11.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (hinweis != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          hinweis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    if (offen) _Details(entry: entry),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _hinweis(AppLocalizations t, HitobitoTrafficLogEntry entry) {
    final code = entry.statusCode;
    if (code == null) {
      return t.t('debug_traffic_hint_exception', {
        'type': entry.errorType ?? '?',
      });
    }
    return switch (code) {
      401 => t.t('debug_traffic_hint_401'),
      403 => t.t('debug_traffic_hint_403'),
      404 => t.t('debug_traffic_hint_404'),
      422 => t.t('debug_traffic_hint_422'),
      429 => t.t('debug_traffic_hint_429'),
      >= 500 => t.t('debug_traffic_hint_5xx'),
      >= 400 => t.t('debug_traffic_hint_4xx'),
      _ => null,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.entry});

  final HitobitoTrafficLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final farben = StatusFarben.of(context);
    final code = entry.statusCode;
    final farbe = code == null || code >= 500
        ? farben.kritisch
        : code >= 400
        ? farben.warnung
        : farben.gut;
    return Container(
      key: Key('traffic_status_${code ?? 'exc'}'),
      constraints: const BoxConstraints(minWidth: 42),
      height: 22,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        code?.toString() ?? 'EXC',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: farbe,
        ),
      ),
    );
  }
}

class _QuellenPill extends StatelessWidget {
  const _QuellenPill({required this.source});

  final String source;

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
        source,
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

class _ParameterChip extends StatelessWidget {
  const _ParameterChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.entry});

  final HitobitoTrafficLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5);
    final basis = entry.uri.split('?').first;
    return Container(
      key: const Key('traffic_details'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            ['${entry.method} $basis', ...entry.queryParameters].join('\n'),
            style: mono.copyWith(color: scheme.onSurface),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: entry.uri));
              if (!context.mounted) {
                return;
              }
              AppSnackbar.show(
                context,
                message: t.t('debug_traffic_uri_copied'),
                type: AppSnackbarType.success,
              );
            },
            child: Text(t.t('debug_traffic_copy_uri')),
          ),
        ],
      ),
    );
  }
}
