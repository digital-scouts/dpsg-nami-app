import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Ordner für Dateien, die die App zum Öffnen oder Teilen an andere Apps
/// gibt (EFZ-Antrag, Log-Ausschnitte). Er wird beim Start und beim Logout
/// geleert, damit keine personenbezogenen Dateien liegen bleiben (A-127).
abstract final class TeilenOrdner {
  static const String name = 'teilen';

  static Future<Directory> verzeichnis({
    Future<Directory> Function()? temp,
  }) async {
    final basis = await (temp ?? getTemporaryDirectory)();
    final ordner = Directory('${basis.path}/$name');
    await ordner.create(recursive: true);
    return ordner;
  }

  /// Löscht den Ordner samt Inhalt und Altdateien früherer Stände, die
  /// direkt im Temp-Verzeichnis lagen. Wirft nie.
  static Future<void> leeren({Future<Directory> Function()? temp}) async {
    try {
      final basis = await (temp ?? getTemporaryDirectory)();
      final ordner = Directory('${basis.path}/$name');
      if (await ordner.exists()) {
        await ordner.delete(recursive: true);
      }
      await for (final eintrag in basis.list()) {
        final dateiname = eintrag.uri.pathSegments.last;
        final alt =
            (dateiname.startsWith('efz_antrag_') &&
                dateiname.endsWith('.pdf')) ||
            (dateiname.startsWith('nami-') && dateiname.endsWith('.log'));
        if (eintrag is File && alt) {
          await eintrag.delete();
        }
      }
    } catch (_) {
      // Aufraeumen darf Start und Logout nicht aufhalten.
    }
  }
}

/// Öffnet eine PDF im Viewer der Wahl. Unter Android erhält nur die
/// gewählte App Lesezugriff auf genau diese Datei (A-74); das Plugin
/// open_file gab allen PDF-Apps dauerhaft Lese- und Schreibrechte.
class PdfOeffnen {
  const PdfOeffnen();

  static const MethodChannel _kanal = MethodChannel(
    'com.namiapp/datei_oeffnen',
  );

  /// `true`, wenn ein Viewer geöffnet wurde.
  Future<bool> oeffnen(File datei) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final geoeffnet = await _kanal.invokeMethod<bool>('pdfOeffnen', {
        'pfad': datei.path,
      });
      return geoeffnet ?? false;
    }
    final ergebnis = await OpenFile.open(datei.path);
    return ergebnis.type == ResultType.done;
  }
}
