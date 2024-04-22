import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami.service.dart';
import 'package:nami/utilities/nami/nami_user_data.dart';

// rechte enum
enum AllowedFeatures {
  error,
  appStart,
  memberEdit,
  memberCreate,
  stufenwechsel,
  fuehrungszeugnis
}

extension AllowedFeaturesExtension on AllowedFeatures {
  String toReadableString() {
    switch (this) {
      case AllowedFeatures.error:
        return 'Fehler, bitte Logs über Einstellungen senden.';
      case AllowedFeatures.appStart:
        return 'Mitglieder anzeigen';
      case AllowedFeatures.memberEdit:
        return 'Miglieder bearbeiten';
      case AllowedFeatures.memberCreate:
        return 'Mitglieder anlegen';
      case AllowedFeatures.stufenwechsel:
        return 'Stufenwechsel';
      case AllowedFeatures.fuehrungszeugnis:
        return 'Führungszeugnis';
      default:
        return 'Unknown';
    }
  }
}

/// Dokumentation zu den Rechten finden sich im README.md
/// Rechte werden anhand der User ID geladen (nicht die Mitgliedsnummer)
Future<List<AllowedFeatures>> getRechte() async {
  sensLog.w('Rechte werden geladen');
  final cookie = getNamiApiCookie();
  if (cookie == 'testLoginCookie') {
    return [AllowedFeatures.appStart];
  }
  List<AllowedFeatures> allowedFeatures = [];
  Map<int, String> rechte;
  try {
    rechte = await _loadRechteJson();
  } catch (e) {
    sensLog.i('Failed to load rechte: $e');
    return [AllowedFeatures.error];
  }

  if (rechte.containsKey(5) &&
      rechte.containsKey(36) &&
      rechte.containsKey(58) &&
      rechte.containsKey(118) &&
      rechte.containsKey(139) &&
      rechte.containsKey(314)) {
    allowedFeatures.add(AllowedFeatures.appStart);
  }
  if (rechte.containsKey(57) && rechte.containsKey(59)) {
    allowedFeatures.add(AllowedFeatures.stufenwechsel);
  }
  if (rechte.containsKey(4) && rechte.containsKey(57)) {
    allowedFeatures.add(AllowedFeatures.memberEdit);
  }
  if (rechte.containsKey(6) &&
      rechte.containsKey(59) &&
      rechte.containsKey(313) &&
      rechte.containsKey(316)) {
    allowedFeatures.add(AllowedFeatures.memberCreate);
  }
  if (rechte.containsKey(473) && rechte.containsKey(474)) {
    allowedFeatures.add(AllowedFeatures.fuehrungszeugnis);
  }

  sensLog.t('Rechte: ${allowedFeatures.map((e) => e.toReadableString())}');
  return allowedFeatures;
}

Future<Map<int, String>> _loadRechteJson() async {
  Mitglied? currentUser = findCurrentUser();
  if (currentUser == null) {
    sensLog.e('Failed to find current user in load rechte');
    throw Exception('Failed to find current user in load rechte');
  }

  dynamic document = await _loadDocument(currentUser.id);

  // Finden Sie das relevante <script>-Tags
  final scriptContent =
      document.querySelector('script:not([src]):not([href])')?.innerHtml;

  if (scriptContent == null) {
    sensLog.w('Kein relevantes <script>-Tag gefunden.');
    throw Exception('Kein relevantes <script>-Tag gefunden.');
  }

  // Extrahieren Sie die items-Arrays Daten aus dem storeEbene-Objekt
  var itemsJsonString = _extractItems(scriptContent);
  sensLog.i('Rechte - itemsString: $itemsJsonString');

  // Parsen des storeEbene-Objekts, um die json korrekte item-list zu erhalten
  // Regex findet alle Elemente die mit , oder { beginnen und mit " enden.
  // Diese müssen mit " umschlossen werden, um gültiges JSON zu erhalten.
  final correctedString = itemsJsonString.replaceAllMapped(
      RegExp(r'(?<=[{,])\s*(\w+)(?=:)'),
      (Match match) => '"${match.group(1)}"');

  // Parsen des items-Arrays-strings
  List<Map<String, dynamic>> items =
      List<Map<String, dynamic>>.from(json.decode(correctedString));
  sensLog.i('Rechte - itemsList: ${items.toString()}');

  Map<int, String> itemMap = _createIdNameMap(items);

  return itemMap;
}

Future<dynamic> _loadDocument(int userId) async {
  final gruppierungId = getGruppierungId();
  // Error 500 on Session Expired
  final reqUrl = Uri.parse(
      '${getNamiLUrl()}/ica//pages/rights/ShowRights?gruppierung=$gruppierungId&id=$userId');
  final html = await withMaybeRetryHTML(
    () async => await http.get(
      reqUrl,
      headers: {'Cookie': getNamiApiCookie()},
    ),
    "Failed to load user rights",
  );
  return html;
}

String _extractItems(scriptContent) {
  const scriptStoreEbeneElement = 'var storeEbene = ';
  int startIndex = scriptContent.indexOf(scriptStoreEbeneElement) +
      scriptStoreEbeneElement.length;
  startIndex = scriptContent.indexOf('items:', startIndex) + 'items:'.length;
  final endIndex = scriptContent.indexOf('}]},', startIndex) + 2;
  final storeEbeneJsonString = scriptContent.substring(startIndex, endIndex);
  return storeEbeneJsonString;
}

Map<int, String> _createIdNameMap(List<Map<String, dynamic>> inputList) {
  return Map.fromEntries(inputList.map((item) {
    int id = int.tryParse(item['id'])!;
    String name = item['name'];
    return MapEntry(id, name);
  }));
}
