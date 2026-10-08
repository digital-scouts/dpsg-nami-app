import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/appearance/appearance_catalog.dart';
import '../../../domain/rechtliches/anbieter.dart';
import '../../../domain/supporter/supporter_aktion.dart';
import '../../../l10n/app_localizations.dart';
import '../../model/supporter_kauf_model.dart';
import '../../navigation/app_router.dart';
import '../../theme/theme.dart';
import '../../widgets/supporter_badge.dart';
import 'supporter_bausteine.dart';

/// „Supporter werden“: Förderer-Abo und die drei Design-Pakete. Nur
/// erreichbar, wenn die Store-Anbindung aktiv ist (SUPPORTER_STORE_ENABLED).
class SupporterPage extends StatefulWidget {
  const SupporterPage({super.key, this.nowProvider = DateTime.now});

  final DateTime Function() nowProvider;

  static const _aboVerwaltenIos =
      'https://apps.apple.com/account/subscriptions';
  static const _aboVerwaltenAndroid =
      'https://play.google.com/store/account/subscriptions?sku=foerderer_jahr&package=de.jlange.nami.app';
  static const _eulaIos =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const _nutzungAndroid = 'https://play.google.com/about/play-terms/';

  @override
  State<SupporterPage> createState() => _SupporterPageState();
}

class _SupporterPageState extends State<SupporterPage> {
  SupporterKaufModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final model = context.read<SupporterKaufModel>();
    if (!identical(model, _model)) {
      _model?.removeListener(_zeigeFehler);
      _model = model..addListener(_zeigeFehler);
    }
  }

  @override
  void dispose() {
    _model?.removeListener(_zeigeFehler);
    super.dispose();
  }

  void _zeigeFehler() {
    final model = _model;
    final fehler = model?.fehler;
    if (model == null || fehler == null || !mounted) {
      return;
    }
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t.t(
            fehler == SupporterKaufFehler.kauf
                ? 'supporter_fehler_kauf'
                : 'supporter_fehler_wiederherstellen',
          ),
        ),
      ),
    );
    model.fehlerQuittieren();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final model = context.watch<SupporterKaufModel>();
    final jetzt = widget.nowProvider();
    return Scaffold(
      appBar: AppBar(title: Text(t.t('supporter_titel'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              t.t('supporter_intro'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (model.status == SupporterStoreStatus.nichtVerfuegbar) ...[
            const SizedBox(height: 14),
            _OfflineHinweis(onErneut: model.aktualisiere),
          ],
          const SizedBox(height: 14),
          SupporterFoerdererKarte(model: model),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 2),
            child: Text(
              t.t('supporter_pakete_titel').toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (final paket in SupporterPaket.values)
            _PaketKarte(paket: paket, model: model, jetzt: jetzt),
          const SizedBox(height: 10),
          const _KompassHinweis(),
          const SizedBox(height: 18),
          _Fuss(model: model),
        ],
      ),
    );
  }
}

class _OfflineHinweis extends StatelessWidget {
  const _OfflineHinweis({required this.onErneut});

  final Future<void> Function() onErneut;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: const Key('supporter-offline'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.t('supporter_offline_titel'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.t('supporter_offline_text'),
                    style: theme.textTheme.bodySmall,
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onErneut,
                    child: Text(t.t('supporter_erneut')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaketKarte extends StatelessWidget {
  const _PaketKarte({
    required this.paket,
    required this.model,
    required this.jetzt,
  });

  final SupporterPaket paket;
  final SupporterKaufModel model;
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final produkt = SupporterPaketInfo.produkt(paket);
    final details = model.produkt(produkt);
    final stand = supporterStand(context, model);
    final foerderer = stand.foerderer;
    final gekauft = stand.pakete.contains(paket);
    final laeuft = model.laeuft(produkt);
    final farben = appPalettes[SupporterPaketInfo.palette(paket)]!.of(
      theme.brightness,
    );

    Widget links;
    Widget rechts;
    if (gekauft || foerderer) {
      links = TextButton(
        key: Key('supporter-paket-${paket.name}-erscheinungsbild'),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.settingsAppearance),
        child: Text(t.t('supporter_erscheinungsbild')),
      );
      rechts = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 16, color: theme.colorScheme.tertiary),
          const SizedBox(width: 4),
          Text(
            t.t(gekauft ? 'supporter_gekauft' : 'supporter_enthalten'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.tertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    } else {
      final reduziert =
          details != null && SupporterPreis.reduziert(details, jetzt);
      links = details == null
          ? Text(t.t('supporter_preis_fehlt'), style: theme.textTheme.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SupporterPreis(
                  details: details,
                  jetzt: jetzt,
                  zusatz: t.t('supporter_einmalig'),
                ),
                if (reduziert)
                  Text(
                    t.t('supporter_aktion_bis', {
                      'datum': _datum(context, SupporterAktion.letzterTag),
                    }),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            );
      rechts = FilledButton(
        key: Key('supporter-paket-${paket.name}-kaufen'),
        onPressed: details == null || laeuft
            ? null
            : () => model.kaufen(produkt),
        child: laeuft
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(t.t('supporter_kaufen')),
      );
    }

    return Card(
      key: Key('supporter-paket-${paket.name}'),
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SupporterPaketVorschau(paket: paket),
              Positioned(
                left: 12,
                bottom: -12,
                child: _Farbtupfer(
                  farben: [
                    farben.primary,
                    farben.secondary,
                    farben.primaryLite,
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.t('supporter_paket_${paket.name}'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.t('supporter_paket_${paket.name}_text'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SupporterPaketIcons(paket: paket),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: links),
                    const SizedBox(width: 10),
                    rechts,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _datum(BuildContext context, DateTime datum) {
    final sprache = Localizations.localeOf(context).languageCode;
    return sprache == 'de'
        ? DateFormat('d.M.').format(datum)
        : DateFormat.MMMd(sprache).format(datum);
  }
}

class _Farbtupfer extends StatelessWidget {
  const _Farbtupfer({required this.farben});

  final List<Color> farben;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).cardColor, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final farbe in farben)
              Container(width: 22, height: 22, color: farbe),
          ],
        ),
      ),
    );
  }
}

class _KompassHinweis extends StatelessWidget {
  const _KompassHinweis();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kompass = AppearanceCatalog.badges
        .where((b) => b.tier == SupportTier.supporter)
        .take(5);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            for (final badge in kompass)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: SupporterBadge(badge: badge.id, size: 28),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.t('supporter_badges_hinweis'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fuss extends StatelessWidget {
  const _Fuss({required this.model});

  final SupporterKaufModel model;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final klein = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Future<void> oeffne(String url) =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    Widget link(String key, String text, VoidCallback onTap) => TextButton(
      key: Key(key),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
      child: Text(text),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            link(
              'supporter-wiederherstellen',
              t.t('supporter_wiederherstellen'),
              model.wiederherstellen,
            ),
            link(
              'supporter-abo-verwalten',
              t.t('supporter_abo_verwalten'),
              () => oeffne(
                ios
                    ? SupporterPage._aboVerwaltenIos
                    : SupporterPage._aboVerwaltenAndroid,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            t.t('supporter_rechtliches', {
              'konto': t.t(
                ios ? 'supporter_konto_ios' : 'supporter_konto_android',
              ),
            }),
            style: klein,
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            link(
              'supporter-nutzungsbedingungen',
              t.t('supporter_nutzungsbedingungen'),
              () => oeffne(
                ios ? SupporterPage._eulaIos : SupporterPage._nutzungAndroid,
              ),
            ),
            link(
              'supporter-datenschutz',
              t.t('supporter_datenschutz'),
              () => oeffne(Anbieter.datenschutzerklaerungUrl),
            ),
          ],
        ),
      ],
    );
  }
}
