import '../arbeitskontext/arbeitskontext_read_model.dart';
import '../arbeitskontext/teildaten_stand.dart';
import '../member/mitglied.dart';
import 'berechne_efz_gueltigkeit_usecase.dart';
import 'hitobito_qualifikationsart.dart';
import 'personenkreis.dart';
import 'qualifikation.dart';
import 'qualifikations_einstellungen.dart';
import 'qualifikations_status.dart';
import 'qualifikationsart.dart';

/// Eine Art in der Uebersicht: das EFZ oder eine Hitobito-Art.
class UebersichtArt {
  const UebersichtArt({
    required this.schluessel,
    required this.label,
    this.gueltigkeitJahre,
    this.hitobitoId,
    this.reaktivierbar = false,
  });

  factory UebersichtArt.efz() => UebersichtArt(
    schluessel: QualifikationsSchluessel.efz,
    label: efzQualifikationsart.label,
    gueltigkeitJahre: efzQualifikationsart.gueltigkeitsjahre,
  );

  factory UebersichtArt.hitobito(HitobitoQualifikationsart art) =>
      UebersichtArt(
        schluessel: QualifikationsSchluessel.hitobito(art.id),
        label: art.label,
        gueltigkeitJahre: art.gueltigkeitJahre,
        hitobitoId: art.id,
        reaktivierbar: art.reaktivierbar,
      );

  final String schluessel;
  final String label;

  /// `null` bei Arten ohne Ablauf.
  final int? gueltigkeitJahre;
  final int? hitobitoId;
  final bool reaktivierbar;

  bool get istEfz => schluessel == QualifikationsSchluessel.efz;

  @override
  bool operator ==(Object other) =>
      other is UebersichtArt &&
      other.schluessel == schluessel &&
      other.label == label &&
      other.gueltigkeitJahre == gueltigkeitJahre;

  @override
  int get hashCode => Object.hash(schluessel, label, gueltigkeitJahre);
}

/// Eine Art mit ihren aufgeloesten Einstellungen (Vorgaben eingesetzt).
class KatalogEintrag {
  const KatalogEintrag({
    required this.art,
    required this.angezeigt,
    required this.personenkreis,
    required this.erinnerung,
  });

  final UebersichtArt art;
  final bool angezeigt;
  final Personenkreis personenkreis;
  final QualifikationsErinnerung erinnerung;
}

/// Eine Person mit ihrem Stand fuer eine Art.
class UebersichtEintrag {
  const UebersichtEintrag({
    required this.mitglied,
    required this.status,
    this.gueltigBis,
    this.ohneAblauf = false,
    this.reaktivierbar = false,
  });

  final Mitglied mitglied;
  final QualifikationsStatus status;
  final DateTime? gueltigBis;
  final bool ohneAblauf;
  final bool reaktivierbar;

  /// Fehlt und abgelaufen zaehlen gemeinsam als „fehlt“.
  bool get fehlt =>
      status == QualifikationsStatus.fehlt ||
      status == QualifikationsStatus.abgelaufen;
}

/// Eine Zeile der Uebersicht: Art, Personenkreis und Zaehlung.
class UebersichtZeile {
  UebersichtZeile({
    required this.katalog,
    required this.eintraege,
    this.gesperrt = false,
  });

  final KatalogEintrag katalog;

  /// Nach Dringlichkeit sortiert.
  final List<UebersichtEintrag> eintraege;

  /// Ohne EFZ-Berechtigung laesst sich die EFZ-Zeile nicht auswerten.
  final bool gesperrt;

  UebersichtArt get art => katalog.art;
  int get benoetigt => eintraege.length;
  int get fehlt => eintraege.where((e) => e.fehlt).length;
  int get bald => eintraege
      .where((e) => e.status == QualifikationsStatus.baldAblaufend)
      .length;
  int get gueltig =>
      eintraege.where((e) => e.status == QualifikationsStatus.gueltig).length;

  /// Erfuellt zaehlt gueltig und demnaechst faellig.
  int get erfuellt => gueltig + bald;
  int get handlungsbedarf => fehlt + bald;
}

/// Baut Katalog und Uebersicht der Qualifikationen aus dem Arbeitskontext
/// und den app-weiten Einstellungen.
class ErmittleQualifikationsUebersichtUseCase {
  const ErmittleQualifikationsUebersichtUseCase({
    this.berechneEfzGueltigkeitUseCase = const BerechneEfzGueltigkeitUseCase(),
  });

  final BerechneEfzGueltigkeitUseCase berechneEfzGueltigkeitUseCase;

  /// Alle Arten im Kontext: das EFZ immer, Hitobito-Arten nur, wenn sie
  /// jemand hat. Angezeigte stehen in der gewuenschten Reihenfolge vorn,
  /// ausgeblendete folgen alphabetisch.
  List<KatalogEintrag> katalog({
    required ArbeitskontextReadModel readModel,
    required QualifikationsEinstellungen einstellungen,
  }) {
    final arten = <UebersichtArt>[
      UebersichtArt.efz(),
      for (final art in readModel.qualifikationsarten)
        UebersichtArt.hitobito(art),
    ];
    final eintraege = arten.map((art) {
      final gespeichert = einstellungen.art(art.schluessel);
      return KatalogEintrag(
        art: art,
        angezeigt:
            gespeichert.angezeigt ??
            QualifikationsVorgaben.istVorgabe(art.schluessel, art.label),
        personenkreis:
            gespeichert.personenkreis ??
            QualifikationsVorgaben.personenkreis(art.schluessel, art.label),
        erinnerung:
            gespeichert.erinnerung ??
            QualifikationsVorgaben.erinnerung(art.schluessel, art.label),
      );
    }).toList();

    int positionVon(KatalogEintrag eintrag) {
      final index = einstellungen.reihenfolge.indexOf(eintrag.art.schluessel);
      return index < 0 ? einstellungen.reihenfolge.length : index;
    }

    int alphabetisch(KatalogEintrag a, KatalogEintrag b) =>
        a.art.label.toLowerCase().compareTo(b.art.label.toLowerCase());

    eintraege.sort((a, b) {
      if (a.angezeigt != b.angezeigt) {
        return a.angezeigt ? -1 : 1;
      }
      if (!a.angezeigt) {
        return alphabetisch(a, b);
      }
      final position = positionVon(a).compareTo(positionVon(b));
      if (position != 0) {
        return position;
      }
      final rang = QualifikationsVorgaben.rang(
        a.art.schluessel,
        a.art.label,
      ).compareTo(QualifikationsVorgaben.rang(b.art.schluessel, b.art.label));
      return rang != 0 ? rang : alphabetisch(a, b);
    });
    return eintraege;
  }

  /// Zeilen fuer alle angezeigten Arten.
  /// [istVollLesbar] blendet Personen aus, fuer die Hitobito keine
  /// Qualifikationen und kein EFZ liefert; sie wuerden sonst als „fehlt“
  /// gezaehlt.
  List<UebersichtZeile> call({
    required ArbeitskontextReadModel readModel,
    required QualifikationsEinstellungen einstellungen,
    required DateTime heute,
    bool Function(Mitglied mitglied)? istVollLesbar,
  }) {
    return katalog(readModel: readModel, einstellungen: einstellungen)
        .where((eintrag) => eintrag.angezeigt)
        .map(
          (eintrag) => zeile(
            readModel: readModel,
            katalog: eintrag,
            heute: heute,
            istVollLesbar: istVollLesbar,
          ),
        )
        .toList(growable: false);
  }

  UebersichtZeile zeile({
    required ArbeitskontextReadModel readModel,
    required KatalogEintrag katalog,
    required DateTime heute,
    bool Function(Mitglied mitglied)? istVollLesbar,
  }) {
    final gesperrt =
        katalog.art.istEfz &&
        readModel.efzStand == TeildatenStand.keineBerechtigung;
    final eintraege = gesperrt
        ? <UebersichtEintrag>[]
        : readModel.mitglieder
              .where(
                (mitglied) =>
                    mitglied.personId != null &&
                    (istVollLesbar?.call(mitglied) ?? true) &&
                    katalog.personenkreis.enthaelt(mitglied, heute: heute),
              )
              .map(
                (mitglied) => eintragFuer(
                  readModel: readModel,
                  art: katalog.art,
                  mitglied: mitglied,
                  warnschwelleTage: katalog.erinnerung.warnschwelleTage,
                  heute: heute,
                ),
              )
              .toList();
    eintraege.sort(_nachDringlichkeit);
    return UebersichtZeile(
      katalog: katalog,
      eintraege: List<UebersichtEintrag>.unmodifiable(eintraege),
      gesperrt: gesperrt,
    );
  }

  /// Stand einer Person fuer eine Art, unabhaengig vom Personenkreis.
  UebersichtEintrag eintragFuer({
    required ArbeitskontextReadModel readModel,
    required UebersichtArt art,
    required Mitglied mitglied,
    required int warnschwelleTage,
    required DateTime heute,
  }) {
    final warnschwelle = Duration(days: warnschwelleTage);
    if (art.istEfz) {
      final gueltigkeit = berechneEfzGueltigkeitUseCase(
        readModel.findeEfzEinsichtnahmen(mitglied.personId),
      );
      return UebersichtEintrag(
        mitglied: mitglied,
        gueltigBis: gueltigkeit.gueltigBis,
        status: berechneStatus(
          gueltigBis: gueltigkeit.gueltigBis,
          heute: heute,
          warnschwelle: warnschwelle,
        ),
      );
    }

    final massgeblich = _massgeblich(
      readModel
          .findeQualifikationen(mitglied.personId)
          .where((q) => q.artId == art.hitobitoId)
          .toList(growable: false),
    );
    if (massgeblich == null) {
      return UebersichtEintrag(
        mitglied: mitglied,
        status: QualifikationsStatus.fehlt,
      );
    }
    if (massgeblich.finishAt == null) {
      return UebersichtEintrag(
        mitglied: mitglied,
        status: QualifikationsStatus.gueltig,
        ohneAblauf: true,
      );
    }
    return UebersichtEintrag(
      mitglied: mitglied,
      gueltigBis: massgeblich.finishAt,
      reaktivierbar: massgeblich.reaktivierbar,
      status: berechneStatus(
        gueltigBis: massgeblich.finishAt,
        heute: heute,
        warnschwelle: warnschwelle,
      ),
    );
  }

  /// Ohne Ablauf geht vor, sonst zaehlt das spaeteste Ende.
  Qualifikation? _massgeblich(List<Qualifikation> qualifikationen) {
    if (qualifikationen.isEmpty) {
      return null;
    }
    for (final qualifikation in qualifikationen) {
      if (qualifikation.finishAt == null) {
        return qualifikation;
      }
    }
    return qualifikationen.reduce(
      (a, b) => a.finishAt!.isAfter(b.finishAt!) ? a : b,
    );
  }
}

/// Fehlt (nie hinterlegt) vor abgelaufen vor bald vor gueltig, innerhalb
/// davon das fruehere Datum zuerst; ohne Datum ans Ende.
int _nachDringlichkeit(UebersichtEintrag a, UebersichtEintrag b) {
  int rang(QualifikationsStatus status) => switch (status) {
    QualifikationsStatus.fehlt => 0,
    QualifikationsStatus.abgelaufen => 1,
    QualifikationsStatus.baldAblaufend => 2,
    QualifikationsStatus.gueltig => 3,
  };
  final status = rang(a.status).compareTo(rang(b.status));
  if (status != 0) {
    return status;
  }
  final aDatum = a.gueltigBis;
  final bDatum = b.gueltigBis;
  if (aDatum == null || bDatum == null) {
    return aDatum == null ? (bDatum == null ? 0 : 1) : -1;
  }
  return aDatum.compareTo(bDatum);
}
