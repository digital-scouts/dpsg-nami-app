/// Art eines gemeldeten Problems (Mehrfachauswahl im Sheet „Problem melden“).
enum ProblemArt {
  anmeldung('hilfe_art_anmeldung'),
  datenSync('hilfe_art_daten_sync'),
  mitgliedBearbeiten('hilfe_art_mitglied_bearbeiten'),
  statistik('hilfe_art_statistik'),
  karten('hilfe_art_karten'),
  darstellung('hilfe_art_darstellung'),
  absturz('hilfe_art_absturz'),
  sonstiges('hilfe_art_sonstiges');

  const ProblemArt(this.textKey);

  final String textKey;
}

/// Angaben aus „Problem melden“; alles freiwillig.
class ProblemMeldung {
  const ProblemMeldung({
    this.arten = const <ProblemArt>{},
    this.gemacht = '',
    this.passiert = '',
    this.erwartet = '',
  });

  final Set<ProblemArt> arten;
  final String gemacht;
  final String passiert;
  final String erwartet;

  /// Betreff, z. B. „NaMi: Problem – Daten & Sync“.
  String betreff(String Function(String key) t) {
    final namen = _artNamen(t);
    return namen.isEmpty
        ? t('hilfe_mail_betreff')
        : '${t('hilfe_mail_betreff')} – ${namen.join(', ')}';
  }

  /// Mailtext mit den Antworten und technischen Eckdaten. Unbeantwortete
  /// Fragen stehen als „–“.
  String text(String Function(String key) t, {required String geraet}) {
    String antwort(String wert) => wert.trim().isEmpty ? '–' : wert.trim();
    final namen = _artNamen(t);
    return [
      '${t('hilfe_problem_art')}: ${namen.isEmpty ? '–' : namen.join(', ')}',
      '',
      t('hilfe_frage_gemacht'),
      antwort(gemacht),
      '',
      t('hilfe_frage_passiert'),
      antwort(passiert),
      '',
      t('hilfe_frage_erwartet'),
      antwort(erwartet),
      '',
      geraet,
    ].join('\n');
  }

  List<String> _artNamen(String Function(String key) t) => [
    for (final art in ProblemArt.values)
      if (arten.contains(art)) t(art.textKey),
  ];
}
