import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/veranstaltung/anmeldestatus.dart';
import '../../../domain/veranstaltung/veranstaltung.dart';
import '../../../l10n/app_localizations.dart';
import '../../model/veranstaltungen_model.dart';
import '../../notifications/app_snackbar.dart';
import '../../theme/status_farben.dart';
import '../../widgets/app_lesebreite.dart';
import '../../widgets/section_header.dart';
import '../../widgets/veranstaltungen/veranstaltung_kalender.dart';
import '../../widgets/veranstaltungen/veranstaltung_texte.dart';

/// Detail eines Kurses oder einer Veranstaltung (Entscheidung D2): Art und
/// Titel, Statusbanner, Aktionen als Pillen, danach Termine als Zeitstrahl
/// und die weiteren Angaben. Laedt Beschreibung, Kontakt und Leitung nach.
class VeranstaltungDetailPage extends StatefulWidget {
  const VeranstaltungDetailPage({
    super.key,
    required this.veranstaltung,
    this.eingebettet = false,
    this.kalenderEintragen = systemKalenderEintragen,
    this.webLink,
    this.veranstalter,
    this.heute,
  });

  final Veranstaltung veranstaltung;

  /// Rechte Spalte neben der Liste: ohne Zurueck-Pfeil.
  final bool eingebettet;
  final KalenderEintragen kalenderEintragen;

  /// Fuer Stories und Tests; sonst aus dem [VeranstaltungenModel].
  final Uri? webLink;
  final String? veranstalter;
  final DateTime? heute;

  @override
  State<VeranstaltungDetailPage> createState() =>
      _VeranstaltungDetailPageState();
}

class _VeranstaltungDetailPageState extends State<VeranstaltungDetailPage> {
  @override
  void initState() {
    super.initState();
    final model = context.read<VeranstaltungenModel?>();
    if (model != null) {
      unawaited(model.ladeDetail(widget.veranstaltung.id));
    }
  }

  Future<void> _kalender(Veranstaltung veranstaltung) async {
    final t = AppLocalizations.of(context);
    final termin = await waehleKalenderTermin(context, veranstaltung);
    if (termin == null || !mounted) {
      return;
    }
    var ok = false;
    try {
      ok = await widget.kalenderEintragen(veranstaltung, termin);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      AppSnackbar.show(
        context,
        message: t.t('veranstaltung_kalender_fehler'),
        type: AppSnackbarType.error,
      );
    }
  }

  Future<void> _web(Uri link) async {
    final t = AppLocalizations.of(context);
    var ok = false;
    try {
      ok = await launchUrl(link, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      AppSnackbar.show(
        context,
        message: t.t('veranstaltung_web_fehler'),
        type: AppSnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<VeranstaltungenModel?>();
    final veranstaltung =
        model?.detail(widget.veranstaltung.id) ?? widget.veranstaltung;
    final heute = widget.heute ?? model?.heute ?? DateTime.now();
    final webLink = widget.webLink ?? model?.webLink(veranstaltung);
    final veranstalter =
        widget.veranstalter ?? model?.veranstalter(veranstaltung);
    final zurueck =
        !widget.eingebettet && (ModalRoute.of(context)?.canPop ?? false);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppLesebreite(
          builder: (context, rand) => ListView(
            key: const Key('veranstaltung-detail'),
            padding: EdgeInsets.only(bottom: 24) + rand,
            children: [
              _Kopf(
                veranstaltung: veranstaltung,
                veranstalter: veranstalter,
                heute: heute,
                zurueck: zurueck,
                webLink: webLink,
                onWeb: webLink == null ? null : () => _web(webLink),
                onKalender: () => _kalender(veranstaltung),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _Abschnitte(
                  veranstaltung: veranstaltung,
                  veranstalter: veranstalter,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kopf extends StatelessWidget {
  const _Kopf({
    required this.veranstaltung,
    required this.veranstalter,
    required this.heute,
    required this.zurueck,
    required this.webLink,
    required this.onWeb,
    required this.onKalender,
  });

  final Veranstaltung veranstaltung;
  final String? veranstalter;
  final DateTime heute;
  final bool zurueck;
  final Uri? webLink;
  final VoidCallback? onWeb;
  final VoidCallback onKalender;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final texte = VeranstaltungTexte(context);
    final extern = veranstaltung.anmeldeLinkExtern != null;
    final unterzeile = [
      veranstalter,
      texte.zeitraum(veranstaltung),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.fromLTRB(16, zurueck ? 4 : 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (zurueck)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                alignment: Alignment.centerLeft,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          Text(
            texte.artMitKurzname(veranstaltung).toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: VeranstaltungFarben.art(context, veranstaltung.art),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            veranstaltung.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (unterzeile.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                unterzeile,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 14),
          _StatusBanner(veranstaltung: veranstaltung, heute: heute),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onWeb != null)
                _Pille(
                  key: const Key('veranstaltung-web'),
                  icon: Icons.open_in_new,
                  label: extern
                      ? t.t('veranstaltung_zur_anmeldung')
                      : t.t('veranstaltung_web'),
                  hervorgehoben: extern,
                  onTap: onWeb!,
                ),
              _Pille(
                key: const Key('veranstaltung-kalender'),
                icon: Icons.event_outlined,
                label: t.t('veranstaltung_kalender'),
                onTap: onKalender,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.veranstaltung, required this.heute});

  final Veranstaltung veranstaltung;
  final DateTime heute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final texte = VeranstaltungTexte(context);
    final farben = StatusFarben.of(context);
    final status = texte.anmeldestatus(veranstaltung, heute);
    final grau = theme.colorScheme.onSurfaceVariant;

    final (titel, farbe) = switch (status.phase) {
      AnmeldePhase.offen => (
        status.bis == null
            ? t.t('veranstaltung_anmeldung_offen')
            : t.t('veranstaltung_anmeldung_offen_bis', {
                'datum': texte.kurzdatum(status.bis!),
              }),
        farben.gut,
      ),
      AnmeldePhase.baldOffen => (
        t.t('veranstaltung_anmeldung_ab', {
          'datum': texte.kurzdatum(status.ab!),
        }),
        farben.warnung,
      ),
      AnmeldePhase.geschlossen => (
        t.t('veranstaltung_anmeldeschluss_vorbei'),
        grau,
      ),
      AnmeldePhase.unbekannt => (t.t('veranstaltung_keine_anmeldedaten'), grau),
    };
    final plaetze = texte.plaetzeText(status, mitMaximum: true);
    final hinweis = veranstaltung.anmeldeLinkExtern != null
        ? t.t('veranstaltung_anmeldung_extern')
        : status.phase == AnmeldePhase.offen ||
              status.phase == AnmeldePhase.baldOffen
        ? t.t('veranstaltung_anmeldung_web')
        : null;

    return Container(
      key: const Key('veranstaltung-status'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: farbe.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: farbe),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: titel),
                      if (plaetze != null)
                        TextSpan(
                          text: ' · $plaetze',
                          style: TextStyle(
                            color: status.ausgebucht ? farben.kritisch : null,
                          ),
                        ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: farbe,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hinweis != null)
                  Text(
                    hinweis,
                    style: theme.textTheme.bodySmall?.copyWith(color: grau),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pille extends StatelessWidget {
  const _Pille({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.hervorgehoben = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool hervorgehoben;

  @override
  Widget build(BuildContext context) {
    final inhalt = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label)),
      ],
    );
    const form = StadiumBorder();
    return hervorgehoben
        ? FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(shape: form),
            child: inhalt,
          )
        : FilledButton.tonal(
            onPressed: onTap,
            style: FilledButton.styleFrom(shape: form),
            child: inhalt,
          );
  }
}

class _Abschnitte extends StatelessWidget {
  const _Abschnitte({required this.veranstaltung, required this.veranstalter});

  final Veranstaltung veranstaltung;
  final String? veranstalter;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final texte = VeranstaltungTexte(context);
    final kursart = veranstaltung.kursart;
    final leer = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    );

    Widget abschnitt(String titel, Widget inhalt) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DpsgSectionHeader(label: titel),
          Card(margin: EdgeInsets.zero, child: inhalt),
        ],
      ),
    );

    Widget fliesstext(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );

    final voraussetzungen = [
      kursart?.voraussetzungen,
      veranstaltung.voraussetzungen,
    ].whereType<String>().toSet().join('\n\n');
    final personen = [
      if (veranstaltung.kontakt case final kontakt?)
        (kontakt, t.t('veranstaltung_kontakt')),
      for (final leitung in veranstaltung.leitung)
        (leitung, t.t('veranstaltung_leitung')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        abschnitt(
          t.t('veranstaltung_termine'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                for (final (i, termin) in veranstaltung.termine.indexed)
                  _Zeitstrahl(
                    titel: termin.label,
                    text: [
                      texte.termin(termin),
                      termin.ort,
                    ].whereType<String>().join(' · '),
                    letzter: i == veranstaltung.termine.length - 1,
                  ),
              ],
            ),
          ),
        ),
        abschnitt(
          t.t('veranstaltung_ort_kosten'),
          Column(
            children: [
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: veranstaltung.ort == null
                    ? Text(t.t('veranstaltung_kein_ort'), style: leer)
                    : Text(veranstaltung.ort!),
                subtitle: veranstaltung.ort == null
                    ? null
                    : Text(t.t('veranstaltung_ort')),
              ),
              ListTile(
                leading: const Icon(Icons.euro),
                title: veranstaltung.kosten == null
                    ? Text(t.t('veranstaltung_keine_kosten'), style: leer)
                    : Text(veranstaltung.kosten!),
                subtitle: veranstaltung.kosten == null
                    ? null
                    : Text(t.t('veranstaltung_kosten')),
              ),
            ],
          ),
        ),
        if (veranstaltung.beschreibung != null || veranstaltung.motto != null)
          abschnitt(
            t.t('veranstaltung_beschreibung'),
            fliesstext(
              [
                veranstaltung.motto,
                veranstaltung.beschreibung,
              ].whereType<String>().join('\n\n'),
            ),
          ),
        if (kursart != null)
          abschnitt(
            t.t('veranstaltung_kursart'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: Text(
                    kursart.kurzname == null
                        ? kursart.label
                        : '${kursart.kurzname} · ${kursart.label}',
                  ),
                  subtitle: _kursartUnterzeile(t, kursart) == null
                      ? null
                      : Text(_kursartUnterzeile(t, kursart)!),
                ),
                if (kursart.allgemeineInfos != null)
                  fliesstext(kursart.allgemeineInfos!),
                if (voraussetzungen.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${t.t('veranstaltung_voraussetzungen')}: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: voraussetzungen),
                        ],
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          )
        else if (voraussetzungen.isNotEmpty)
          abschnitt(
            t.t('veranstaltung_voraussetzungen'),
            fliesstext(voraussetzungen),
          ),
        if (personen.isNotEmpty)
          abschnitt(
            t.t('veranstaltung_ansprechpersonen'),
            Column(
              children: [
                for (final (person, rolle) in personen)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(person.name),
                    subtitle: Text(rolle),
                  ),
              ],
            ),
          ),
        if (veranstalter != null)
          abschnitt(
            t.t('veranstaltung_veranstalter'),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(veranstalter!),
            ),
          ),
      ],
    );
  }

  String? _kursartUnterzeile(AppLocalizations t, Kursart kursart) {
    final teile = [
      kursart.kategorie?.label,
      if (kursart.mindestalter case final alter? when alter > 0)
        t.t('veranstaltung_ab_jahren', {'n': alter}),
    ].whereType<String>();
    return teile.isEmpty ? null : teile.join(' · ');
  }
}

class _Zeitstrahl extends StatelessWidget {
  const _Zeitstrahl({
    required this.titel,
    required this.text,
    required this.letzter,
  });

  final String? titel;
  final String text;
  final bool letzter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 12,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!letzter)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: letzter ? 4 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titel != null)
                    Text(
                      titel!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    text,
                    style: titel == null
                        ? theme.textTheme.bodyLarge
                        : theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
