import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

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

bool hatMeldungsLink({String? externalLink, String? deepLink}) =>
    istErlaubterExternerLink(externalLink) ||
    (deepLink != null && erlaubteMeldungsZiele.contains(deepLink));

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
  if (deepLink != null && erlaubteMeldungsZiele.contains(deepLink)) {
    await Navigator.of(context).pushNamed(deepLink);
    return;
  }
  if (istErlaubterExternerLink(externalLink)) {
    await launchUrl(
      Uri.parse(externalLink!.trim()),
      mode: LaunchMode.inAppBrowserView,
    );
  }
}
