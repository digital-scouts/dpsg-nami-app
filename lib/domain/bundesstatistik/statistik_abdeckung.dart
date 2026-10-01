/// Welcher Teil eines Stammes fuer die angemeldete Person lesbar ist.
///
/// Wer den ganzen Stamm lesen darf, teilt Stammeszahlen. Wer nur einzelne
/// Gruppen lesen darf (z. B. `group_read` als Leitung einer Meute), teilt nur
/// die Werte dieser Gruppen; stammweite Zahlen waeren aus einer Teilsicht falsch.
class StatistikAbdeckung {
  const StatistikAbdeckung.stamm() : _gruppenIds = null;

  StatistikAbdeckung.gruppen(Iterable<int> gruppenIds)
    : _gruppenIds = Set<int>.unmodifiable(gruppenIds);

  final Set<int>? _gruppenIds;

  bool get istStamm => _gruppenIds == null;

  /// Lesbare Gruppen bei Teilsicht; leer bei [istStamm].
  Set<int> get gruppenIds => _gruppenIds ?? const <int>{};

  bool deckt(int gruppenId) => istStamm || gruppenIds.contains(gruppenId);

  @override
  bool operator ==(Object other) =>
      other is StatistikAbdeckung &&
      other.istStamm == istStamm &&
      other.gruppenIds.length == gruppenIds.length &&
      other.gruppenIds.containsAll(gruppenIds);

  @override
  int get hashCode =>
      istStamm ? 0 : Object.hashAllUnordered(gruppenIds.toList());

  @override
  String toString() => istStamm
      ? 'StatistikAbdeckung.stamm()'
      : 'StatistikAbdeckung.gruppen($gruppenIds)';
}
