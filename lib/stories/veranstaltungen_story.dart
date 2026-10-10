import 'package:flutter/material.dart';
import 'package:nami/demo/demo_data.dart';
import 'package:nami/demo/demo_services.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/veranstaltung/veranstaltung.dart';
import 'package:nami/presentation/model/veranstaltungen_model.dart';
import 'package:nami/presentation/screens/veranstaltungen/veranstaltung_detail_page.dart';
import 'package:nami/presentation/screens/veranstaltungen/veranstaltungen_page.dart';
import 'package:nami/services/app_mode_controller.dart';
import 'package:nami/services/hitobito_events_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

enum VeranstaltungenStoryZustand { geladen, keine, offline, fehler }

enum VeranstaltungenStorySeite { liste, kurs, mehrereTermine, leer }

final DateTime _jetzt = DateTime(2026, 10, 10, 9);

/// Liefert die Demo-Events oder simuliert einen Zustand der Suche.
class _StoryService extends DemoHitobitoEventsService {
  _StoryService(this.zustand)
    : super(DemoData(DemoZugang.stammesvorstand, now: () => _jetzt));

  final VeranstaltungenStoryZustand zustand;

  @override
  Future<List<Veranstaltung>> fetchVeranstaltungen(
    String accessToken, {
    required DateTime abTag,
    Set<int>? gruppenIds,
  }) async {
    switch (zustand) {
      case VeranstaltungenStoryZustand.geladen:
        return super.fetchVeranstaltungen(
          accessToken,
          abTag: abTag,
          gruppenIds: gruppenIds,
        );
      case VeranstaltungenStoryZustand.keine:
        return const [];
      case VeranstaltungenStoryZustand.offline:
        throw const NetworkAccessBlockedException(
          reason: NetworkAccessBlockedReason.offline,
          connectionType: NetworkConnectionType.offline,
          message: 'offline',
        );
      case VeranstaltungenStoryZustand.fehler:
        throw const HitobitoEventsException('Story', statusCode: 500);
    }
  }
}

Story veranstaltungenStory() => Story(
  name: 'Einstellungen/Kurse & Veranstaltungen',
  builder: (context) {
    final seite = context.knobs.options<VeranstaltungenStorySeite>(
      label: 'Seite',
      initial: VeranstaltungenStorySeite.liste,
      options: const [
        Option(label: 'Liste', value: VeranstaltungenStorySeite.liste),
        Option(label: 'Detail Kurs', value: VeranstaltungenStorySeite.kurs),
        Option(
          label: 'Detail mehrere Termine',
          value: VeranstaltungenStorySeite.mehrereTermine,
        ),
        Option(
          label: 'Detail ohne Angaben',
          value: VeranstaltungenStorySeite.leer,
        ),
      ],
    );
    final zustand = context.knobs.options<VeranstaltungenStoryZustand>(
      label: 'Zustand der Liste',
      initial: VeranstaltungenStoryZustand.geladen,
      options: const [
        Option(label: 'Geladen', value: VeranstaltungenStoryZustand.geladen),
        Option(
          label: 'Keine sichtbar',
          value: VeranstaltungenStoryZustand.keine,
        ),
        Option(label: 'Offline', value: VeranstaltungenStoryZustand.offline),
        Option(label: 'Fehler', value: VeranstaltungenStoryZustand.fehler),
      ],
    );

    final service = _StoryService(zustand);
    final model = VeranstaltungenModel(
      service: service,
      remoteAccessExecutor: <T>({required trigger, required action}) =>
          action(AuthSession(accessToken: 'story', receivedAt: _jetzt)),
      readModel: () => null,
      jetzt: () => _jetzt,
    );
    final events = {
      for (final v in service.demoData.veranstaltungen()) v.id: v,
    };
    final Widget inhalt = switch (seite) {
      VeranstaltungenStorySeite.liste => const VeranstaltungenPage(),
      VeranstaltungenStorySeite.kurs => VeranstaltungDetailPage(
        veranstaltung: events[9104]!,
      ),
      VeranstaltungenStorySeite.mehrereTermine => VeranstaltungDetailPage(
        veranstaltung: events[9102]!,
      ),
      VeranstaltungenStorySeite.leer => VeranstaltungDetailPage(
        veranstaltung: events[9107]!,
      ),
    };
    return ChangeNotifierProvider<VeranstaltungenModel>.value(
      key: ValueKey('$seite-$zustand'),
      value: model,
      child: inhalt,
    );
  },
);
