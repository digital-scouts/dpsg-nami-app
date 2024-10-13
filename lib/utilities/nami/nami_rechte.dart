import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami.service.dart';

// rechte enum
enum AllowedFeatures {
  noPermission,
  unknownError,
  appStart,
  memberEdit,
  memberCreate,
  memberImport,
  membershipEnd,
  taetigkeitCreate,
  taetigkeitEdit,
  taetigkeitDelete,
  stufenwechsel,
  fuehrungszeugnis,
  ausbildungCreate,
  ausbildungEdit,
  ausbildungRead,
  ausbildungDelete,
}

extension AllowedFeaturesExtension on AllowedFeatures {
  String toReadableString() {
    switch (this) {
      case AllowedFeatures.unknownError:
        return 'Fehler, bitte Logs über Einstellungen senden.';
      case AllowedFeatures.noPermission:
        return 'Keine Berechtigung';
      case AllowedFeatures.appStart:
        return 'Mitglieder anzeigen';
      case AllowedFeatures.memberEdit:
        return 'Mitglieder bearbeiten';
      case AllowedFeatures.memberCreate:
        return 'Mitglieder anlegen';
      case AllowedFeatures.membershipEnd:
        return 'Mitgliedschaft beenden';
      case AllowedFeatures.memberImport:
        return 'Mitglied übernehmen';
      case AllowedFeatures.taetigkeitCreate:
        return 'Tätigkeit anlegen';
      case AllowedFeatures.taetigkeitEdit:
        return 'Tätigkeit bearbeiten';
      case AllowedFeatures.taetigkeitDelete:
        return 'Tätigkeit löschen';
      case AllowedFeatures.stufenwechsel:
        return 'Stufenwechsel';
      case AllowedFeatures.fuehrungszeugnis:
        return 'Führungszeugnis';
      case AllowedFeatures.ausbildungCreate:
        return 'Ausbildung anlegen';
      case AllowedFeatures.ausbildungEdit:
        return 'Ausbildung bearbeiten';
      case AllowedFeatures.ausbildungRead:
        return 'Ausbildung anzeigen';
      case AllowedFeatures.ausbildungDelete:
        return 'Ausbildung löschen';
    }
  }
}

Future<List<int>> loadRechte(int id) async {
  sensLog.i('Rechte werden geladen');
  final cookie = getNamiApiCookie();
  if (cookie == 'testLoginCookie') {
    return [5, 36, 58, 118, 139, 314, 193, 194];
  }
  Map<int, String> rechte;
  try {
    rechte = await _loadRechteJson(id);
  } catch (e, st) {
    sensLog.e('Failed to load rechte', error: e, stackTrace: st);
    return [];
  }
  return rechte.keys.toList();
}

/// Dokumentation zu den Rechten finden sich im README.md
/// Rechte werden anhand der User ID geladen (nicht die Mitgliedsnummer)
List<AllowedFeatures> getAllowedFeatures() {
  final rechte = getRechte();
  if (rechte.isEmpty) {
    return [AllowedFeatures.unknownError];
  }
  List<AllowedFeatures> allowedFeatures = [];
  if (rechte.contains(5) &&
      rechte.contains(36) &&
      rechte.contains(58) &&
      rechte.contains(118) &&
      rechte.contains(139) &&
      rechte.contains(314)) {
    allowedFeatures.add(AllowedFeatures.appStart);
  }
  if (rechte.contains(57) && rechte.contains(59)) {
    allowedFeatures.add(AllowedFeatures.stufenwechsel);
  }
  if (rechte.contains(57)) {
    allowedFeatures.add(AllowedFeatures.taetigkeitEdit);
  }
  if (rechte.contains(59)) {
    allowedFeatures.add(AllowedFeatures.taetigkeitCreate);
  }
  if (rechte.contains(186)) {
    allowedFeatures.add(AllowedFeatures.taetigkeitDelete);
  }
  if (rechte.contains(4) && rechte.contains(57)) {
    allowedFeatures.add(AllowedFeatures.memberEdit);
  }
  if (rechte.contains(6) &&
      rechte.contains(59) &&
      rechte.contains(313) &&
      rechte.contains(316)) {
    allowedFeatures.add(AllowedFeatures.memberCreate);
  }
  if (rechte.contains(312)) {
    allowedFeatures.add(AllowedFeatures.membershipEnd);
  }
  if (rechte.contains(315)) {
    allowedFeatures.add(AllowedFeatures.memberImport);
  }
  if (rechte.contains(473) && rechte.contains(474)) {
    allowedFeatures.add(AllowedFeatures.fuehrungszeugnis);
  }
  if (rechte.contains(192)) {
    allowedFeatures.add(AllowedFeatures.ausbildungCreate);
  }
  if (rechte.contains(193)) {
    allowedFeatures.add(AllowedFeatures.ausbildungRead);
  }
  if (rechte.contains(194)) {
    allowedFeatures.add(AllowedFeatures.ausbildungEdit);
  }
  if (rechte.contains(195)) {
    allowedFeatures.add(AllowedFeatures.ausbildungDelete);
  }

  sensLog.t('Rechte: ${allowedFeatures.map((e) => e.toReadableString())}');
  return allowedFeatures;
}

Future<Map<int, String>> _loadRechteJson(int id) async {
  dynamic document = await _loadDocument(id);

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
