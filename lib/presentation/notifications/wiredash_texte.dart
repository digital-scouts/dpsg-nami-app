import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wiredash/wiredash.dart';

/// Eigene Texte fuer Wiredash: Der Screenshot-Schritt bekommt den Hinweis,
/// keine Mitgliederdaten aufzunehmen. Alle uebrigen Texte bleiben die des SDK.
class WiredashTexteDelegate
    extends LocalizationsDelegate<WiredashLocalizations> {
  const WiredashTexteDelegate();

  static const screenshotHinweisDe =
      'Bediene die App bis zur passenden Stelle und erstelle dann den '
      'Screenshot. Bitte keine Namen oder Kontaktdaten von Mitgliedern im '
      'Bild – übermale sie mit dem Stift.';
  static const screenshotHinweisEn =
      'Navigate to the right spot in the app, then take the screenshot. '
      'Please keep member names and contact details out of the picture – '
      'paint over them with the pen.';

  @override
  bool isSupported(Locale locale) =>
      const ['de', 'en'].contains(locale.languageCode);

  // Wiredash verlangt ein synchrones Laden.
  @override
  Future<WiredashLocalizations> load(Locale locale) =>
      SynchronousFuture<WiredashLocalizations>(
        locale.languageCode == 'de' ? _WiredashTexteDe() : _WiredashTexteEn(),
      );

  @override
  bool shouldReload(WiredashTexteDelegate old) => false;
}

class _WiredashTexteDe extends WiredashLocalizationsDe {
  @override
  String get feedbackStep3ScreenshotOverviewDescription =>
      WiredashTexteDelegate.screenshotHinweisDe;
}

class _WiredashTexteEn extends WiredashLocalizationsEn {
  @override
  String get feedbackStep3ScreenshotOverviewDescription =>
      WiredashTexteDelegate.screenshotHinweisEn;
}
