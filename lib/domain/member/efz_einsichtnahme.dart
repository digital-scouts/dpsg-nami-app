class EfzEinsichtnahme {
  const EfzEinsichtnahme({
    required this.id,
    required this.personId,
    this.einsichtnehmerId,
    this.einsichtOn,
    this.issuedOn,
  }) : assert(id > 0),
       assert(personId > 0);

  final int id;
  final int personId;
  final int? einsichtnehmerId;
  final DateTime? einsichtOn;
  final DateTime? issuedOn;

  @override
  bool operator ==(Object other) {
    return other is EfzEinsichtnahme &&
        other.id == id &&
        other.personId == personId &&
        other.einsichtnehmerId == einsichtnehmerId &&
        other.einsichtOn == einsichtOn &&
        other.issuedOn == issuedOn;
  }

  @override
  int get hashCode =>
      Object.hash(id, personId, einsichtnehmerId, einsichtOn, issuedOn);

  @override
  String toString() {
    return 'EfzEinsichtnahme(id: $id, personId: $personId, '
        'einsichtnehmerId: $einsichtnehmerId, einsichtOn: $einsichtOn, '
        'issuedOn: $issuedOn)';
  }
}
