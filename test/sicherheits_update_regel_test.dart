import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/app_update/sicherheits_update_regel.dart';

void main() {
  const regel = SicherheitsUpdateRegel();
  final start = DateTime(2026, 10, 10, 9);

  test('fragt zuerst mit zwei verbleibenden Aufschueben nach', () {
    final lage = regel.lage(SicherheitsUpdateStand.leer, now: start);

    expect(lage.art, SicherheitsUpdateLageArt.nachfrage);
    expect(lage.verbleibendeAufschuebe, 2);
  });

  test('wartet nach „Später“ drei Stunden', () {
    final stand = regel.spaeter(SicherheitsUpdateStand.leer, now: start);

    final gleich = regel.lage(stand, now: start.add(const Duration(hours: 1)));
    expect(gleich.art, SicherheitsUpdateLageArt.warten);
    expect(gleich.ab, start.add(const Duration(hours: 3)));

    final spaeter = regel.lage(stand, now: start.add(const Duration(hours: 3)));
    expect(spaeter.art, SicherheitsUpdateLageArt.nachfrage);
    expect(spaeter.verbleibendeAufschuebe, 1);
  });

  test('zaehlt nach dem zweiten „Später“ herunter und sperrt dann', () {
    var stand = regel.spaeter(SicherheitsUpdateStand.leer, now: start);
    final zweites = start.add(const Duration(hours: 3));
    stand = regel.spaeter(stand, now: zweites);

    final countdown = regel.lage(
      stand,
      now: zweites.add(const Duration(minutes: 30)),
    );
    expect(countdown.art, SicherheitsUpdateLageArt.countdown);
    expect(countdown.ab, zweites.add(const Duration(hours: 3)));

    final danach = zweites.add(const Duration(hours: 3));
    expect(
      regel.lage(stand, now: danach).art,
      SicherheitsUpdateLageArt.gesperrt,
    );
    final gesperrt = regel.mitSperreWennFaellig(stand, now: danach);
    expect(gesperrt.gesperrt, isTrue);
    // Die Sperre bleibt, auch wenn die Uhr zurueckgestellt wird.
    expect(
      regel.lage(gesperrt, now: start).art,
      SicherheitsUpdateLageArt.gesperrt,
    );
  });

  test('zurueckgestellte Uhr verlaengert keine Wartezeit', () {
    final stand = regel.spaeter(SicherheitsUpdateStand.leer, now: start);

    final lage = regel.lage(
      stand,
      now: start.subtract(const Duration(days: 1)),
    );
    expect(lage.art, SicherheitsUpdateLageArt.nachfrage);
  });

  test('speichert und laedt den Stand', () {
    final stand = regel.spaeter(SicherheitsUpdateStand.leer, now: start);

    final geladen = SicherheitsUpdateStand.fromJson(stand.toJson());

    expect(geladen.aufschuebe, 1);
    expect(geladen.naechsteAnzeigeAb, stand.naechsteAnzeigeAb);
    expect(geladen.gesperrt, isFalse);
  });
}
