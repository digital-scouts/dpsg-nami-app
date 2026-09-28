// Wird nur in einem Worktree von v0.2.8 kompiliert (siehe README.md).
// Schreibt realistische Fake-Daten mit dem echten Code der App-Version 0.2.8.
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/hive/ausbildung.dart';
import 'package:nami/utilities/hive/custom_group.dart';
import 'package:nami/utilities/hive/data_changes.dart';
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings_service.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

/// Oeffnet alle Boxen wie 0.2.8 (inkl. Schluesselerzeugung in Secure Storage)
/// und befuellt sie. Die Boxen bleiben geoeffnet. Liefert die Mitglieder.
Future<List<Mitglied>> seedLegacyData() async {
  await registerAdapter();
  await openHive();
  initializeSettingsService();

  final members = List<Mitglied>.generate(5, _member);
  final memberBox = Hive.box<Mitglied>('members');
  for (final member in members) {
    await memberBox.put(member.mitgliedsNummer, member);
  }
  final taetigkeitBox = Hive.box<Taetigkeit>('taetigkeit');
  for (final member in members) {
    for (final taetigkeit in member.taetigkeiten) {
      await taetigkeitBox.put(taetigkeit.id, taetigkeit);
    }
  }

  settingsService
    ..setWelcomeMessageShown(true)
    ..setNamiApiCookie('JSESSIONID=legacy-fixture-cookie')
    ..setNamiLoginId(123456)
    ..setLoggedInUserId(4711)
    ..setNamiPassword('legacy-fixture-password')
    ..setNamiUrl('https://nami.dpsg.de')
    ..setNamiPath('/ica/rest')
    ..setGruppierungId(131313)
    ..setGruppierungName('Stamm Fixture')
    ..setLastNamiSync(DateTime(2026, 5, 1, 12))
    ..setLastNamiSyncTry(DateTime(2026, 5, 1, 12))
    ..setLastLoginCheck(DateTime(2026, 5, 1, 12))
    ..setRechte([1, 2, 3])
    ..setLastAppVersion('0.2.8')
    ..setThemeMode(ThemeMode.dark)
    ..setBenachrichtigungenActive(true)
    ..setFavouriteList([members.first.mitgliedsNummer]);

  await Hive.box('filterBox').put('FilterValue.customGroups', {
    'Leitende': CustomGroup(active: true, iconIndex: 1),
  });

  await Hive.box<DataChange>('dataChanges').add(
    DataChange(
      id: members.first.id!,
      changeDate: DateTime(2026, 4, 30),
      gruppierung: 131313,
      action: 1,
      changedFields: ['email'],
    ),
  );
  await Hive.box<Map>('satzung_db').put('chunk_0', {
    'text': 'Fixture-Satzungstext',
    'embedding': [0.1, 0.2, 0.3],
  });
  await Hive.box<Map>(
    'ai_chat_messages',
  ).put('m1', {'role': 'user', 'text': 'Fixture-Frage'});

  return members;
}

Mitglied _member(int index) {
  final id = 1000 + index;
  final taetigkeit = Taetigkeit()
    ..id = 9000 + index
    ..taetigkeit = index == 0 ? '€ LeiterIn (6)' : '€ Mitglied (1)'
    ..aktivVon = DateTime(2020, 1, 1)
    ..aktivBis = null
    ..anlagedatum = DateTime(2020, 1, 1)
    ..untergliederung = 'Wölfling'
    ..gruppierung = 'Stamm Fixture 131313'
    ..berechtigteGruppe = null
    ..berechtigteUntergruppen = null;

  return Mitglied()
    ..vorname = 'Fixture$index'
    ..nachname = 'Legacy'
    ..geschlechtId = 1
    ..geburtsDatum = DateTime(2015, (index % 12) + 1, 10 + index)
    ..id = id
    ..mitgliedsNummer = 500000 + index
    ..eintrittsdatum = DateTime(2020, 1, 1)
    ..austrittsDatum = null
    ..ort = 'Musterstadt'
    ..plz = '12345'
    ..strasse = 'Musterweg $index'
    ..landId = 1
    ..email = 'fixture$index@example.org'
    ..emailVertretungsberechtigter = null
    ..telefon1 = '0123 45678$index'
    ..telefon2 = null
    ..telefon3 = null
    ..lastUpdated = DateTime(2026, 5, 1)
    ..version = 1
    ..mglTypeId = 'MITGLIED'
    ..beitragsartId = 1
    ..status = 'Aktiv'
    ..taetigkeiten = [taetigkeit]
    ..ausbildungen = <Ausbildung>[]
    ..staatssangehaerigkeitId = 1
    ..konfessionId = null
    ..mitgliedszeitschrift = false
    ..datenweiterverwendung = false
    ..spitzname = null;
}
