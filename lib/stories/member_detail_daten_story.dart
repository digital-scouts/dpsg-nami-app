import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/data/maps/in_memory_address_map_location_repository.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/widgets/member_address_card.dart';
import 'package:nami/presentation/widgets/member_detail/member_fakt_kacheln.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'support/mitglied_edge_cases.dart';

enum _KartenZustand { laden, technischerFehler, offline, nichtGefunden }

/// Kartenvorschau der Adresskarte in allen Fehlerzustaenden, ohne Netz.
Story memberAddressMapStatesStory() => Story(
  name: 'Mitglieder/Widgets/Basis/Kartenzustaende',
  builder: (context) {
    final zustand = context.knobs.options<_KartenZustand>(
      label: 'Zustand',
      initial: _KartenZustand.technischerFehler,
      options: const [
        Option(label: 'lädt', value: _KartenZustand.laden),
        Option(
          label: 'technischer Fehler',
          value: _KartenZustand.technischerFehler,
        ),
        Option(label: 'offline', value: _KartenZustand.offline),
        Option(
          label: 'Adresse nicht gefunden',
          value: _KartenZustand.nichtGefunden,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: MemberAddressCard(
          key: ValueKey<_KartenZustand>(zustand),
          mitglied: MitgliedEdgeCases.mats,
          addressLocationRepository: InMemoryAddressMapLocationRepository(),
          addressSettingsRepository: InMemoryAddressSettingsRepository(),
          mapService: _StoryGeoapifyService(zustand),
          onLaunchAddress: (_) async => true,
        ),
      ),
    );
  },
);

/// Kacheln oben im Daten-Tab mit Geburtstags-Hervorhebung.
Story memberFaktKachelnStory() => Story(
  name: 'Mitglieder/Widgets/Basis/Kacheln',
  builder: (context) {
    final tageBisGeburtstag = context.knobs.sliderInt(
      label: 'Tage bis zum Geburtstag',
      initial: 3,
      min: 0,
      max: 60,
    );
    final unbekannt = context.knobs.boolean(
      label: 'Geburtstag unbekannt',
      initial: false,
    );
    final ausgetreten = context.knobs.boolean(
      label: 'Ausgetreten',
      initial: false,
    );
    final heute = MitgliedEdgeCases.heute;
    final geburtstag = heute.add(Duration(days: tageBisGeburtstag));
    final mitglied = MitgliedEdgeCases.mats.copyWith(
      geburtsdatum: unbekannt
          ? Mitglied.peoplePlaceholderDate
          : DateTime(2016, geburtstag.month, geburtstag.day),
      eintrittsdatum: DateTime(2019, 9, 1),
      austrittsdatum: ausgetreten ? DateTime(2025, 12, 31) : null,
      austrittsdatumLoeschen: !ausgetreten,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: MemberFaktKacheln(mitglied: mitglied, heute: heute),
    );
  },
);

class _StoryGeoapifyService extends GeoapifyAddressMapService {
  _StoryGeoapifyService(this.zustand) : super(apiKeyOverride: 'story');

  final _KartenZustand zustand;

  @override
  bool get hasApiKey => true;

  @override
  Future<GeoapifyGeocodeResult> resolveAddress(
    String addressText, {
    bool allowMobileDataOverride = false,
  }) {
    return switch (zustand) {
      _KartenZustand.laden => Completer<GeoapifyGeocodeResult>().future,
      _KartenZustand.technischerFehler => Future.value(
        const GeoapifyGeocodeResult.technicalError(),
      ),
      _KartenZustand.offline => Future.value(
        const GeoapifyGeocodeResult.networkBlocked(
          deviceOffline: true,
          mobileDataBlocked: false,
        ),
      ),
      _KartenZustand.nichtGefunden => Future.value(
        const GeoapifyGeocodeResult.addressNotFound(),
      ),
    };
  }
}
