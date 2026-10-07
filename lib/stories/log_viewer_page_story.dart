import 'package:flutter/foundation.dart';
import 'package:nami/presentation/screens/log_viewer_page.dart';
import 'package:nami/presentation/widgets/app_log_view.dart';
import 'package:nami/presentation/widgets/hitobito_traffic_log_view.dart';
import 'package:nami/services/hitobito_traffic_log_service.dart';
import 'package:nami/services/logger_service.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'app_log_view_story.dart';
import 'hitobito_traffic_log_view_story.dart';

DateTime _jetzt() => DateTime(2026, 10, 7, 10, 30);

LogQuelle _appQuelle() => LogQuelle(
  titelKey: 'debug_logs_app_title',
  heuteKey: 'debug_logs_app_today',
  dateiKennung: 'app',
  lesen: () async => appLogStoryContent,
  loeschen: () async {},
  eintraege: (content) => [
    for (final entry in AppLogEntry.parseAll(content))
      LogEintragInfo(entry.timestamp, fehler: entry.level == 'error'),
  ],
  ansicht: (content, zeitfenster, zeitraumAuswahl, onAusschnitt) => AppLogView(
    content: content,
    nowProvider: _jetzt,
    zeitfenster: zeitfenster,
    zeitraumAuswahl: zeitraumAuswahl,
    onAusschnitt: onAusschnitt,
  ),
);

LogQuelle _trafficQuelle() => LogQuelle(
  titelKey: 'debug_logs_traffic_title',
  heuteKey: 'debug_logs_traffic_today',
  dateiKennung: 'traffic',
  lesen: () async => hitobitoTrafficStoryContent,
  loeschen: () async {},
  eintraege: (content) => [
    for (final line in content.split('\n'))
      if (HitobitoTrafficLogEntry.tryParse(line) case final entry?)
        LogEintragInfo(entry.timestamp, fehler: entry.isError),
  ],
  ansicht: (content, zeitfenster, zeitraumAuswahl, onAusschnitt) =>
      HitobitoTrafficLogView(
        content: content,
        zeitfenster: zeitfenster,
        zeitraumAuswahl: zeitraumAuswahl,
        onAusschnitt: onAusschnitt,
      ),
);

Story logViewerPageStory() {
  return Story(
    name: 'Einstellungen/Screens/Log-Ansicht',
    builder: (context) {
      final traffic = context.knobs.boolean(
        label: 'Traffic-Log',
        initial: false,
      );
      return LogViewerPage(
        key: ValueKey<bool>(traffic),
        quelle: traffic ? _trafficQuelle() : _appQuelle(),
        nowProvider: _jetzt,
      );
    },
  );
}
