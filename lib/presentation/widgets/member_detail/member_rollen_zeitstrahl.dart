import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/taetigkeit/role_derivation.dart';
import '../../../domain/taetigkeit/roles.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../section_header.dart';
import 'rollen_symbol.dart';

/// Rollen nach Beginnjahr auf einer Linie. Aktive Rollen liegen auf
/// getoentem Grund, Geplantes steht oben. Rollen anderer Layer sind
/// standardmaessig ausgeblendet; ein Hinweis am Ende blendet sie ein.
class MemberRollenZeitstrahl extends StatefulWidget {
  const MemberRollenZeitstrahl({
    super.key,
    required this.rollen,
    required this.heute,
    this.eintritt,
    this.aktiverLayerName,
  });

  final List<Role> rollen;
  final DateTime heute;
  final DateTime? eintritt;

  /// Name des aktiven Layers; ohne ihn gibt es keinen Layer-Filter.
  final String? aktiverLayerName;

  /// Ab so vielen Jahren werden aeltere Jahre eingeklappt.
  static const int sichtbareJahre = 5;

  @override
  State<MemberRollenZeitstrahl> createState() => _MemberRollenZeitstrahlState();
}

class _MemberRollenZeitstrahlState extends State<MemberRollenZeitstrahl> {
  bool _nurAktiverLayer = true;
  bool _offen = false;

  bool _istFremd(Role rolle) {
    final aktiver = widget.aktiverLayerName;
    final layer = rolle.layerName;
    return aktiver != null && layer != null && layer != aktiver;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fremd = widget.rollen.where(_istFremd).toList(growable: false);
    final gefiltert = _nurAktiverLayer && fremd.isNotEmpty;
    final rollen = gefiltert
        ? widget.rollen.where((r) => !_istFremd(r)).toList(growable: false)
        : widget.rollen;

    final geplant = rollen.where((r) => r.start.isAfter(widget.heute)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final begonnen = <int, List<Role>>{};
    for (final rolle in rollen.where((r) => !r.start.isAfter(widget.heute))) {
      begonnen.putIfAbsent(_startJahr(rolle), () => <Role>[]).add(rolle);
    }
    for (final liste in begonnen.values) {
      liste.sort((a, b) => b.start.compareTo(a.start));
    }
    final jahre = begonnen.keys.toList()..sort((a, b) => b.compareTo(a));
    final sichtbar = _offen
        ? jahre
        : jahre.take(MemberRollenZeitstrahl.sichtbareJahre).toList();
    final versteckteJahre = jahre.length - sichtbar.length;

    final zeilen = <Widget>[
      if (geplant.isNotEmpty)
        _JahrZeile(
          beschriftung: t.t('rollen_geplant'),
          geplant: true,
          erste: true,
          letzte: false,
          kinder: [for (final r in geplant) _eintrag(r, t)],
        ),
      for (var i = 0; i < sichtbar.length; i++)
        _JahrZeile(
          beschriftung: '${sichtbar[i]}',
          erste: geplant.isEmpty && i == 0,
          letzte: false,
          kinder: [for (final r in begonnen[sichtbar[i]]!) _eintrag(r, t)],
        ),
      if (versteckteJahre > 0 || (_offen && jahre.length > sichtbar.length))
        _AufklappZeile(
          text: versteckteJahre == 1
              ? t.t('rollen_frueheres_jahr')
              : t.t('rollen_fruehere_jahre', {'n': versteckteJahre}),
          onTap: () => setState(() => _offen = true),
        ),
      if (_offen && jahre.length > MemberRollenZeitstrahl.sichtbareJahre)
        _AufklappZeile(
          text: t.t('rollen_weniger'),
          offen: true,
          onTap: () => setState(() => _offen = false),
        ),
      if (widget.eintritt != null)
        _JahrZeile(
          beschriftung: '${widget.eintritt!.year}',
          erste: geplant.isEmpty && sichtbar.isEmpty,
          letzte: true,
          kinder: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                t.t('rollen_eintritt'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            DpsgSectionHeader(label: t.t('rollen_titel')),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                gefiltert
                    ? '${rollen.length} ${t.t('rollen_ausgeblendet', {'n': fremd.length})}'
                    : '${rollen.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rollen.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      t.t('rollen_keine'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ...zeilen,
                if (fremd.isNotEmpty)
                  _filterHinweis(t, theme, fremd, gefiltert),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _startJahr(Role rolle) {
    final start = rolle.startOn ?? rolle.createdAt ?? widget.eintritt;
    return start?.year ?? widget.heute.year;
  }

  Widget _filterHinweis(
    AppLocalizations t,
    ThemeData theme,
    List<Role> fremd,
    bool gefiltert,
  ) {
    final ebenen = fremd
        .map((r) => r.layerName!.split(' ').first)
        .toSet()
        .join(t.t('rollen_und'));
    final text = gefiltert
        ? (fremd.length == 1
              ? t.t('rollen_filter_ausgeblendet_eine', {'ebenen': ebenen})
              : t.t('rollen_filter_ausgeblendet', {
                  'n': fremd.length,
                  'ebenen': ebenen,
                }))
        : t.t('rollen_filter_alle');
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 16,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          TextButton(
            key: const Key('rollen-layer-filter'),
            onPressed: () =>
                setState(() => _nurAktiverLayer = !_nurAktiverLayer),
            child: Text(
              gefiltert
                  ? t.t('rollen_filter_anzeigen')
                  : t.t('rollen_filter_nur', {
                      'layer': widget.aktiverLayerName,
                    }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eintrag(Role rolle, AppLocalizations t) {
    return _RollenEintrag(
      rolle: rolle,
      aktiv: rolle.isActiveAt(widget.heute),
      geplant: rolle.start.isAfter(widget.heute),
      fremd: _istFremd(rolle),
      zeitraum: _zeitraum(rolle, t),
    );
  }

  String _zeitraum(Role rolle, AppLocalizations t) {
    final sprache = Localizations.localeOf(context).languageCode;
    String monat(DateTime d) => DateFormat('MMM yyyy', sprache).format(d);
    final start = rolle.startOn ?? rolle.createdAt;
    if (rolle.start.isAfter(widget.heute)) {
      return t.t('rollen_ab', {'datum': monat(rolle.start)});
    }
    if (rolle.isActiveAt(widget.heute)) {
      return start == null
          ? t.t('rollen_aktiv')
          : t.t('rollen_aktiv_seit', {'datum': monat(start)});
    }
    final ende = rolle.ende;
    if (ende == null) {
      return '';
    }
    if (start != null && start.year == ende.year) {
      final nurMonat = DateFormat('MMM', sprache).format(start);
      return t.t('rollen_zeitraum', {'von': nurMonat, 'bis': monat(ende)});
    }
    return t.t('rollen_zeitraum', {
      'von': start == null ? '?' : monat(start),
      'bis': monat(ende),
    });
  }
}

/// Titel einer Rolle: Stufenname fuer Mitglieder, „Leiter*in · Wö“ fuer
/// Leitungen, sonst die Bezeichnung.
String rollenTitel(Role rolle) {
  final stufe = rolle.stufe;
  final label = rolle.resolvedLabel ?? '';
  if (rolle.art == RoleCategory.mitglied && stufe != Stufe.leitung) {
    return stufe.displayName;
  }
  if (rolle.art == RoleCategory.leitung && stufe != Stufe.leitung) {
    return '$label · ${stufe.shortDisplayName}';
  }
  return label;
}

class _RollenEintrag extends StatelessWidget {
  const _RollenEintrag({
    required this.rolle,
    required this.aktiv,
    required this.geplant,
    required this.fremd,
    required this.zeitraum,
  });

  final Role rolle;
  final bool aktiv;
  final bool geplant;
  final bool fremd;
  final String zeitraum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unterzeile = [
      if (rolle.groupName != null) rolle.groupName!,
      if (zeitraum.isNotEmpty) zeitraum,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: aktiv
          ? BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Row(
        children: [
          RollenSymbol(rolle: rolle),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rollenTitel(rolle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: aktiv || geplant
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (fremd) ...[
                      const SizedBox(width: 6),
                      _LayerChip(name: rolle.layerName!),
                    ],
                  ],
                ),
                if (unterzeile.isNotEmpty)
                  Text(
                    unterzeile,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: geplant
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      fontWeight: geplant ? FontWeight.w600 : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerChip extends StatelessWidget {
  const _LayerChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        name.split(' ').first,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _JahrZeile extends StatelessWidget {
  const _JahrZeile({
    required this.beschriftung,
    required this.kinder,
    required this.erste,
    required this.letzte,
    this.geplant = false,
  });

  final String beschriftung;
  final List<Widget> kinder;
  final bool erste;
  final bool letzte;
  final bool geplant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                beschriftung,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: geplant
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 14,
            child: CustomPaint(
              painter: _LiniePainter(
                farbe: theme.colorScheme.outline,
                punkt: theme.colorScheme.primary,
                flaeche: theme.colorScheme.surface,
                erste: erste,
                letzte: letzte,
                gestrichelt: geplant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: kinder,
            ),
          ),
        ],
      ),
    );
  }
}

class _AufklappZeile extends StatelessWidget {
  const _AufklappZeile({
    required this.text,
    required this.onTap,
    this.offen = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool offen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 70),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Icon(
                offen ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiniePainter extends CustomPainter {
  _LiniePainter({
    required this.farbe,
    required this.punkt,
    required this.flaeche,
    required this.erste,
    required this.letzte,
    required this.gestrichelt,
  });

  final Color farbe;
  final Color punkt;
  final Color flaeche;
  final bool erste;
  final bool letzte;
  final bool gestrichelt;

  static const double _punktY = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final linie = Paint()
      ..color = farbe
      ..strokeWidth = 2;
    final oben = erste ? _punktY : 0.0;
    final unten = letzte ? _punktY : size.height;
    if (gestrichelt) {
      for (var y = oben; y < unten; y += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, (y + 4).clamp(0, unten)),
          linie,
        );
      }
    } else if (unten > oben) {
      canvas.drawLine(Offset(x, oben), Offset(x, unten), linie);
    }
    canvas.drawCircle(Offset(x, _punktY), 5, Paint()..color = flaeche);
    canvas.drawCircle(
      Offset(x, _punktY),
      5,
      Paint()
        ..color = punkt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _LiniePainter oldDelegate) =>
      oldDelegate.erste != erste ||
      oldDelegate.letzte != letzte ||
      oldDelegate.gestrichelt != gestrichelt ||
      oldDelegate.farbe != farbe;
}
