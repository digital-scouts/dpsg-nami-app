import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wiredash/wiredash.dart';

/// Eigene Texte fuer Wiredash: Der Screenshot-Schritt bekommt den Hinweis,
/// keine Mitgliederdaten aufzunehmen. Alle uebrigen Texte bleiben die des SDK.
class WiredashTexteDelegate
    extends LocalizationsDelegate<WiredashLocalizations> {
  const WiredashTexteDelegate();

  static const screenshotHinweisDe =
      'Du kannst die App normal bedienen, bevor du einen Screenshot '
      'erstellst. Achte darauf, dass keine Mitgliederdaten zu sehen sind, '
      'oder übermale sie.';
  static const screenshotHinweisEn =
      'You can use the app as usual before taking a screenshot. Make sure '
      'no member data is visible, or paint over it.';

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
