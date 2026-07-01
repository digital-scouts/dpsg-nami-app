enum Beitragsart {
  ordentlicheMitgliedschaft,
  foerdermitgliedschaft,
  zweitmitgliedschaft,
}

extension BeitragsartProps on Beitragsart {
  String get displayName => switch (this) {
    Beitragsart.ordentlicheMitgliedschaft => 'Ordentliche Mitgliedschaft',
    Beitragsart.foerdermitgliedschaft => 'Foerdermitgliedschaft',
    Beitragsart.zweitmitgliedschaft => 'Zweitmitgliedschaft',
  };
}
