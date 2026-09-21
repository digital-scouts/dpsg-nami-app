import 'package:nami/domain/taetigkeit/stufe.dart';

class AltersIntervall {
  final int minJahre;
  final int maxJahre;
  const AltersIntervall({required this.minJahre, required this.maxJahre});

  AltersIntervall copyWith({int? minJahre, int? maxJahre}) => AltersIntervall(
    minJahre: minJahre ?? this.minJahre,
    maxJahre: maxJahre ?? this.maxJahre,
  );
}

class Altersgrenzen {
  final Map<Stufe, AltersIntervall> grenzen;
  const Altersgrenzen(this.grenzen);

  AltersIntervall forStufe(Stufe stufe) {
    final v = grenzen[stufe];
    if (v != null) return v;
    // Fallback: benutze statische Defaults ohne Rekursion
    return StufenDefaults.intervalFor(stufe);
  }

  Altersgrenzen copyWithFor(Stufe stufe, AltersIntervall intervall) {
    final m = Map<Stufe, AltersIntervall>.from(grenzen);
    m[stufe] = intervall;
    return Altersgrenzen(m);
  }
}

class StufenDefaults {
  static Altersgrenzen build() {
    final m = <Stufe, AltersIntervall>{
      Stufe.biber: const AltersIntervall(minJahre: 4, maxJahre: 7),
      Stufe.woelfling: const AltersIntervall(minJahre: 6, maxJahre: 10),
      Stufe.jungpfadfinder: const AltersIntervall(minJahre: 9, maxJahre: 13),
      Stufe.pfadfinder: const AltersIntervall(minJahre: 12, maxJahre: 16),
      Stufe.rover: const AltersIntervall(minJahre: 15, maxJahre: 20),
    };
    return Altersgrenzen(m);
  }

  static AltersIntervall intervalFor(Stufe stufe) {
    switch (stufe) {
      case Stufe.biber:
        return const AltersIntervall(minJahre: 5, maxJahre: 6);
      case Stufe.woelfling:
        return const AltersIntervall(minJahre: 6, maxJahre: 10);
      case Stufe.jungpfadfinder:
        return const AltersIntervall(minJahre: 11, maxJahre: 13);
      case Stufe.pfadfinder:
        return const AltersIntervall(minJahre: 14, maxJahre: 16);
      case Stufe.rover:
        return const AltersIntervall(minJahre: 17, maxJahre: 20);
      case Stufe.leitung:
        return const AltersIntervall(minJahre: 18, maxJahre: 99);
    }
  }
}
