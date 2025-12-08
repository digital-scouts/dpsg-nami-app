import '../../domain/stufe/altersgrenzen.dart';

class StufenSettings {
  final Altersgrenzen grenzen;
  final DateTime? stufenwechselDatum;

  const StufenSettings({required this.grenzen, this.stufenwechselDatum});

  StufenSettings copyWith({
    Altersgrenzen? grenzen,
    DateTime? stufenwechselDatum,
  }) => StufenSettings(
    grenzen: grenzen ?? this.grenzen,
    stufenwechselDatum: stufenwechselDatum ?? this.stufenwechselDatum,
  );
}
