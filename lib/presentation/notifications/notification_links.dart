import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/supporter_kauf_model.dart';
import '../navigation/app_router.dart';

/// Ziele, die eine Meldung per `deep_link` öffnen darf. Alles andere wird
/// ignoriert, damit ein Feed die App nicht auf beliebige Seiten schicken kann.
final Set<String> erlaubteMeldungsZiele = {
  AppRoutes.settingsMessages,
  AppRoutes.settingsNotification,
  AppRoutes.settingsQualifikationen,
  AppRoutes.achievements,
  AppRoutes.supporter,
};

/// Erlaubtes Ziel, das in dieser App auch erreichbar ist. „Unterstützen“ gibt
/// es nur mit Store-Anbindung (`SupporterKaufModel`), wie bei den übrigen
/// Einstiegen; ohne sie gilt der externe Link der Meldung.
bool istMeldungsZielVerfuegbar(BuildContext context, String? deepLink) {
  if (deepLink == null || !erlaubteMeldungsZiele.contains(deepLink)) {
    return false;
  }
  if (deepLink == AppRoutes.supporter) {
    return Provider.of<SupporterKaufModel?>(context, listen: false) != null;
  }
  return true;
}

bool hatMeldungsLink(
  BuildContext context, {
  String? externalLink,
  String? deepLink,
}) =>
    istErlaubterExternerLink(externalLink) ||
    istMeldungsZielVerfuegbar(context, deepLink);

bool istErlaubterExternerLink(String? link) {
  final uri = link == null ? null : Uri.tryParse(link.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// Öffnet zuerst den internen Link, sonst den externen im In-App-Browser.
Future<void> oeffneMeldungsLink(
  BuildContext context, {
  String? externalLink,
  String? deepLink,
}) async {
  if (istMeldungsZielVerfuegbar(context, deepLink)) {
    await Navigator.of(context).pushNamed(deepLink!);
    return;
  }
  if (istErlaubterExternerLink(externalLink)) {
    await launchUrl(
      Uri.parse(externalLink!.trim()),
      mode: LaunchMode.inAppBrowserView,
    );
  }
}
