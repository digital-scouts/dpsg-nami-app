import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/arbeitskontext/teildaten_stand.dart';
import '../../domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import '../../l10n/app_localizations.dart';
import '../model/qualifikations_einstellungen_model.dart';
import '../widgets/qualifikationen/qualifikation_bausteine.dart';
import 'qualifikationen/qualifikation_personen_page.dart';
import 'qualifikationen/qualifikationen_auswahl_page.dart';
import 'qualifikationen/qualifikationen_kontext.dart';

/// Qualifikationen-Uebersicht (Einstellungen -> Schnellzugriff): je
/// angezeigter Art eine Zeile mit „erfuellt / benoetigt“ und Status. Teil des
/// Supporter-Pakets; gesperrt erscheint nur ein Hinweis.
class SettingsQualifikationenPage extends StatelessWidget {
  const SettingsQualifikationenPage({
    super.key,
    this.readModel,
    this.heuteProvider,
  });

  /// Fuer Stories und Tests; sonst aus dem ArbeitskontextModel.
  final ArbeitskontextReadModel? readModel;
  final DateTime Function()? heuteProvider;

  static const _useCase = ErmittleQualifikationsUebersichtUseCase();

  void _oeffneAuswahl(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QualifikationenAuswahlPage(
          readModel: readModel,
          heuteProvider: heuteProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final supporter = QualifikationenKontext.supporterFrei(context);
    final readModel = QualifikationenKontext.readModel(context, this.readModel);
    final einstellungen = context
        .watch<QualifikationsEinstellungenModel>()
        .einstellungen;
    final heute = QualifikationenKontext.heute(heuteProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('quali_titel')),
        actions: [
          if (supporter && readModel != null)
            IconButton(
              key: const Key('quali-auswahl-oeffnen'),
              tooltip: t.t('quali_auswahl_tooltip'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _oeffneAuswahl(context),
            ),
        ],
      ),
      body: !supporter
          ? const _SupporterHinweis()
          : readModel == null
          ? const Center(child: CircularProgressIndicator())
          : readModel.efzStand == TeildatenStand.unbekannt &&
                readModel.qualifikationenStand == TeildatenStand.unbekannt
          ? _ZustandsHinweis(
              icon: Icons.sync,
              titel: t.t('quali_nicht_sync_titel'),
              text: t.t('quali_nicht_sync_text'),
            )
          : _Uebersicht(
              readModel: readModel,
              zeilen: _useCase(
                readModel: readModel,
                einstellungen: einstellungen,
                heute: heute,
              ),
              heute: heute,
              onAuswahl: () => _oeffneAuswahl(context),
              onZeile: (zeile) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QualifikationPersonenPage(
                    schluessel: zeile.art.schluessel,
                    readModel: this.readModel,
                    heuteProvider: heuteProvider,
                  ),
                ),
              ),
            ),
    );
  }
}

class _Uebersicht extends StatelessWidget {
  const _Uebersicht({
    required this.readModel,
    required this.zeilen,
    required this.heute,
    required this.onAuswahl,
    required this.onZeile,
  });

  final ArbeitskontextReadModel readModel;
  final List<UebersichtZeile> zeilen;
  final DateTime heute;
  final VoidCallback onAuswahl;
  final ValueChanged<UebersichtZeile> onZeile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final ohneHitobitoArten = readModel.qualifikationsarten.isEmpty;
    final hinweis = !ohneHitobitoArten
        ? null
        : readModel.qualifikationenStand == TeildatenStand.fehlgeschlagen
        ? t.t('quali_fehlgeschlagen_titel')
        : readModel.qualifikationenStand == TeildatenStand.geladen
        ? t.t('quali_leer_hinweis')
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            t.t('quali_kontext', {
              'kontext': readModel.arbeitskontext.aktiverLayer.name,
              'n': QualifikationenKontext.personenMitRolle(readModel, heute),
            }),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final zeile in zeilen) ...[
                QualifikationUebersichtZeile(
                  zeile: zeile,
                  onTap: () => onZeile(zeile),
                ),
                const Divider(height: 1, indent: 62),
              ],
              ListTile(
                key: const Key('quali-hinzufuegen'),
                leading: Icon(Icons.add, color: theme.colorScheme.primary),
                title: Text(
                  t.t('quali_hinzufuegen'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: onAuswahl,
              ),
            ],
          ),
        ),
        if (hinweis != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: theme.hintColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(hinweis, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SupporterHinweis extends StatelessWidget {
  const _SupporterHinweis();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              t.t('quali_supporter_titel'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t.t('quali_supporter_text'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              t.t('quali_supporter_hinweis'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZustandsHinweis extends StatelessWidget {
  const _ZustandsHinweis({
    required this.icon,
    required this.titel,
    required this.text,
  });

  final IconData icon;
  final String titel;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.outline),
            const SizedBox(height: 10),
            Text(
              titel,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
