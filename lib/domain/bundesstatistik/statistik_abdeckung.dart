/// Welcher Teil eines Stammes fuer die angemeldete Person lesbar ist.
///
/// Wer den ganzen Stamm lesen darf, teilt Stammeszahlen. Wer nur einzelne
/// Gruppen lesen darf (z. B. `group_read` als Leitung einer Meute), teilt nur
/// die Werte dieser Gruppen; stammweite Zahlen waeren aus einer Teilsicht falsch.
///
/// Hitobito liefert Rollen, Qualifikationen und EFZ ueber die JSON:API nur fuer
/// voll lesbare Personen (`group_full` bzw. `layer_*`). Gruppen, die nur per
/// `group_read` lesbar sind und fuer die keine fremden Rollen ankommen, stehen
/// deshalb in [gruppenOhneRollen] statt in [gruppenIds]: Ihre Zahlen sind
/// unbekannt, nicht 0.
class StatistikAbdeckung {
  const StatistikAbdeckung.stamm()
    : _gruppenIds = null,
      gruppenOhneRollen = const <int>{},
      vollLesbareGruppenIds = const <int>{};

  StatistikAbdeckung.gruppen(
    Iterable<int> gruppenIds, {
    Iterable<int> gruppenOhneRollen = const <int>[],
    Iterable<int> vollLesbareGruppenIds = const <int>[],
  }) : _gruppenIds = Set<int>.unmodifiable(gruppenIds),
       gruppenOhneRollen = Set<int>.unmodifiable(gruppenOhneRollen),
       vollLesbareGruppenIds = Set<int>.unmodifiable(vollLesbareGruppenIds);

  final Set<int>? _gruppenIds;

  /// Lesbare Gruppen, fuer die Hitobito keine Rollen anderer Personen liefert.
  final Set<int> gruppenOhneRollen;

  /// Gruppen, deren Personen voll lesbar sind (`group_full`,
  /// `group_and_below_full`); leer bei [istStamm].
  final Set<int> vollLesbareGruppenIds;

  bool get istStamm => _gruppenIds == null;

  /// Lesbare Gruppen mit Rollen bei Teilsicht; leer bei [istStamm].
  Set<int> get gruppenIds => _gruppenIds ?? const <int>{};

  bool deckt(int gruppenId) => istStamm || gruppenIds.contains(gruppenId);

  /// Nur der Teil, der im Snapshot steht (Stamm oder abgedeckte Gruppen);
  /// zum Vergleich mit einem zuletzt gesendeten Snapshot.
  StatistikAbdeckung get alsGesendet =>
      istStamm ? this : StatistikAbdeckung.gruppen(gruppenIds);

  /// Ob Personen mit Rollen in [gruppenIdsDerPerson] voll lesbar sind, Hitobito
  /// also auch Qualifikationen und EFZ liefert.
  bool istVollLesbar(Iterable<int> gruppenIdsDerPerson) =>
      istStamm || gruppenIdsDerPerson.any(vollLesbareGruppenIds.contains);

  @override
  bool operator ==(Object other) =>
      other is StatistikAbdeckung &&
      other.istStamm == istStamm &&
      _gleich(other.gruppenIds, gruppenIds) &&
      _gleich(other.gruppenOhneRollen, gruppenOhneRollen) &&
      _gleich(other.vollLesbareGruppenIds, vollLesbareGruppenIds);

  static bool _gleich(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => istStamm
      ? 0
      : Object.hash(
          Object.hashAllUnordered(gruppenIds),
          Object.hashAllUnordered(gruppenOhneRollen),
          Object.hashAllUnordered(vollLesbareGruppenIds),
        );

  @override
  String toString() => istStamm
      ? 'StatistikAbdeckung.stamm()'
      : 'StatistikAbdeckung.gruppen($gruppenIds, '
            'gruppenOhneRollen: $gruppenOhneRollen, '
            'vollLesbareGruppenIds: $vollLesbareGruppenIds)';
}
