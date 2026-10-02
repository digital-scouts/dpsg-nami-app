import '../../../domain/member/mitglied_zeitraeume.dart';
import '../../../l10n/app_localizations.dart';

/// Dauer fuer Kacheln: bis zwei Jahre ausgeschrieben („7 Tage“, „3 Wochen“,
/// „5 Monate“), danach kurz („22 J.“).
String mitgliedDauerText(AppLocalizations t, DateTime von, DateTime bis) {
  final tage = tageZwischen(von, bis);
  if (tage < 14) {
    return tage == 1 ? t.t('dauer_tag') : t.t('dauer_tage', {'n': tage});
  }
  if (tage < 70) {
    final wochen = (tage / 7).round();
    return t.t('dauer_wochen', {'n': wochen});
  }
  final monate = monateZwischen(von, bis);
  if (monate < 24) {
    return monate == 1
        ? t.t('dauer_monat')
        : t.t('dauer_monate', {'n': monate});
  }
  return t.t('dauer_jahre_kurz', {'n': monate ~/ 12});
}
