import 'qualifikations_einstellungen.dart';

/// Speichert die Einstellungen der Qualifikationen-Uebersicht pro App.
abstract class QualifikationsEinstellungenRepository {
  Future<QualifikationsEinstellungen> load();

  Future<void> save(QualifikationsEinstellungen einstellungen);
}
