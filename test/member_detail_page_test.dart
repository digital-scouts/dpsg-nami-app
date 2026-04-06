import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/data/maps/in_memory_address_map_location_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
import 'package:nami/services/geoapify_address_map_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  testWidgets(
    'rendert Read-only-Details fuer ein Mitglied',
    (tester) async {
      final member = Mitglied(
        mitgliedsnummer: '4711',
        vorname: 'Julia',
        nachname: 'Keller',
        geburtsdatum: DateTime(2010, 4, 6),
        eintrittsdatum: DateTime(2020, 5, 1),
        updatedAt: DateTime(2024, 11, 7, 14, 35),
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(wert: '040123456', label: 'Festnetznummer'),
        ],
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(wert: 'julia@example.com', label: 'E-Mail'),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(MemberDetailPage(mitglied: member)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Julia Keller'), findsOneWidget);
      expect(find.text('Allgemeine Informationen'), findsOneWidget);
      expect(find.text('Mitgliedschaft'), findsOneWidget);
      expect(find.text('4711'), findsOneWidget);
      expect(find.text('Zuletzt aktualisiert'), findsOneWidget);
      expect(find.text('07.11.2024, 14:35'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets(
    'blendet Platzhalterdaten fuer Geburtstag und Eintritt aus',
    (tester) async {
      final member = Mitglied.peopleListItem(
        mitgliedsnummer: '9',
        vorname: 'Max',
        nachname: 'Mustermann',
      );

      await tester.pumpWidget(
        _buildTestApp(MemberDetailPage(mitglied: member)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Geburtstag'), findsNothing);
      expect(find.text('Eintrittsdatum'), findsNothing);
      expect(find.text('Mitgliedschaft'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets('zeigt die erste Adresse in den Details an', (tester) async {
    final member = Mitglied(
      personId: 23,
      mitgliedsnummer: '4711',
      vorname: 'Julia',
      nachname: 'Keller',
      geburtsdatum: DateTime(2010, 4, 6),
      eintrittsdatum: DateTime(2020, 5, 1),
      adressen: const <MitgliedKontaktAdresse>[
        MitgliedKontaktAdresse(
          additionalAddressId: 0,
          street: 'Musterweg',
          housenumber: '4',
          zipCode: '50667',
          town: 'Koeln',
          country: 'DE',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(
        MemberDetailPage(
          mitglied: member,
          addressLocationRepository: InMemoryAddressMapLocationRepository(),
          mapService: _NeverCompletingGeoapifyAddressMapService(),
          previewTimeout: const Duration(milliseconds: 100),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Adresse'), findsOneWidget);
    expect(find.text('Musterweg 4\n50667 Koeln\nDE'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'bricht eine haengende Kartenauflosung nach Timeout ab',
    (tester) async {
      final member = Mitglied(
        personId: 23,
        mitgliedsnummer: '4711',
        vorname: 'Julia',
        nachname: 'Keller',
        geburtsdatum: DateTime(2010, 4, 6),
        eintrittsdatum: DateTime(2020, 5, 1),
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 0,
            street: 'Musterweg',
            housenumber: '4',
            zipCode: '50667',
            town: 'Koeln',
            country: 'DE',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          MemberDetailPage(
            mitglied: member,
            addressLocationRepository: InMemoryAddressMapLocationRepository(),
            mapService: _NeverCompletingGeoapifyAddressMapService(),
            previewTimeout: const Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Adresse'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Image), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );
}

Widget _buildTestApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de'), Locale('en')],
    home: home,
  );
}

class _NeverCompletingGeoapifyAddressMapService
    extends GeoapifyAddressMapService {
  _NeverCompletingGeoapifyAddressMapService()
    : super(apiKeyOverride: 'test-key');

  @override
  bool get hasApiKey => true;

  @override
  Future<LatLng?> geocodeAddress(String addressText) {
    return Completer<LatLng?>().future;
  }
}
