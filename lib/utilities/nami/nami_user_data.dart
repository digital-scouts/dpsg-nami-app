import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';

List<Mitglied> mitglieder =
    Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();

// find user by id in mitglied list
Mitglied? findMitgliedById(int id) {
  for (var mitglied in mitglieder) {
    if (mitglied.mitgliedsNummer == id) {
      return mitglied;
    }
  }
  return null;
}

Mitglied? findCurrentUser() {
  int? mitgliedsnummer = getNamiLoginId();
  return findMitgliedById(mitgliedsnummer!);
}
