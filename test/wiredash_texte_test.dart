import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/notifications/wiredash_texte.dart';
import 'package:wiredash/wiredash.dart';

void main() {
  const delegate = WiredashTexteDelegate();

  test('Screenshot-Schritt nennt den Hinweis zu Mitgliederdaten', () async {
    final de = await delegate.load(const Locale('de'));
    final en = await delegate.load(const Locale('en'));

    expect(
      de.feedbackStep3ScreenshotOverviewDescription,
      contains('keine Mitgliederdaten'),
    );
    expect(
      en.feedbackStep3ScreenshotOverviewDescription,
      contains('no member data'),
    );
  });

  test('übrige Texte bleiben die des SDK', () async {
    final de = await delegate.load(const Locale('de'));

    expect(
      de.feedbackStep3ScreenshotOverviewTitle,
      WiredashLocalizationsDe().feedbackStep3ScreenshotOverviewTitle,
    );
  });

  test('nur Deutsch und Englisch, andere Sprachen nutzt das SDK selbst', () {
    expect(delegate.isSupported(const Locale('de')), isTrue);
    expect(delegate.isSupported(const Locale('en')), isTrue);
    expect(delegate.isSupported(const Locale('fr')), isFalse);
  });
}
