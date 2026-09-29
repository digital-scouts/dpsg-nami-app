// Inhalte der Store-Einträge. Einzige Quelle für Texte und Slides;
// als JS statt JSON, damit die Vorschau auch per file:// funktioniert.
window.STORE = {
  version: '1.0.0',

  // Reihenfolge = Reihenfolge im Store. `scene` = Dateiname in raw/<gerät>/.
  // `accent` greift im Stil "stufen".
  slides: [
    {
      scene: 'mitglieder',
      headline: 'Dein Stamm in der Hosentasche',
      subline: 'Alle Mitglieder durchsuchen, filtern und sortieren – auch offline.',
      accent: '#5A9AD8',
    },
    {
      scene: 'statistik',
      headline: 'Euer Stamm in Zahlen',
      subline: 'Neu: umfangreiche Statistiken zu Gruppen, Alter, Geschlecht und Leitenden.',
      accent: '#FF6400',
    },
    {
      scene: 'bundesvergleich',
      headline: 'Vergleich mit Stämmen bundesweit',
      subline: 'Freiwillig und nur mit zusammengefassten Zahlen – keine Namen, keine Einzeldaten.',
      accent: '#00823c',
    },
    {
      scene: 'erfolge',
      headline: 'Erfolge sammeln',
      subline: 'Abzeichen von Bronze bis Diamant für eure Arbeit mit der App.',
      accent: '#E0B43A',
    },
    {
      scene: 'stufenwechsel',
      headline: 'Stufenwechsel ohne Rätselraten',
      subline: 'Sieh auf einen Blick, wer bis zum Stichtag in die nächste Stufe wechselt.',
      accent: '#5A9AD8',
    },
    {
      scene: 'erscheinungsbild',
      sceneDark: 'erscheinungsbild_dunkel',
      split: [46, 20],
      headline: 'Komplett kostenlos',
      subline: 'Alle Funktionen sind frei – hell wie dunkel. Supporter-Pakete bringen nur zusätzliche Designs.',
      accent: '#cc1f2f',
    },
    {
      scene: 'mitgliedsdetail',
      headline: 'Alles Wichtige auf einen Blick',
      subline: 'Kontakt, Mitgliedschaft, Rollen und Qualifikationen – direkt anrufen oder mailen.',
      accent: '#FF6400',
    },
    {
      scene: 'karte',
      headline: 'Alle Stämme auf der Karte',
      subline: 'Diözesangrenzen und DPSG-Stämme in ganz Deutschland.',
      accent: '#00823c',
    },
  ],

  featureGraphic: {
    title: 'NaMi',
    claim: 'Dein Stamm in der Hosentasche – für Leitende in der DPSG',
    scenes: ['mitglieder', 'statistik', 'erfolge'],
  },

  // Limits laut Play Console / App Store Connect.
  texts: {
    play: [
      {
        key: 'Kurzbeschreibung',
        limit: 80,
        variants: ['Dein Stamm in der Hosentasche: Mitglieder, Stufenwechsel und Statistik'],
      },
      { key: 'Vollständige Beschreibung', limit: 4000, ref: 'description' },
      { key: 'Versionshinweise', limit: 500, ref: 'whatsNew' },
    ],
    appStore: [
      {
        key: 'Untertitel',
        limit: 30,
        variants: ['Für Leitende in der DPSG', 'Dein Stamm in der Hosentasche'],
      },
      {
        key: 'Werbetext',
        limit: 170,
        variants: [
          'Komplett neu für die NaMi 3.0: Mitglieder durchsuchen, Stufenwechsel planen und euren Stamm bundesweit vergleichen – übersichtlich und auch offline.',
          'Komplett neu für die NaMi 3.0: umfangreiche Statistiken, bundesweiter Vergleich, Erfolge und eigene Designs – und alle Mitglieder immer dabei, auch offline.',
        ],
      },
      { key: 'Beschreibung', limit: 4000, ref: 'description' },
      { key: 'Neues in dieser Version', limit: 4000, ref: 'whatsNew' },
      {
        key: 'Keywords',
        limit: 100,
        variants: [
          'DPSG,Pfadfinder,NaMi,Stamm,Leiter,Mitglieder,Stufenwechsel,Wölflinge,Jungpfadfinder,Rover,Hitobito',
        ],
      },
    ],
  },

  description: `NaMi ist die App für Leitende in der DPSG. Sie bringt die Mitgliederdaten eures Stammes aus der NaMi aufs Smartphone – übersichtlich, schnell und auch ohne Netz.

Version 1.0 ist ein kompletter Neubau: Die App arbeitet jetzt mit der neuen NaMi 3.0 zusammen und wurde von Grund auf neu gestaltet.

NEU IN VERSION 1.0
• Umfangreiche Statistiken: Mitglieder, Leitende und Gruppen im Überblick, Alters- und Geschlechterverteilung, Detailansicht je Gruppe
• Bundesweiter Vergleich: Seht, wie euer Stamm im Vergleich zu anderen Stämmen aufgestellt ist. Geteilt werden nur zusammengefasste Zahlen, keine Namen oder Einzeldaten – und nur, wenn ihr zustimmt.
• Erfolge: Sammelt Abzeichen von Bronze bis Diamant. Eure Erfolge bleiben auf dem Gerät.
• Designvarianten: helles und dunkles Design, Farbpaletten, Hintergründe für die Mitgliederliste und eigene App-Icons
• Auf Deutsch und Englisch

MITGLIEDER IMMER DABEI
• Alle Mitglieder eures Stammes durchsuchen, filtern und sortieren
• Gruppen wie Meute, Trupp oder Runde per Fingertipp auswählen
• Kontaktdaten, Rollen, Mitgliedschaft und Qualifikationen auf einen Blick
• Direkt anrufen oder eine E-Mail schreiben
• Mitgliedsdaten bearbeiten – Konflikte mit Änderungen in der NaMi werden verständlich aufgelöst
• Daten bleiben offline verfügbar, zum Beispiel im Zeltlager ohne Empfang

STUFENWECHSEL UND KARTE
• Sieh, wer bis zum Stichtag in die nächste Stufe wechseln kann
• Altersgrenzen und Stichtag passt ihr an euren Stamm an
• Diözesangrenzen und Stämme der DPSG in ganz Deutschland auf der Karte

WEITERE FUNKTIONEN
• Erinnerungen an Geburtstage, auf Wunsch nur für ausgewählte Stufen
• Wechsel des Arbeitskontexts für Bezirks-, Diözesan- und Bundesebene
• App-Sperre per Face ID oder Fingerabdruck

KOSTENLOS
Alle Funktionen der App sind kostenlos und bleiben es. Wer die Entwicklung unterstützen möchte, kann Supporter-Pakete kaufen. Sie bringen ausschließlich zusätzliche Designs wie Farbpaletten, Hintergründe, App-Icons und ein Supporter-Badge.

VORAUSSETZUNG
Du brauchst einen Zugang zur NaMi der DPSG. Die App zeigt nur die Daten, die du auch in der NaMi sehen darfst.

HINWEIS
Diese App wird privat und ehrenamtlich entwickelt. Sie steht in keinem Zusammenhang mit der DPSG und ist von ihr weder autorisiert noch unterstützt.

Feedback und Ideen sind jederzeit willkommen – direkt in der App oder auf GitHub.`,

  whatsNew: `Version 1.0 – komplett neu gebaut:
• Die App arbeitet jetzt mit der neuen NaMi 3.0
• Neues Design und schnellere Bedienung
• Umfangreiche Statistiken für euren Stamm
• Optionaler bundesweiter Vergleich mit anderen Stämmen
• Erfolge mit Abzeichen von Bronze bis Diamant
• Designvarianten: Farbpaletten, Hintergründe und App-Icons
• Auf Deutsch und Englisch

Wichtig: Nach dem Update ist eine neue Anmeldung nötig. Die Daten werden anschließend neu aus der NaMi geladen.`,
};
