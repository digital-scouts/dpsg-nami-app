import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/domain/member/mitglied.dart';

const _primaryEmail = MitgliedKontaktEmail(
  wert: 'julia@example.org',
  label: Mitglied.primaryEmailLabel,
  istPrimaer: true,
);
const _elternEmail = MitgliedKontaktEmail(
  additionalEmailId: 31,
  wert: 'eltern@example.org',
  label: Mitglied.secondaryEmailLabel,
);
const _mobil = MitgliedKontaktTelefon(
  phoneNumberId: 11,
  wert: '+49 170 1111111',
  label: Mitglied.phoneMobileLabel,
);
const _festnetz = MitgliedKontaktTelefon(
  phoneNumberId: 12,
  wert: '+49 30 2222222',
  label: Mitglied.phoneLandlineLabel,
);
const _hauptadresse = MitgliedKontaktAdresse(
  street: 'Hauptstrasse',
  housenumber: '1',
  zipCode: '10115',
  town: 'Berlin',
  country: 'DE',
);
const _zusatzadresse = MitgliedKontaktAdresse(
  additionalAddressId: 41,
  label: 'Oma',
  street: 'Nebenweg',
  housenumber: '2',
  zipCode: '20095',
  town: 'Hamburg',
  country: 'DE',
);

Mitglied _basis() {
  return Mitglied.peopleListItem(
    mitgliedsnummer: '4711',
    personId: 23,
    vorname: 'Julia',
    nachname: 'Keller',
    fahrtenname: 'Falke',
    gender: 'w',
    updatedAt: DateTime(2026, 4, 14, 12, 0),
    telefonnummern: const <MitgliedKontaktTelefon>[_mobil, _festnetz],
    emailAdressen: const <MitgliedKontaktEmail>[_primaryEmail, _elternEmail],
    adressen: const <MitgliedKontaktAdresse>[_hauptadresse, _zusatzadresse],
  ).copyWith(geburtsdatum: DateTime(2010, 5, 1));
}

MemberMergePlan _resolve({
  required Mitglied basis,
  Mitglied? ziel,
  Mitglied? remote,
}) {
  return MemberConflictResolver.resolve(
    basisMitglied: basis,
    zielMitglied: ziel ?? basis,
    remoteMitglied: remote ?? basis,
  );
}

Mitglied _withPrimaryEmail(Mitglied mitglied, String wert) {
  return mitglied.copyWith(
    emailAdressen: <MitgliedKontaktEmail>[
      _primaryEmail.copyWith(wert: wert),
      ...mitglied.emailAdressen.where((email) => !email.istPrimaer),
    ],
  );
}

Mitglied _withPrimaryAddress(Mitglied mitglied, String street) {
  return mitglied.copyWith(
    adressen: <MitgliedKontaktAdresse>[
      _hauptadresse.copyWith(street: street),
      ...mitglied.adressen.skip(1),
    ],
  );
}

Mitglied _withPhones(Mitglied mitglied, List<MitgliedKontaktTelefon> phones) {
  return mitglied.copyWith(telefonnummern: phones);
}

Mitglied _withAdditionalEmails(
  Mitglied mitglied,
  List<MitgliedKontaktEmail> emails,
) {
  return mitglied.copyWith(
    emailAdressen: <MitgliedKontaktEmail>[
      ...mitglied.emailAdressen.where((email) => email.istPrimaer),
      ...emails,
    ],
  );
}

Mitglied _withAdditionalAddresses(
  Mitglied mitglied,
  List<MitgliedKontaktAdresse> addresses,
) {
  return mitglied.copyWith(
    adressen: <MitgliedKontaktAdresse>[
      ...mitglied.adressen.take(1),
      ...addresses,
    ],
  );
}

class _ScalarCase {
  const _ScalarCase({
    required this.name,
    required this.targetType,
    required this.change,
    required this.read,
  });

  final String name;
  final MemberResolutionTargetType targetType;
  final Mitglied Function(Mitglied mitglied, String variant) change;
  final Object? Function(Mitglied mitglied) read;
}

final _scalarCases = <_ScalarCase>[
  _ScalarCase(
    name: 'Vorname',
    targetType: MemberResolutionTargetType.firstName,
    change: (m, v) => m.copyWith(vorname: 'Vorname-$v'),
    read: (m) => m.vorname,
  ),
  _ScalarCase(
    name: 'Nachname',
    targetType: MemberResolutionTargetType.lastName,
    change: (m, v) => m.copyWith(nachname: 'Nachname-$v'),
    read: (m) => m.nachname,
  ),
  _ScalarCase(
    name: 'Fahrtenname',
    targetType: MemberResolutionTargetType.nickname,
    change: (m, v) => m.copyWith(fahrtenname: 'Fahrt-$v'),
    read: (m) => m.fahrtenname,
  ),
  _ScalarCase(
    name: 'Geschlecht',
    targetType: MemberResolutionTargetType.gender,
    change: (m, v) => m.copyWith(gender: v == 'lokal' ? 'm' : 'd'),
    read: (m) => m.gender,
  ),
  _ScalarCase(
    name: 'Geburtsdatum',
    targetType: MemberResolutionTargetType.birthday,
    change: (m, v) =>
        m.copyWith(geburtsdatum: DateTime(2011, v == 'lokal' ? 2 : 3, 4)),
    read: (m) => m.geburtsdatum,
  ),
  _ScalarCase(
    name: 'primaere E-Mail',
    targetType: MemberResolutionTargetType.primaryEmail,
    change: (m, v) => _withPrimaryEmail(m, '$v@example.org'),
    read: (m) => m.emailAdressen.firstWhere((email) => email.istPrimaer).wert,
  ),
  _ScalarCase(
    name: 'primaere Adresse',
    targetType: MemberResolutionTargetType.primaryAddress,
    change: (m, v) => _withPrimaryAddress(m, 'Strasse-$v'),
    read: (m) => m.primaryAddress,
  ),
];

void main() {
  group('MemberConflictResolver skalare Felder', () {
    for (final scalarCase in _scalarCases) {
      group(scalarCase.name, () {
        test('uebernimmt nur lokale Aenderung ohne Konflikt', () {
          final basis = _basis();
          final ziel = scalarCase.change(basis, 'lokal');

          final plan = _resolve(basis: basis, ziel: ziel);

          expect(plan.items, isEmpty);
          expect(plan.requiresResolution, isFalse);
          expect(scalarCase.read(plan.mergedMitglied), scalarCase.read(ziel));
          expect(
            scalarCase.read(plan.mergedMitglied),
            isNot(scalarCase.read(basis)),
          );
        });

        test('uebernimmt nur remote Aenderung ohne Konflikt', () {
          final basis = _basis();
          final remote = scalarCase.change(basis, 'remote');

          final plan = _resolve(basis: basis, remote: remote);

          expect(plan.items, isEmpty);
          expect(scalarCase.read(plan.mergedMitglied), scalarCase.read(remote));
        });

        test('meldet keinen Konflikt bei gleicher Aenderung auf beiden '
            'Seiten', () {
          final basis = _basis();
          final ziel = scalarCase.change(basis, 'lokal');
          final remote = scalarCase.change(basis, 'lokal');

          final plan = _resolve(basis: basis, ziel: ziel, remote: remote);

          expect(plan.items, isEmpty);
          expect(scalarCase.read(plan.mergedMitglied), scalarCase.read(ziel));
        });

        test('meldet Konflikt bei unterschiedlicher Aenderung und behaelt '
            'Remote-Wert', () {
          final basis = _basis();
          final ziel = scalarCase.change(basis, 'lokal');
          final remote = scalarCase.change(basis, 'remote');

          final plan = _resolve(basis: basis, ziel: ziel, remote: remote);

          expect(plan.requiresResolution, isTrue);
          expect(plan.items, hasLength(1));
          final item = plan.items.single;
          expect(item.problemType, MemberResolutionProblemType.conflict);
          expect(item.cause, MemberResolutionCause.overlappingChange);
          expect(item.target.type, scalarCase.targetType);
          expect(item.target.relationshipId, isNull);
          expect(item.message, isNotEmpty);
          expect(scalarCase.read(plan.mergedMitglied), scalarCase.read(remote));
        });

        test('liefert Remote-Stand wenn nichts geaendert wurde', () {
          final basis = _basis();

          final plan = _resolve(basis: basis);

          expect(plan.items, isEmpty);
          expect(plan.mergedMitglied, basis);
        });
      });
    }

    test('uebernimmt lokales Leeren von Fahrtenname und Geschlecht', () {
      final basis = _basis();
      final ziel = basis.copyWith(
        fahrtennameLoeschen: true,
        genderLoeschen: true,
      );

      final plan = _resolve(basis: basis, ziel: ziel);

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.fahrtenname, isNull);
      expect(plan.mergedMitglied.gender, isNull);
    });

    test('uebernimmt nicht gemergte Felder wie updatedAt vom Remote-Stand', () {
      final basis = _basis();
      final remote = basis.copyWith(
        updatedAt: DateTime(2026, 4, 15, 8, 0),
        pronoun: 'sie',
      );
      final ziel = basis.copyWith(vorname: 'Juliane', pronoun: 'er');

      final plan = _resolve(basis: basis, ziel: ziel, remote: remote);

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.vorname, 'Juliane');
      expect(plan.mergedMitglied.updatedAt, DateTime(2026, 4, 15, 8, 0));
      expect(plan.mergedMitglied.pronoun, 'sie');
    });

    test('sammelt mehrere Konflikte in fester Feldreihenfolge', () {
      final basis = _basis();
      final ziel = basis.copyWith(vorname: 'A', nachname: 'B');
      final remote = basis.copyWith(vorname: 'C', nachname: 'D');

      final plan = _resolve(basis: basis, ziel: ziel, remote: remote);

      expect(plan.items.map((item) => item.target.type), <Object>[
        MemberResolutionTargetType.firstName,
        MemberResolutionTargetType.lastName,
      ]);
    });

    test(
      'setzt primaere E-Mail beim Merge immer mit Standardlabel neu auf',
      () {
        final basis = _basis();
        final remote = basis.copyWith(
          emailAdressen: <MitgliedKontaktEmail>[
            _primaryEmail.copyWith(label: 'Privat'),
            _elternEmail,
          ],
        );

        final plan = _resolve(basis: basis, remote: remote);

        final primary = plan.mergedMitglied.emailAdressen.first;
        expect(primary.istPrimaer, isTrue);
        expect(primary.wert, _primaryEmail.wert);
        expect(primary.label, Mitglied.primaryEmailLabel);
      },
    );

    test('entfernt primaere E-Mail wenn sie lokal geloescht wurde', () {
      final basis = _basis();
      final ziel = basis.copyWith(
        emailAdressen: const <MitgliedKontaktEmail>[_elternEmail],
      );

      final plan = _resolve(basis: basis, ziel: ziel);

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.emailAdressen, <MitgliedKontaktEmail>[
        _elternEmail,
      ]);
    });
  });

  group('MemberConflictResolver Telefonnummern', () {
    test('uebernimmt lokale Aenderung einer Telefonnummer', () {
      final basis = _basis();
      final lokal = _mobil.copyWith(wert: '+49 170 9999999');
      final ziel = _withPhones(basis, [lokal, _festnetz]);

      final plan = _resolve(basis: basis, ziel: ziel);

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [lokal, _festnetz]);
    });

    test('uebernimmt remote Aenderung einer Telefonnummer', () {
      final basis = _basis();
      final remoteFestnetz = _festnetz.copyWith(wert: '+49 30 3333333');
      final remote = _withPhones(basis, [_mobil, remoteFestnetz]);

      final plan = _resolve(basis: basis, remote: remote);

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [_mobil, remoteFestnetz]);
    });

    test('mischt lokale und remote Aenderungen an verschiedenen Nummern', () {
      final basis = _basis();
      final lokal = _mobil.copyWith(wert: '+49 170 9999999');
      final remoteFestnetz = _festnetz.copyWith(wert: '+49 30 3333333');

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [lokal, _festnetz]),
        remote: _withPhones(basis, [_mobil, remoteFestnetz]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [lokal, remoteFestnetz]);
    });

    test('meldet Konflikt mit relationshipId bei unterschiedlicher '
        'Aenderung derselben Nummer und behaelt Remote-Wert', () {
      final basis = _basis();
      final lokal = _mobil.copyWith(wert: '+49 170 9999999');
      final remoteMobil = _mobil.copyWith(wert: '+49 170 8888888');

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [lokal, _festnetz]),
        remote: _withPhones(basis, [remoteMobil, _festnetz]),
      );

      expect(plan.items, hasLength(1));
      final item = plan.items.single;
      expect(item.problemType, MemberResolutionProblemType.conflict);
      expect(item.cause, MemberResolutionCause.overlappingChange);
      expect(
        item.target,
        const MemberResolutionTarget(
          type: MemberResolutionTargetType.phone,
          relationshipId: 11,
        ),
      );
      expect(plan.mergedMitglied.telefonnummern, [remoteMobil, _festnetz]);
    });

    test('meldet keinen Konflikt bei identischer Aenderung derselben '
        'Nummer', () {
      final basis = _basis();
      final geaendert = _mobil.copyWith(wert: '+49 170 9999999');

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [geaendert, _festnetz]),
        remote: _withPhones(basis, [geaendert, _festnetz]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [geaendert, _festnetz]);
    });

    test('entfernt lokal geloeschte Nummer wenn remote unveraendert', () {
      final basis = _basis();

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [_festnetz]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [_festnetz]);
    });

    test('entfernt remote geloeschte Nummer wenn lokal unveraendert', () {
      final basis = _basis();

      final plan = _resolve(
        basis: basis,
        remote: _withPhones(basis, [_festnetz]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [_festnetz]);
    });

    test('meldet Konflikt wenn lokal geloescht aber remote geaendert und '
        'behaelt Remote-Wert', () {
      final basis = _basis();
      final remoteMobil = _mobil.copyWith(wert: '+49 170 8888888');

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [_festnetz]),
        remote: _withPhones(basis, [remoteMobil, _festnetz]),
      );

      expect(plan.items, hasLength(1));
      expect(plan.items.single.target.relationshipId, 11);
      expect(plan.items.single.cause, MemberResolutionCause.overlappingChange);
      expect(plan.mergedMitglied.telefonnummern, [remoteMobil, _festnetz]);
    });

    test('meldet bei lokal geaendert aber remote geloescht einen '
        'remoteDeletedLocalEdited-Konflikt', () {
      final basis = _basis();
      final lokal = _mobil.copyWith(wert: '+49 170 9999999');

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [lokal, _festnetz]),
        remote: _withPhones(basis, [_festnetz]),
      );

      expect(plan.items, hasLength(1));
      final item = plan.items.single;
      expect(item.target.type, MemberResolutionTargetType.phone);
      expect(item.target.relationshipId, 11);
      expect(item.cause, MemberResolutionCause.remoteDeletedLocalEdited);
      expect(item.message, contains('in Hitobito aber gelöscht'));
    });

    test('meldet keinen Konflikt wenn Nummer auf beiden Seiten geloescht '
        'wurde', () {
      final basis = _basis();

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [_festnetz]),
        remote: _withPhones(basis, [_festnetz]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [_festnetz]);
    });

    test('haengt neue lokale Nummer ohne id hinter die Nummern mit id an', () {
      final basis = _basis();
      const neu = MitgliedKontaktTelefon(
        wert: '+49 171 5555555',
        label: Mitglied.phoneBusinessLabel,
      );
      final remoteFestnetz = _festnetz.copyWith(wert: '+49 30 3333333');

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [neu, _mobil, _festnetz]),
        remote: _withPhones(basis, [_mobil, remoteFestnetz]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [_mobil, remoteFestnetz, neu]);
    });

    test('uebernimmt neue remote Nummer mit id', () {
      final basis = _basis();
      const remoteNeu = MitgliedKontaktTelefon(
        phoneNumberId: 13,
        wert: '+49 171 5555555',
      );

      final plan = _resolve(
        basis: basis,
        remote: _withPhones(basis, [_mobil, _festnetz, remoteNeu]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [
        _mobil,
        _festnetz,
        remoteNeu,
      ]);
    });

    test('fuehrt identische Nummer ohne id aus lokal und remote durch '
        'Mitglied-Normalisierung nur einmal', () {
      const ohneId = MitgliedKontaktTelefon(wert: '+49 171 5555555');
      final basis = _withPhones(_basis(), [_mobil, ohneId]);

      final plan = _resolve(basis: basis);

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [_mobil, ohneId]);
    });

    test('ersetzt bei lokaler Aenderung einer Nummer ohne id die alte '
        'Version', () {
      const ohneId = MitgliedKontaktTelefon(wert: '+49 171 5555555');
      final basis = _withPhones(_basis(), [_mobil, ohneId]);
      const lokal = MitgliedKontaktTelefon(wert: '+49 171 6666666');

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [_mobil, lokal]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [_mobil, lokal]);
    });

    test('entfernt lokal geloeschte Nummer ohne id', () {
      const ohneId = MitgliedKontaktTelefon(wert: '+49 171 5555555');
      final basis = _withPhones(_basis(), [_mobil, ohneId]);

      final plan = _resolve(basis: basis, ziel: _withPhones(basis, [_mobil]));

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [_mobil]);
    });

    test('ergaenzt lokal neue Nummer ohne id nicht, wenn sie remote '
        'bereits mit id existiert', () {
      final basis = _basis();
      const lokalNeu = MitgliedKontaktTelefon(wert: '+49 171 5555555');
      const remoteNeu = MitgliedKontaktTelefon(
        phoneNumberId: 13,
        wert: '+49 171 5555555',
      );

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [_mobil, _festnetz, lokalNeu]),
        remote: _withPhones(basis, [_mobil, _festnetz, remoteNeu]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [
        _mobil,
        _festnetz,
        remoteNeu,
      ]);
    });

    test('uebernimmt remote neu hinzugekommene Nummer ohne id', () {
      final basis = _basis();
      const remoteNeu = MitgliedKontaktTelefon(wert: '+49 171 7777777');

      final plan = _resolve(
        basis: basis,
        remote: _withPhones(basis, [_mobil, _festnetz, remoteNeu]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [
        _mobil,
        _festnetz,
        remoteNeu,
      ]);
    });

    test('fuehrt auf beiden Seiten neu angelegte gleiche Nummer ohne id '
        'nur einmal', () {
      final basis = _basis();
      const neu = MitgliedKontaktTelefon(wert: '+49 171 7777777');

      final plan = _resolve(
        basis: basis,
        ziel: _withPhones(basis, [_mobil, _festnetz, neu]),
        remote: _withPhones(basis, [_mobil, _festnetz, neu]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.telefonnummern, [_mobil, _festnetz, neu]);
    });
  });

  group('MemberConflictResolver zusaetzliche E-Mails', () {
    test('uebernimmt lokale Aenderung einer zusaetzlichen E-Mail', () {
      final basis = _basis();
      final lokal = _elternEmail.copyWith(wert: 'mama@example.org');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalEmails(basis, [lokal]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.emailAdressen, [_primaryEmail, lokal]);
    });

    test('uebernimmt remote Aenderung einer zusaetzlichen E-Mail', () {
      final basis = _basis();
      final remote = _elternEmail.copyWith(wert: 'papa@example.org');

      final plan = _resolve(
        basis: basis,
        remote: _withAdditionalEmails(basis, [remote]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.emailAdressen, [_primaryEmail, remote]);
    });

    test('meldet Konflikt mit relationshipId bei unterschiedlicher '
        'Aenderung derselben E-Mail', () {
      final basis = _basis();
      final lokal = _elternEmail.copyWith(wert: 'mama@example.org');
      final remote = _elternEmail.copyWith(wert: 'papa@example.org');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalEmails(basis, [lokal]),
        remote: _withAdditionalEmails(basis, [remote]),
      );

      expect(plan.items, hasLength(1));
      final item = plan.items.single;
      expect(item.problemType, MemberResolutionProblemType.conflict);
      expect(item.cause, MemberResolutionCause.overlappingChange);
      expect(
        item.target,
        const MemberResolutionTarget(
          type: MemberResolutionTargetType.additionalEmail,
          relationshipId: 31,
        ),
      );
      expect(plan.mergedMitglied.emailAdressen, [_primaryEmail, remote]);
    });

    test('entfernt lokal geloeschte E-Mail wenn remote unveraendert', () {
      final basis = _basis();

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalEmails(basis, const []),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.emailAdressen, [_primaryEmail]);
    });

    test('meldet Konflikt wenn lokal geloescht aber remote geaendert', () {
      final basis = _basis();
      final remote = _elternEmail.copyWith(wert: 'papa@example.org');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalEmails(basis, const []),
        remote: _withAdditionalEmails(basis, [remote]),
      );

      expect(plan.items, hasLength(1));
      expect(plan.items.single.target.relationshipId, 31);
      expect(plan.mergedMitglied.emailAdressen, [_primaryEmail, remote]);
    });

    test('meldet bei lokal geaendert aber remote geloescht einen '
        'remoteDeletedLocalEdited-Konflikt fuer die E-Mail', () {
      final basis = _basis();
      final lokal = _elternEmail.copyWith(wert: 'mama@example.org');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalEmails(basis, [lokal]),
        remote: _withAdditionalEmails(basis, const []),
      );

      expect(plan.items, hasLength(1));
      expect(
        plan.items.single.cause,
        MemberResolutionCause.remoteDeletedLocalEdited,
      );
      expect(plan.items.single.target.relationshipId, 31);
    });

    test('haengt neue lokale E-Mail ohne id hinter die primaere und die '
        'E-Mails mit id an', () {
      final basis = _basis();
      const neu = MitgliedKontaktEmail(wert: 'neu@example.org');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalEmails(basis, [neu, _elternEmail]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.emailAdressen, [
        _primaryEmail,
        _elternEmail,
        neu,
      ]);
    });

    test('ersetzt bei lokaler Aenderung einer E-Mail ohne id die alte '
        'Version', () {
      const ohneId = MitgliedKontaktEmail(wert: 'alt@example.org');
      final basis = _withAdditionalEmails(_basis(), [ohneId]);
      const lokal = MitgliedKontaktEmail(wert: 'neu@example.org');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalEmails(basis, [lokal]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.emailAdressen, [_primaryEmail, lokal]);
    });
  });

  group('MemberConflictResolver Zusatzadressen', () {
    test('uebernimmt lokale Aenderung einer Zusatzadresse', () {
      final basis = _basis();
      final lokal = _zusatzadresse.copyWith(town: 'Bremen');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalAddresses(basis, [lokal]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.adressen, [_hauptadresse, lokal]);
    });

    test('uebernimmt remote Aenderung einer Zusatzadresse', () {
      final basis = _basis();
      final remote = _zusatzadresse.copyWith(town: 'Kiel');

      final plan = _resolve(
        basis: basis,
        remote: _withAdditionalAddresses(basis, [remote]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.adressen, [_hauptadresse, remote]);
    });

    test('meldet Konflikt mit relationshipId bei unterschiedlicher '
        'Aenderung derselben Zusatzadresse', () {
      final basis = _basis();
      final lokal = _zusatzadresse.copyWith(town: 'Bremen');
      final remote = _zusatzadresse.copyWith(town: 'Kiel');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalAddresses(basis, [lokal]),
        remote: _withAdditionalAddresses(basis, [remote]),
      );

      expect(plan.items, hasLength(1));
      final item = plan.items.single;
      expect(item.problemType, MemberResolutionProblemType.conflict);
      expect(item.cause, MemberResolutionCause.overlappingChange);
      expect(
        item.target,
        const MemberResolutionTarget(
          type: MemberResolutionTargetType.additionalAddress,
          relationshipId: 41,
        ),
      );
      expect(plan.mergedMitglied.adressen, [_hauptadresse, remote]);
    });

    test('entfernt lokal geloeschte Zusatzadresse wenn remote '
        'unveraendert', () {
      final basis = _basis();

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalAddresses(basis, const []),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.adressen, [_hauptadresse]);
    });

    test('meldet Konflikt wenn Zusatzadresse lokal geloescht aber remote '
        'geaendert', () {
      final basis = _basis();
      final remote = _zusatzadresse.copyWith(town: 'Kiel');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalAddresses(basis, const []),
        remote: _withAdditionalAddresses(basis, [remote]),
      );

      expect(plan.items, hasLength(1));
      expect(plan.items.single.target.relationshipId, 41);
      expect(plan.mergedMitglied.adressen, [_hauptadresse, remote]);
    });

    test('meldet bei lokal geaendert aber remote geloescht einen '
        'remoteDeletedLocalEdited-Konflikt fuer die Adresse', () {
      final basis = _basis();
      final lokal = _zusatzadresse.copyWith(town: 'Bremen');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalAddresses(basis, [lokal]),
        remote: _withAdditionalAddresses(basis, const []),
      );

      expect(plan.items, hasLength(1));
      expect(
        plan.items.single.cause,
        MemberResolutionCause.remoteDeletedLocalEdited,
      );
    });

    test('haengt neue lokale Zusatzadresse ohne id hinten an', () {
      final basis = _basis();
      const neu = MitgliedKontaktAdresse(street: 'Neuweg', town: 'Bonn');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalAddresses(basis, [neu, _zusatzadresse]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.adressen, [
        _hauptadresse,
        _zusatzadresse,
        neu,
      ]);
    });

    test('verwirft leere Zusatzadressen', () {
      final basis = _basis();
      const leer = MitgliedKontaktAdresse(label: 'Leer', street: '  ');

      final plan = _resolve(
        basis: basis,
        ziel: _withAdditionalAddresses(basis, [_zusatzadresse, leer]),
      );

      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.adressen, [_hauptadresse, _zusatzadresse]);
      expect(
        plan.mergedMitglied.adressen.where((address) => address.istLeer),
        isEmpty,
      );
    });

    test('rueckt beim lokalen Leeren der Hauptadresse die Zusatzadresse '
        'nach vorn und uebernimmt sie als Hauptadresse', () {
      final basis = _basis();
      final ziel = basis.copyWith(
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(),
          _zusatzadresse,
        ],
      );

      final plan = _resolve(basis: basis, ziel: ziel);

      expect(ziel.primaryAddress, _zusatzadresse);
      expect(plan.items, isEmpty);
      expect(plan.mergedMitglied.adressen, [_zusatzadresse]);
    });

    test('erzeugt aktuell doppelte Adresse mit gleicher id wenn Hauptadresse '
        'lokal geleert und Zusatzadresse remote geaendert wurde', () {
      final basis = _basis();
      final ziel = basis.copyWith(
        adressen: const <MitgliedKontaktAdresse>[_zusatzadresse],
      );
      final remoteZusatz = _zusatzadresse.copyWith(town: 'Kiel');
      final remote = _withAdditionalAddresses(basis, [remoteZusatz]);

      final plan = _resolve(basis: basis, ziel: ziel, remote: remote);

      expect(plan.items, hasLength(1));
      expect(
        plan.items.single.target.type,
        MemberResolutionTargetType.additionalAddress,
      );
      expect(plan.mergedMitglied.adressen, [_zusatzadresse, remoteZusatz]);
      expect(
        plan.mergedMitglied.adressen.map((a) => a.additionalAddressId),
        <int?>[41, 41],
      );
    });
  });

  group('MemberResolutionItem', () {
    MemberResolutionItem item(
      MemberResolutionProblemType problemType,
      MemberResolutionTargetType targetType, {
      MemberResolutionCause? cause,
      int? relationshipId,
      String? fingerprint,
    }) {
      return MemberResolutionItem(
        problemType: problemType,
        target: MemberResolutionTarget(
          type: targetType,
          relationshipId: relationshipId,
          fingerprint: fingerprint,
        ),
        message: 'Hinweis',
        cause: cause,
      );
    }

    test('leitet overlappingChange als Standardursache fuer Konflikte ab', () {
      for (final targetType in MemberResolutionTargetType.values) {
        expect(
          item(MemberResolutionProblemType.conflict, targetType).effectiveCause,
          MemberResolutionCause.overlappingChange,
          reason: targetType.name,
        );
      }
    });

    test('leitet addressValidation nur fuer Adressziele und sonst '
        'serverValidation ab', () {
      for (final targetType in MemberResolutionTargetType.values) {
        final expected =
            targetType == MemberResolutionTargetType.primaryAddress ||
                targetType == MemberResolutionTargetType.additionalAddress
            ? MemberResolutionCause.addressValidation
            : MemberResolutionCause.serverValidation;
        expect(
          item(
            MemberResolutionProblemType.validation,
            targetType,
          ).effectiveCause,
          expected,
          reason: targetType.name,
        );
      }
    });

    test('bevorzugt explizit gesetzte Ursache', () {
      expect(
        item(
          MemberResolutionProblemType.validation,
          MemberResolutionTargetType.primaryAddress,
          cause: MemberResolutionCause.unknown,
        ).effectiveCause,
        MemberResolutionCause.unknown,
      );
      expect(
        item(
          MemberResolutionProblemType.conflict,
          MemberResolutionTargetType.phone,
          cause: MemberResolutionCause.remoteDeletedLocalEdited,
        ).effectiveCause,
        MemberResolutionCause.remoteDeletedLocalEdited,
      );
    });

    test('bildet itemId und storageKey aus relationshipId, fingerprint oder '
        'default', () {
      final mitId = item(
        MemberResolutionProblemType.conflict,
        MemberResolutionTargetType.phone,
        relationshipId: 11,
        fingerprint: 'ignoriert',
      );
      final mitFingerprint = item(
        MemberResolutionProblemType.validation,
        MemberResolutionTargetType.additionalAddress,
        fingerprint: 'abc',
      );
      final ohneBeides = item(
        MemberResolutionProblemType.conflict,
        MemberResolutionTargetType.firstName,
      );

      expect(mitId.target.storageKey, 'phone:11');
      expect(mitId.itemId, 'conflict:phone:11');
      expect(mitFingerprint.target.storageKey, 'additionalAddress:abc');
      expect(mitFingerprint.itemId, 'validation:additionalAddress:abc');
      expect(ohneBeides.target.storageKey, 'firstName:default');
      expect(ohneBeides.itemId, 'conflict:firstName:default');
    });
  });

  group('MemberResolutionCase.category', () {
    MemberResolutionCase resolutionCase(List<MemberResolutionItem> items) {
      return MemberResolutionCase(
        remoteMitglied: _basis(),
        items: items,
        source: MemberResolutionSource.manualSave,
      );
    }

    const konflikt = MemberResolutionItem(
      problemType: MemberResolutionProblemType.conflict,
      target: MemberResolutionTarget(
        type: MemberResolutionTargetType.firstName,
      ),
      message: 'Konflikt',
    );
    const validierung = MemberResolutionItem(
      problemType: MemberResolutionProblemType.validation,
      target: MemberResolutionTarget(
        type: MemberResolutionTargetType.primaryAddress,
      ),
      message: 'Validierung',
    );

    test('liefert nonMergeProblem fuer leere Items', () {
      final value = resolutionCase(const []);

      expect(value.category, MemberResolutionCategory.nonMergeProblem);
      expect(value.hasMergeConflicts, isFalse);
      expect(value.hasNonMergeProblems, isFalse);
      expect(value.causes, isEmpty);
    });

    test('liefert mergeConflict fuer nur Konflikte', () {
      final value = resolutionCase(const [konflikt]);

      expect(value.category, MemberResolutionCategory.mergeConflict);
      expect(value.causes, {MemberResolutionCause.overlappingChange});
    });

    test('liefert nonMergeProblem fuer nur Validierungen', () {
      final value = resolutionCase(const [validierung]);

      expect(value.category, MemberResolutionCategory.nonMergeProblem);
      expect(value.causes, {MemberResolutionCause.addressValidation});
    });

    test('liefert mixed fuer Konflikt und Validierung', () {
      final value = resolutionCase(const [konflikt, validierung]);

      expect(value.category, MemberResolutionCategory.mixed);
      expect(value.hasMergeConflicts, isTrue);
      expect(value.hasNonMergeProblems, isTrue);
    });

    test('ordnet Konflikt mit Ursache remoteDeletedLocalEdited als '
        'mergeConflict ein', () {
      final value = resolutionCase(const [
        MemberResolutionItem(
          problemType: MemberResolutionProblemType.conflict,
          target: MemberResolutionTarget(
            type: MemberResolutionTargetType.phone,
            relationshipId: 11,
          ),
          message: 'Geloescht',
          cause: MemberResolutionCause.remoteDeletedLocalEdited,
        ),
      ]);

      expect(value.category, MemberResolutionCategory.mergeConflict);
    });

    test('liefert fuer Resolver-Konflikte die Kategorie mergeConflict', () {
      final basis = _basis();
      final plan = _resolve(
        basis: basis,
        ziel: basis.copyWith(vorname: 'A'),
        remote: basis.copyWith(vorname: 'B'),
      );

      final value = resolutionCase(plan.items);

      expect(value.category, MemberResolutionCategory.mergeConflict);
    });
  });
}
