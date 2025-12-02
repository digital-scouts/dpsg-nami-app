import 'package:flutter/material.dart';
import 'package:nami/domain/stufenwechsel/stufenwechsel_info.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

class StufenwechselEmpfehlung extends StatelessWidget {
  final List<StufenwechselInfo> infos;
  final Stufe stufe;
  final void Function(String id)? onTap;

  const StufenwechselEmpfehlung({
    super.key,
    required this.infos,
    required this.stufe,
    this.onTap,
  });

  String _formatAlter(Duration d) {
    final jahre = (d.inDays / 365).floor();
    final restTage = d.inDays - jahre * 365;
    final monate = (restTage / 30).floor();
    return '${jahre}J ${monate}M';
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
    final sorted = [...infos]
      ..sort((a, b) => b.alterZumStichtag.compareTo(a.alterZumStichtag));

    return DataTable(
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Alter')),
        DataColumn(label: Text('Wechsel')),
      ],
      rows: sorted.map((info) {
        final name = info.vorname;
        final alter = _formatAlter(info.alterZumStichtag);
        final wechsel = _formatWechsel(info.wechselzeitraum);
        return DataRow(
          cells: [
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
          ],
        );
      }).toList(),
    );
  }
}
