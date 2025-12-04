class FzDocument {
  final int id;
  final DateTime erstelltAm;
  final String fzNummer;
  final String empfaenger;
  final String empfaengerNachname;
  final String empfaengerVorname;
  final DateTime empfaengerGebDatum;
  final DateTime datumEinsicht;
  final DateTime fzDatum;
  final String autor;

  FzDocument({
    required this.id,
    required this.erstelltAm,
    required this.fzNummer,
    required this.empfaenger,
    required this.empfaengerNachname,
    required this.empfaengerVorname,
    required this.empfaengerGebDatum,
    required this.datumEinsicht,
    required this.fzDatum,
    required this.autor,
  });

  factory FzDocument.fromJson(Map<String, dynamic> json) {
    return FzDocument(
      id: json['id'],
      erstelltAm: DateTime.parse(json['entries_erstelltAm']),
      fzNummer: json['entries_fzNummer'],
      empfaenger: json['entries_empfaenger'],
      empfaengerNachname: json['entries_empfNachname'],
      empfaengerVorname: json['entries_empfVorname'],
      empfaengerGebDatum: DateTime.parse(json['entries_empfGebDatum']),
      datumEinsicht: DateTime.parse(json['entries_datumEinsicht']),
      fzDatum: DateTime.parse(json['entries_fzDatum']),
      autor: json['entries_autor'],
    );
  }
}
