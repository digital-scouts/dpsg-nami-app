import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Die gebuendelten Schriften sind keine Pakete und tauchen deshalb nicht von
/// selbst auf der Lizenzseite auf. WorkSans steht unter der OFL-1.1, Roboto
/// unter Apache-2.0; beide verlangen die Weitergabe des Lizenztexts.
void registriereSchriftlizenzen({AssetBundle? bundle}) {
  final quelle = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'WorkSans',
    ], await quelle.loadString('assets/fonts/WorkSans-OFL.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Roboto',
    ], await quelle.loadString('assets/fonts/Roboto-LICENSE.txt'));
  });
}
