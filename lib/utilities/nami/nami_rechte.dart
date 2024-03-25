import 'dart:convert';

import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'package:nami/utilities/nami/nami_user_data.dart';

String url = getNamiLUrl();
String path = getNamiPath();
int? gruppierungId = getGruppierungId();
int? namiLoginId = getNamiLoginId();
String cookie = getNamiApiCookie();

// rechte enum
enum AllowedFeatures {
  appStart,
  memberEdit,
  memberCreate,
  stufenwechsel,
  fuehrungszeugnis
}

extension AllowedFeaturesExtension on AllowedFeatures {
  String toReadableString() {
    switch (this) {
      case AllowedFeatures.appStart:
        return 'App Start';
      case AllowedFeatures.memberEdit:
        return 'Member Edit';
      case AllowedFeatures.memberCreate:
        return 'Member Create';
      case AllowedFeatures.stufenwechsel:
        return 'Stufenwechsel';
      case AllowedFeatures.fuehrungszeugnis:
        return 'Führungszeugnis';
      default:
        return 'Unknown';
    }
  }
}

// Dokumentation zu den Rechten finden sich im README.md
Future<List<AllowedFeatures>> getRechte() async {
  List<AllowedFeatures> allowedFeatures = [];
  Map<int, String> rechte = await loadRechteJson();

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

  return allowedFeatures;
}

Future<Map<int, String>> loadRechteJson() async {
  final headers = {'Cookie': cookie};
  Mitglied? currentUser = findCurrentUser();
  if (currentUser == null) {
    debugPrint('Kein Benutzer gefunden.');
    return Map.from({});
  }

  dynamic document = await loadDocument(currentUser.id, headers);

  // Finden Sie das relevante <script>-Tags
  final scriptContent =
      document.querySelector('script:not([src]):not([href])')?.innerHtml;

  if (scriptContent == null) {
    debugPrint('Kein relevantes <script>-Tag gefunden.');
    return Map.from({});
  }

  // Extrahieren Sie die items-Arrays Daten aus dem storeEbene-Objekt
  var itemsJsonString = extractItems(scriptContent);

  // Parsen des storeEbene-Objekts, um die json korrekte item-list zu erhalten
  String correctedString = itemsJsonString.replaceAllMapped(
      RegExp(r'(\w+):'), (Match match) => '"${match.group(1)}":');

  // Parsen des items-Arrays-strings
  List<Map<String, dynamic>> items =
      List<Map<String, dynamic>>.from(json.decode(correctedString));

  Map<int, String> itemMap = createIdNameMap(items);

  return itemMap;
}

Future<dynamic> loadDocument(int userId, Map<String, String> headers) async {
  try {
    http.Response response = await http.get(
        Uri.parse(
            '$url/ica//pages/rights/ShowRights?gruppierung=$gruppierungId&id=$userId'),
        headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load user rights: $url');
    }
    final html = response.body;
    return parse(html);
  } catch (e) {
    debugPrint(e.toString());
    throw Exception('Failed to load user rights: $url');
  }
}

String extractItems(scriptContent) {
  const scriptStoreEbeneElement = 'var storeEbene = ';
  int startIndex = scriptContent.indexOf(scriptStoreEbeneElement) +
      scriptStoreEbeneElement.length;
  startIndex = scriptContent.indexOf('items:', startIndex) + 'items:'.length;
  final endIndex = scriptContent.indexOf('}]},', startIndex) + 2;
  final storeEbeneJsonString = scriptContent.substring(startIndex, endIndex);
  return storeEbeneJsonString;
}

Map<int, String> createIdNameMap(List<Map<String, dynamic>> inputList) {
  return Map.fromEntries(inputList.map((item) {
    int id = int.tryParse(item['id'])!;
    String name = item['name'];
    return MapEntry(id, name);
  }));
}
