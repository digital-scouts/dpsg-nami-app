import 'bundesaggregat.dart';
import 'installation_credentials.dart';
import 'stammes_snapshot.dart';

enum BundesstatistikFehlerArt {
  /// Der Server kennt die Installations-ID mit einem anderen Secret.
  ungueltigeCredentials,

  /// Noch nie oder seit mehr als 14 Tagen kein Snapshot erfolgreich gesendet.
  nichtTeilnehmend,
  zuVieleAnfragen,

  /// Der Server hat den Snapshot fachlich abgelehnt (400).
  abgelehnt,
  netzwerk,
  unbekannt,
}

class BundesstatistikException implements Exception {
  const BundesstatistikException(this.art, {this.code, this.statusCode});

  final BundesstatistikFehlerArt art;
  final String? code;
  final int? statusCode;

  @override
  String toString() =>
      'BundesstatistikException(art: ${art.name}, code: $code, statusCode: $statusCode)';
}

abstract class BundesstatistikRepository {
  Future<void> sendeSnapshot(
    StammesSnapshot snapshot,
    InstallationCredentials credentials,
  );

  Future<Bundesaggregat> ladeBundesaggregat(
    InstallationCredentials credentials,
  );
}
