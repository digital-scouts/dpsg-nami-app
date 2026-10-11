import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/veranstaltung/veranstaltung.dart';
import '../../../domain/veranstaltung/veranstaltungs_filter.dart';
import '../../../l10n/app_localizations.dart';
import '../../model/appearance_model.dart';
import '../../model/arbeitskontext_model.dart';
import '../../model/veranstaltungen_model.dart';
import '../../widgets/app_falz.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_seitenleiste.dart';
import '../../widgets/member_list_search_bar.dart';
import '../../widgets/supporter_backdrop.dart';
import '../../widgets/veranstaltungen/veranstaltungen_filter.dart';
import '../../widgets/veranstaltungen/veranstaltungen_liste.dart';
import 'veranstaltung_detail_page.dart';

/// Kurse & Veranstaltungen (Einstellungen -> Schnellzugriff bzw.
/// Seitenleiste): Suche, Chips und nach Monat gruppierte Liste. Mit
/// Seitenleiste stehen Liste und Detail nebeneinander.
class VeranstaltungenPage extends StatefulWidget {
  const VeranstaltungenPage({super.key});

  @override
  State<VeranstaltungenPage> createState() => _VeranstaltungenPageState();
}

class _VeranstaltungenPageState extends State<VeranstaltungenPage> {
  int? _ausgewaehlt;
  VeranstaltungenModel? _model;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<VeranstaltungenModel>().laden());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model = context.read<VeranstaltungenModel>();
  }

  @override
  void dispose() {
    // Die Freigabe mobiler Daten gilt nur, solange die Seite offen ist.
    _model?.mobileDatenFreigabeBeenden();
    super.dispose();
  }

  Future<void> _filterFenster(VeranstaltungenModel model) async {
    final neu = await zeigeVeranstaltungenFilter(
      context,
      filter: model.filter,
      layerName: _layerName(),
      kategorien: model.kategorien,
      trefferFuer: model.trefferAnzahl,
    );
    if (neu != null && mounted) {
      model.setzeFilter(neu);
    }
  }

  String? _layerName() => context
      .read<ArbeitskontextModel?>()
      ?.readModel
      ?.arbeitskontext
      .aktiverLayer
      .name;

  void _oeffne(Veranstaltung veranstaltung, {required bool nebeneinander}) {
    if (nebeneinander) {
      setState(() => _ausgewaehlt = veranstaltung.id);
      return;
    }
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VeranstaltungDetailPage(veranstaltung: veranstaltung),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final model = context.watch<VeranstaltungenModel>();
    final background = context.watch<AppearanceModel?>()?.background;
    final layerName = context
        .watch<ArbeitskontextModel?>()
        ?.readModel
        ?.arbeitskontext
        .aktiverLayer
        .name;
    final zurueck = ModalRoute.of(context)?.canPop ?? false;
    final nebeneinander = AppSeitenleiste.sichtbar(
      MediaQuery.sizeOf(context).width,
    );
    final treffer = model.treffer;
    final filter = model.filter;

    Veranstaltung? ausgewaehlt;
    if (nebeneinander && treffer.isNotEmpty) {
      ausgewaehlt =
          treffer.where((v) => v.id == _ausgewaehlt).firstOrNull ??
          treffer.first;
    }

    final kopf = AppPageHeader(
      background: background,
      volleBreite: nebeneinander,
      primary: Row(
        children: [
          if (zurueck)
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: MemberSearchBar(
              initial: filter.suchtext,
              hintText: t.t('veranstaltung_suche_hint'),
              zeigeFilterKnopf: false,
              padding: EdgeInsets.zero,
              onChanged: (text) =>
                  model.setzeFilter(model.filter.copyWith(suchtext: text)),
            ),
          ),
        ],
      ),
      secondary: VeranstaltungenFilterLeiste(
        filter: filter,
        layerName: layerName,
        kategorien: model.kategorien,
        onChanged: model.setzeFilter,
        onFensterOeffnen: () => _filterFenster(model),
      ),
    );

    final Widget liste;
    if (treffer.isNotEmpty) {
      liste = VeranstaltungenListe(
        veranstaltungen: treffer,
        heute: model.heute,
        veranstalter: model.veranstalter,
        ausgewaehltId: ausgewaehlt?.id,
        onTap: (v) => _oeffne(v, nebeneinander: nebeneinander),
        onRefresh: () => model.laden(erzwingen: true),
        kopfzeile: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            t.t('veranstaltung_anzahl', {'n': treffer.length}),
            key: const Key('veranstaltungen-anzahl'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      liste = _zustand(t, model);
    }

    return Scaffold(
      body: SupporterBackdrop(
        background: background,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              kopf,
              Expanded(
                child: ausgewaehlt == null
                    ? liste
                    : AppListeDetail(
                        liste: liste,
                        detail: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(22),
                            ),
                            child: VeranstaltungDetailPage(
                              key: ValueKey(ausgewaehlt.id),
                              veranstaltung: ausgewaehlt,
                              eingebettet: true,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zustand(AppLocalizations t, VeranstaltungenModel model) {
    switch (model.zustand) {
      case VeranstaltungenLadezustand.initial:
      case VeranstaltungenLadezustand.laedt:
        return const Center(child: CircularProgressIndicator());
      case VeranstaltungenLadezustand.offline:
        return VeranstaltungenZustand(
          key: const Key('veranstaltungen-offline'),
          icon: Icons.wifi_off,
          titel: t.t('veranstaltung_offline_titel'),
          text: t.t('veranstaltung_offline_text'),
          knopf: t.t('veranstaltung_erneut'),
          onKnopf: () => model.laden(erzwingen: true),
        );
      case VeranstaltungenLadezustand.nurWlan:
        return VeranstaltungenZustand(
          key: const Key('veranstaltungen-nur-wlan'),
          icon: Icons.signal_cellular_alt,
          titel: t.t('veranstaltung_nur_wlan_titel'),
          text: t.t('veranstaltung_nur_wlan_text'),
          knopf: t.t('veranstaltung_trotzdem_laden'),
          onKnopf: model.trotzdemLaden,
          zweitKnopf: t.t('veranstaltung_abbrechen'),
          // Als Schnellziel neben der Seitenleiste gibt es kein Zurueck.
          onZweitKnopf: Navigator.of(context).canPop()
              ? () => Navigator.of(context).pop()
              : null,
        );
      case VeranstaltungenLadezustand.anmeldungNoetig:
        return VeranstaltungenZustand(
          key: const Key('veranstaltungen-anmeldung'),
          icon: Icons.lock_outline,
          titel: t.t('veranstaltung_anmeldung_noetig_titel'),
          text: t.t('veranstaltung_anmeldung_noetig_text'),
        );
      case VeranstaltungenLadezustand.fehler:
        return VeranstaltungenZustand(
          key: const Key('veranstaltungen-fehler'),
          icon: Icons.error_outline,
          titel: t.t('veranstaltung_fehler_titel'),
          text: t.t('veranstaltung_fehler_text'),
          knopf: t.t('veranstaltung_erneut'),
          onKnopf: () => model.laden(erzwingen: true),
        );
      case VeranstaltungenLadezustand.geladen:
        // Ohne Treffer bei allem Sichtbaren zeigt Hitobito nichts, meist weil
        // keine aktive Rolle besteht.
        if (model.geladenAnzahl == 0 &&
            model.filter.ebene == EbenenFilter.alle) {
          return VeranstaltungenZustand(
            key: const Key('veranstaltungen-keine'),
            icon: Icons.event_busy_outlined,
            titel: t.t('veranstaltung_keine_titel'),
            text: t.t('veranstaltung_keine_text'),
            knopf: t.t('veranstaltung_erneut'),
            onKnopf: () => model.laden(erzwingen: true),
          );
        }
        return VeranstaltungenZustand(
          key: const Key('veranstaltungen-leer'),
          icon: Icons.search_off,
          titel: t.t('veranstaltung_leer_titel'),
          text: t.t('veranstaltung_leer_text'),
          knopf: model.filter.istStandard
              ? null
              : t.t('veranstaltung_filter_reset'),
          onKnopf: model.filterZuruecksetzen,
        );
    }
  }
}

/// Leer-, Offline- und Fehlerzustand: Symbol, Titel, Hinweis, optional ein
/// Knopf.
class VeranstaltungenZustand extends StatelessWidget {
  const VeranstaltungenZustand({
    super.key,
    required this.icon,
    required this.titel,
    required this.text,
    this.knopf,
    this.onKnopf,
    this.zweitKnopf,
    this.onZweitKnopf,
  });

  final IconData icon;
  final String titel;
  final String text;
  final String? knopf;
  final VoidCallback? onKnopf;

  /// Leiser Textknopf unter [knopf], etwa „Abbrechen“.
  final String? zweitKnopf;
  final VoidCallback? onZweitKnopf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      children: [
        Center(
          child: CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          titel,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (knopf != null && onKnopf != null) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.tonal(onPressed: onKnopf, child: Text(knopf!)),
          ),
        ],
        if (zweitKnopf != null && onZweitKnopf != null) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: onZweitKnopf,
              child: Text(zweitKnopf!),
            ),
          ),
        ],
      ],
    );
  }
}
