// Domain-Schicht: keine UI-Abhängigkeiten hier.

enum Stufe { biber, woelfling, jungpfadfinder, pfadfinder, rover, leitung }

extension StufeProps on Stufe {
  /// Anzeigename (lokalisiert später via I18n Layer)
  String get displayName => switch (this) {
    Stufe.biber => 'Biber',
    Stufe.woelfling => 'Wölfling',
    Stufe.jungpfadfinder => 'Jungpfadfinder',
    Stufe.pfadfinder => 'Pfadfinder',
    Stufe.rover => 'Rover',
    Stufe.leitung => 'Leitung',
  };

  String get shortDisplayName => switch (this) {
    Stufe.biber => 'Biber',
    Stufe.woelfling => 'Wö',
    Stufe.jungpfadfinder => 'Jufi',
    Stufe.pfadfinder => 'Pfadi',
    Stufe.rover => 'Rover',
    Stufe.leitung => 'Leitung',
  };

  // Keine Farben/Assets hier – diese gehören in die Presentation-Schicht.

  num get order => switch (this) {
    Stufe.biber => 1,
    Stufe.woelfling => 2,
    Stufe.jungpfadfinder => 3,
    Stufe.pfadfinder => 4,
    Stufe.rover => 5,
    Stufe.leitung => 6,
  };

  num get defaultMinAge => switch (this) {
    Stufe.biber => 4,
    Stufe.woelfling => 6,
    Stufe.jungpfadfinder => 9,
    Stufe.pfadfinder => 12,
    Stufe.rover => 15,
    Stufe.leitung => 18,
  };

  num get defaultMaxAge => switch (this) {
    Stufe.biber => 7,
    Stufe.woelfling => 11,
    Stufe.jungpfadfinder => 14,
    Stufe.pfadfinder => 17,
    Stufe.rover => 21,
    Stufe.leitung => 99,
  };

  Stufe? get nextStufe => switch (this) {
    Stufe.biber => Stufe.woelfling,
    Stufe.woelfling => Stufe.jungpfadfinder,
    Stufe.jungpfadfinder => Stufe.pfadfinder,
    Stufe.pfadfinder => Stufe.rover,
    Stufe.rover => null,
    Stufe.leitung => null,
  };
}
