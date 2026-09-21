import 'package:flutter/material.dart';
import 'package:nami/domain/stufenwechsel/stufenwechsel_info.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/format/date_formatters.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';

class StufenwechselEmpfehlung extends StatelessWidget {
  final List<StufenwechselInfo> infos;
  final List<Stufe> stufen;
  final void Function(String id)? onTap;
  final DateTime stichtag;

  const StufenwechselEmpfehlung({
    super.key,
    required this.infos,
    required this.stufen,
    this.onTap,
    required this.stichtag,
  });
  String _formatAlter(BuildContext context, Duration d) {
    final jahre = (d.inDays / 365).floor();
    final restTage = d.inDays - jahre * 365;
    final monate = (restTage / 30).floor();
    return AppLocalizations.of(
      context,
    ).t('stufenwechsel_age_format', {'years': jahre, 'months': monate});
  }

  String _formatWechsel(Wechselzeitraum w) {
    final s = w.startJahr;
    final e = w.endJahr;
    if (s == null && e == null) return '-';
    if (s != null && e != null) {
      if (s == e) return '$s';
      // bei "2025-27": Kürze Endjahr auf zwei Ziffern, wenn gleicher Jahrhundert/ Jahrzehnt-Kontext
      final endShort = e % 100;
      return '$s-$endShort';
    }
    // Nur eines gesetzt
    return '${s ?? e}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Alle gewünschten Stufen zusammenführen und in einer Liste darstellen.
    final combined =
        infos.where((i) => i.stufe != null && stufen.contains(i.stufe)).toList()
          ..sort((a, b) => b.alterZumStichtag.compareTo(a.alterZumStichtag));

    if (combined.isEmpty) {
      final stufenText = stufen.isEmpty
          ? t.t('stufenwechsel_column_stage')
          : stufen.map((s) => s.shortDisplayName).join(', ');
      final datumText = DateFormatter.formatGermanShortDate(stichtag);
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          t.t('stufenwechsel_no_change', {
            'stages': stufenText,
            'date': datumText,
          }),
          textAlign: TextAlign.center,
        ),
      );
    }

    final showStufeCol = stufen.length > 1;

    final columns = <DataColumn>[
      if (showStufeCol)
        DataColumn(label: Text(t.t('stufenwechsel_column_stage'))),
      DataColumn(label: Text(t.t('stufenwechsel_column_name'))),
      DataColumn(label: Text(t.t('stufenwechsel_column_age'))),
      DataColumn(label: Text(t.t('stufenwechsel_column_change'))),
    ];

    return SizedBox(
      width: double.infinity,
      child: DataTable(
        columns: columns,
        rows: combined.map((info) {
          final name = info.vorname;
          final alter = _formatAlter(context, info.alterZumStichtag);
          final wechsel = _formatWechsel(info.wechselzeitraum);
          final cells = <DataCell>[];

          if (showStufeCol) {
            final stufe = info.stufe;
            final asset = stufe != null ? StufeVisuals.assetFor(stufe) : null;
            cells.add(
              DataCell(
                asset != null
                    ? Image.asset(
                        asset,
                        width: 35,
                        height: 28,
                        fit: BoxFit.contain,
                      )
                    : const SizedBox.shrink(),
                onTap: onTap == null ? null : () => onTap!(info.id),
              ),
            );
          }

          cells.addAll([
            DataCell(
              Text(name),
              onTap: onTap == null ? null : () => onTap!(info.id),
            ),
            DataCell(
              Text(alter),
              onTap: onTap == null ? null : () => onTap!(info.id),
            ),
            DataCell(
              Text(wechsel),
              onTap: onTap == null ? null : () => onTap!(info.id),
            ),
          ]);

          return DataRow(cells: cells);
        }).toList(),
      ),
    );
  }
}
