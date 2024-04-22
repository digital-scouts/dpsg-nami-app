import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wiredash/assets/l10n/wiredash_localizations.g.dart';
import 'package:wiredash/assets/l10n/wiredash_localizations_de.g.dart';

class CustomWiredashTranslationsDelegate
    extends LocalizationsDelegate<WiredashLocalizations> {
  const CustomWiredashTranslationsDelegate();

  @override
  bool isSupported(Locale locale) {
    /// You have to define all languages that should be overridden
    return ['de'].contains(locale.languageCode);
  }

  @override
  Future<WiredashLocalizations> load(Locale locale) {
    switch (locale.languageCode) {
      case 'de':
        // Replace some text to better address your users
        return SynchronousFuture(_DeOverrides());
      default:
        throw "Unsupported locale $locale";
    }
  }

  @override
  bool shouldReload(CustomWiredashTranslationsDelegate old) => false;
}

class _DeOverrides extends WiredashLocalizationsDe {
  @override
  String get feedbackStep3ScreenshotOverviewDescription =>
      "Du kannst die App normal bedienen, bevor du einen Screenshot erstellst. Achte darauf, auf deinem Screenshot alle personenbezogenen Daten mit einem dicken schwarzen Stift zu verdecken.";
}
