import 'stufe.dart';

/// Art der Tätigkeit eines Mitglieds (Rolle in der Gruppe).
enum TaetigkeitsArt { mitglied, leitung, sonstiges }

extension TaetigkeitsArtProps on TaetigkeitsArt {
  String get displayName => switch (this) {
    TaetigkeitsArt.mitglied => 'Mitglied',
    TaetigkeitsArt.leitung => 'Leitung',
    TaetigkeitsArt.sonstiges => 'Sonstiges',
  };
}

/// Eine Tätigkeit beschreibt den Zeitraum und die Rolle einer Person in einer Stufe.
class Taetigkeit {
  Taetigkeit({
    required this.stufe,
    required this.art,
    required this.start,
    this.ende,
    this.permission,
  });

  final Stufe stufe;
  final TaetigkeitsArt art;
  final DateTime start;
  final DateTime? ende;
  final String? permission;

  bool get istAktiv => ende == null || ende!.isAfter(DateTime.now());

  Taetigkeit copyWith({
    Stufe? stufe,
    TaetigkeitsArt? art,
    DateTime? start,
    DateTime? ende,
    String? permission,
  }) => Taetigkeit(
    stufe: stufe ?? this.stufe,
    art: art ?? this.art,
    start: start ?? this.start,
    ende: ende ?? this.ende,
    permission: permission ?? this.permission,
  );

  @override
  bool operator ==(Object other) {
    return other is Taetigkeit &&
        other.stufe == stufe &&
        other.art == art &&
        other.start == start &&
        other.ende == ende;
  }

  @override
  int get hashCode => Object.hash(stufe, art, start, ende);

  @override
  String toString() =>
      'Taetigkeit(stufe: $stufe, art: $art, start: $start, ende: $ende, permission: $permission)';
}
