import 'package:flutter/foundation.dart';

import '../../domain/qualifikation/qualifikations_einstellungen.dart';
import '../../domain/qualifikation/qualifikations_einstellungen_repository.dart';

/// App-weite Einstellungen der Qualifikationen; jede Aenderung wird sofort
/// gespeichert.
class QualifikationsEinstellungenModel extends ChangeNotifier {
  QualifikationsEinstellungenModel(this._repository);

  final QualifikationsEinstellungenRepository _repository;

  QualifikationsEinstellungen _einstellungen =
      const QualifikationsEinstellungen();
  bool _geladen = false;

  QualifikationsEinstellungen get einstellungen => _einstellungen;
  bool get geladen => _geladen;

  Future<void> load() async {
    _einstellungen = await _repository.load();
    _geladen = true;
    notifyListeners();
  }

  Future<void> aendern(
    QualifikationsEinstellungen Function(QualifikationsEinstellungen) aenderung,
  ) async {
    final neu = aenderung(_einstellungen);
    if (neu == _einstellungen) {
      return;
    }
    _einstellungen = neu;
    notifyListeners();
    await _repository.save(neu);
  }

  Future<void> artAendern(
    String schluessel,
    ArtEinstellung Function(ArtEinstellung) aenderung,
  ) => aendern((alt) => alt.mitArt(schluessel, aenderung(alt.art(schluessel))));
}
