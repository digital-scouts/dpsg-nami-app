import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../domain/appearance/appearance_catalog.dart';
import '../../../domain/appearance/support_access.dart';
import '../../../domain/supporter/supporter_aktion.dart';
import '../../../domain/supporter/supporter_produkt.dart';
import '../../../l10n/app_localizations.dart';
import '../../model/appearance_model.dart';
import '../../model/supporter_kauf_model.dart';
import '../../widgets/supporter_background.dart';

/// Gemeinsame Bausteine der Kaufseite, des Paket-Sheets und der gesperrten
/// Qualifikationen-Seite.

const _foerdererGold = Color(0xFFFFD678);
const _foerdererText = Color(0xFF1B2A3A);

/// Wirksamer Supporter-Stand: In Debug- und Profile-Builds geht der
/// Testschalter aus Debug & Tools dem Store vor (siehe main.dart), deshalb
/// zaehlt der Zugang des [AppearanceModel], nicht der reine Store-Stand.
SupportAccess supporterStand(BuildContext context, SupporterKaufModel model) =>
    context.watch<AppearanceModel?>()?.access ?? model.access;

bool _istIos(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

String supporterStoreName(BuildContext context, AppLocalizations t) =>
    t.t(_istIos(context) ? 'supporter_store_ios' : 'supporter_store_android');

/// Hintergrund, Icons und Paletten-Bezug je Paket.
abstract final class SupporterPaketInfo {
  static AppearanceBackgroundId hintergrund(SupporterPaket paket) =>
      AppearanceCatalog.backgroundPakete.entries
          .firstWhere((e) => e.value == paket)
          .key;

  static AppPaletteId palette(SupporterPaket paket) => AppearanceCatalog
      .palettePakete
      .entries
      .firstWhere((e) => e.value == paket)
      .key;

  static AppIconPackage icons(SupporterPaket paket) => AppearanceCatalog
      .iconPakete
      .entries
      .firstWhere((e) => e.value == paket)
      .key;

  static SupporterProdukt produkt(SupporterPaket paket) =>
      SupporterProdukt.values.firstWhere((p) => p.paket == paket);
}

/// Store-Preis, bei laufender Einfuehrungsaktion mit durchgestrichenem
/// Normalpreis davor.
class SupporterPreis extends StatelessWidget {
  const SupporterPreis({
    super.key,
    required this.details,
    required this.jetzt,
    this.zusatz,
    this.style,
  });

  final ProductDetails details;
  final DateTime jetzt;
  final String? zusatz;
  final TextStyle? style;

  static bool reduziert(ProductDetails details, DateTime jetzt) =>
      SupporterAktion.reduziert(
        waehrung: details.currencyCode,
        preis: details.rawPrice,
        jetzt: jetzt,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final basis = style ?? theme.textTheme.titleSmall;
    return Text.rich(
      TextSpan(
        style: basis?.copyWith(fontWeight: FontWeight.w700),
        children: [
          if (reduziert(details, jetzt)) ...[
            TextSpan(
              text: NumberFormat.currency(
                locale: locale,
                name: 'EUR',
                symbol: '€',
              ).format(SupporterAktion.normalpreisEur),
              style: TextStyle(
                decoration: TextDecoration.lineThrough,
                fontWeight: FontWeight.w500,
                color: basis?.color?.withValues(alpha: 0.6),
              ),
            ),
            const TextSpan(text: ' '),
          ],
          TextSpan(text: details.price),
          if (zusatz != null)
            TextSpan(
              text: ' $zusatz',
              style: theme.textTheme.bodySmall?.copyWith(
                color: basis?.color ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Förderer-Karte aus „Supporter werden“; auch auf der gesperrten
/// Qualifikationen-Seite.
class SupporterFoerdererKarte extends StatelessWidget {
  const SupporterFoerdererKarte({super.key, required this.model});

  final SupporterKaufModel model;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dunkel = theme.brightness == Brightness.dark;
    final details = model.produkt(SupporterProdukt.foerderer);
    final aktiv = supporterStand(context, model).foerderer;
    final laeuft = model.laeuft(SupporterProdukt.foerderer);
    const weiss = Colors.white;
    final punkte = [
      'supporter_foerderer_punkt_pakete',
      'supporter_foerderer_punkt_quali',
      'supporter_foerderer_punkt_badge',
      'supporter_foerderer_punkt_zukunft',
    ];

    Widget fuss;
    if (aktiv) {
      fuss = Container(
        key: const Key('supporter-foerderer-aktiv'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: weiss.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check, size: 18, color: Color(0xFF7EE0A0)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.t('supporter_foerderer_aktiv'),
                style: theme.textTheme.bodyMedium?.copyWith(color: weiss),
              ),
            ),
          ],
        ),
      );
    } else {
      fuss = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const Key('supporter-foerderer-kaufen'),
            style: FilledButton.styleFrom(
              backgroundColor: _foerdererGold,
              foregroundColor: _foerdererText,
              disabledBackgroundColor: weiss.withValues(alpha: 0.14),
              disabledForegroundColor: weiss,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: details == null || laeuft
                ? null
                : () => model.kaufen(SupporterProdukt.foerderer),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (laeuft) ...[
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: weiss,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    laeuft
                        ? t.t('supporter_kauf_laeuft')
                        : details == null
                        ? t.t('supporter_preis_fehlt')
                        : t.t('supporter_foerderer_testen'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          if (details != null && !laeuft) ...[
            const SizedBox(height: 10),
            Text(
              t.t('supporter_foerderer_preis', {
                'preis': details.price,
                'store': supporterStoreName(context, t),
              }),
              style: theme.textTheme.bodySmall?.copyWith(
                color: weiss.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      key: const Key('supporter-foerderer-karte'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dunkel
              ? const [Color(0xFF11233A), Color(0xFF1A3654), Color(0xFF244A69)]
              : const [Color(0xFF0F2A45), Color(0xFF1D3F63), Color(0xFF2B5677)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                AppearanceCatalog.badge(
                  SupporterBadgeId.foerdererPolarstern,
                ).assetPath,
                width: 52,
                height: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.t('supporter_foerderer_titel'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: weiss,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      t.t('supporter_foerderer_untertitel'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: weiss.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final punkt in punkte)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 17, color: _foerdererGold),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      t.t(punkt),
                      style: theme.textTheme.bodyMedium?.copyWith(color: weiss),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          fuss,
        ],
      ),
    );
  }
}

/// Vorschau eines Pakets: Hintergrund mit Farbtupfern, darunter die
/// App-Icons in drei Tageszeiten.
class SupporterPaketVorschau extends StatelessWidget {
  const SupporterPaketVorschau({
    super.key,
    required this.paket,
    this.hoehe = 86,
    this.radius = BorderRadius.zero,
  });

  final SupporterPaket paket;
  final double hoehe;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: hoehe,
        width: double.infinity,
        child: SupporterBackground(
          background: SupporterPaketInfo.hintergrund(paket),
        ),
      ),
    );
  }
}

class SupporterPaketIcons extends StatelessWidget {
  const SupporterPaketIcons({super.key, required this.paket});

  final SupporterPaket paket;

  @override
  Widget build(BuildContext context) {
    final package = SupporterPaketInfo.icons(paket);
    return Row(
      children: [
        for (final variante in const [
          AppIconVariant.morgen,
          AppIconVariant.abend,
          AppIconVariant.nacht,
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                'assets/supporter/icons/${AppIconChoice(package, variante).key}.png',
                width: 46,
                height: 46,
              ),
            ),
          ),
      ],
    );
  }
}
