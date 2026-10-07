import 'package:flutter/material.dart';
import 'package:nami/presentation/widgets/app_log_view.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

/// Synthetische Zeilen im Format von LoggerService.
const String appLogStoryContent = '''
[2026-10-06 21:14:02] [info] [lifecycle] App AppLifecycleState.resumed
[2026-10-06 21:14:06] [info] [hitobito_sync] Hitobito-Sync erfolgreich trigger=resume
[2026-10-07 08:02:11] [info] [auth_flow] Initialisierung gestartet
[2026-10-07 08:02:11] [info] [nav] route_open route=/
[2026-10-07 08:02:13] [info] [http] source=hitobito_groups method=GET url=https://hitobito.example/api/groups status=200
[2026-10-07 08:02:15] [warn] [arbeitskontext] Mitglieder-Refresh fehlgeschlagen, Cache bleibt aktiv status=503 versuch=1
[2026-10-07 08:02:21] [error] [arbeitskontext] Arbeitskontext konnte nicht aktualisiert werden error=HitobitoPeopleException: People-Anfrage fehlgeschlagen (503).
#0 HitobitoPeopleService._fetchPeoplePage (package:nami/services/hitobito_people_service.dart:745)
#1 HitobitoPeopleService.fetchPeople (package:nami/services/hitobito_people_service.dart:96)
#2 ArbeitskontextModel._runRefreshFromRemote (package:nami/presentation/model/arbeitskontext_model.dart:534)
[2026-10-07 08:03:40] [info] [member_list] member_detail_opened source=member_list
[2026-10-07 08:04:10] [info] [arbeitskontext] Arbeitskontext erfolgreich aktualisiert: layer=68 name=Stamm Silberfels gruppen=6 mitglieder=27 dauer_ms=3837''';

Story appLogViewStory() {
  return Story(
    name: 'Einstellungen/Screens/App-Logs',
    builder: (context) {
      final leer = context.knobs.boolean(label: 'Leer', initial: false);
      return Scaffold(
        appBar: AppBar(title: const Text('App-Logs')),
        body: AppLogView(
          content: leer ? '' : appLogStoryContent,
          nowProvider: () => DateTime(2026, 10, 7, 9),
        ),
      );
    },
  );
}
