import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';

// find user by id in mitglied list
Mitglied? findMitgliedById(int id) {
  List<Mitglied> mitglieder = Hive.box<Mitglied>(
    'members',
  ).values.toList().cast<Mitglied>();
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
