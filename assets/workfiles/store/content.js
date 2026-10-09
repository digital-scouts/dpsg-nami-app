// Inhalte der Store-Einträge. Einzige Quelle für Texte und Slides;
// als JS statt JSON, damit die Vorschau auch per file:// funktioniert.
// Sprachabhängiges steht je Sprache unter `de` und `en`.
window.STORE = {
  // Version, für die der Store-Eintrag zuletzt überarbeitet wurde. Weicht
  // pubspec.yaml ab, startet der Skill store-seite eine Feedbackrunde.
  version: '1.0.0',
  languages: ['de', 'en'],

  // Reihenfolge = Reihenfolge im Store. `scene` = Dateiname in
  // raw/<sprache>/<gerät>/. `accent` greift im Stil "stufen".
  slides: [
    {
      scene: 'mitglieder',
      accent: '#5A9AD8',
      de: {
        headline: 'Dein Stamm in der Hosentasche',
        subline: 'Alle Mitglieder durchsuchen, filtern und sortieren – auch offline.',
      },
      en: {
        headline: 'Your scout group in your pocket',
        subline: 'Search, filter and sort all members – even offline.',
      },
    },
    {
      scene: 'statistik',
      accent: '#FF6400',
      de: {
        headline: 'Euer Stamm in Zahlen',
        subline: 'Neu: umfangreiche Statistiken zu Gruppen, Alter, Geschlecht und Leitenden.',
      },
      en: {
        headline: 'Your group in numbers',
        subline: 'New: detailed statistics on groups, age, gender and leaders.',
      },
    },
    {
      scene: 'bundesvergleich',
      accent: '#00823c',
      de: {
        headline: 'Vergleich mit Stämmen bundesweit',
        subline: 'Freiwillig und nur mit zusammengefassten Zahlen.',
      },
      en: {
        headline: 'Compare with groups nationwide',
        subline: 'Optional and only with aggregated figures.',
      },
    },
    {
      scene: 'erfolge',
      accent: '#E0B43A',
      de: {
        headline: 'Erfolge sammeln',
        subline: 'Abzeichen von Bronze bis Diamant für eure Arbeit mit der App.',
      },
      en: {
        headline: 'Collect achievements',
        subline: 'Badges from bronze to diamond for your work with the app.',
      },
    },
    {
      scene: 'stufenwechsel',
      accent: '#5A9AD8',
      de: {
        headline: 'Stufenwechsel ohne Rätselraten',
        subline: 'Sieh auf einen Blick, wer bis zum Stichtag in die nächste Stufe wechselt.',
      },
      en: {
        headline: 'Section changes made easy',
        subline: 'See at a glance who moves up to the next section by the cut-off date.',
      },
    },
    {
      scene: 'erscheinungsbild',
      sceneDark: 'erscheinungsbild_dunkel',
      split: [46, 20],
      accent: '#cc1f2f',
      de: {
        headline: 'Kostenlos im Kern',
        subline: 'Mitglieder, Statistik und Karten sind frei. Supporter-Pakete bringen Extras und zusätzliche Designs.',
      },
      en: {
        headline: 'Free at its core',
        subline: 'Members, statistics and maps are free. Supporter packs add extras and additional designs.',
      },
    },
    {
      scene: 'mitgliedsdetail',
      accent: '#FF6400',
      de: {
        headline: 'Alles Wichtige auf einen Blick',
        subline: 'Kontakt, Mitgliedschaft, Rollen und Qualifikationen – direkt anrufen oder mailen.',
      },
      en: {
        headline: 'Everything important at a glance',
        subline: 'Contact details, membership, roles and qualifications – call or email directly.',
      },
    },
    {
      scene: 'karte',
      accent: '#00823c',
      de: {
        headline: 'Alle Stämme auf der Karte',
        subline: 'Diözesangrenzen und DPSG-Stämme in ganz Deutschland.',
      },
      en: {
        headline: 'All groups on the map',
        subline: 'Diocese boundaries and DPSG groups across Germany.',
      },
    },
  ],

  featureGraphic: {
    title: 'NaMi',
    claim: {
      de: 'Dein Stamm in der Hosentasche – für Leitende in der DPSG',
      en: 'Your scout group in your pocket – for DPSG leaders',
    },
    scenes: ['mitglieder', 'statistik', 'erfolge'],
  },

  // App-Store-Produktseite: Kopfzeile (Marke, eine Idee) und
  // Suchergebnis (zeigt die App). Keine Preise, URLs oder fremde Plattformen.
  appStore: {
    header: {
      title: 'NaMi',
      claim: {
        de: 'Dein Stamm in der Hosentasche – für Leitende in der DPSG',
        en: 'Your scout group in your pocket – for DPSG leaders',
      },
      scenes: ['statistik', 'mitglieder', 'stufenwechsel', 'erfolge'],
    },
    search: {
      de: {
        headline: 'Dein Stamm in der Hosentasche',
        subline: 'Mitglieder, Statistik und Stufenwechsel – auch offline.',
      },
      en: {
        headline: 'Your scout group in your pocket',
        subline: 'Members, statistics and section changes – even offline.',
      },
      scenes: ['mitglieder', 'statistik', 'stufenwechsel'],
    },
  },

  // Limits laut Play Console / App Store Connect. `file` = Dateiname im
  // Fastlane-Metadatenordner (export_fastlane.mjs). Die erste Variante je
  // Sprache ist die aktive und wird hochgeladen. Titel und Name braucht jede
  // neue Store-Sprache; sie bleiben überall „NaMi“.
  texts: {
    play: [
      { key: 'Titel', file: 'title', limit: 30, de: ['NaMi'], en: ['NaMi'] },
      {
        key: 'Kurzbeschreibung',
        file: 'short_description',
        limit: 80,
        de: ['Dein Stamm in der Hosentasche: Mitglieder, Stufenwechsel und Statistik'],
        en: ['Your scout group in your pocket: members, section changes and statistics'],
      },
      { key: 'Vollständige Beschreibung', file: 'full_description', limit: 4000, ref: 'description' },
      { key: 'Versionshinweise', file: 'changelogs/default', limit: 500, ref: 'whatsNew' },
    ],
    appStore: [
      { key: 'Name', file: 'name', limit: 30, de: ['NaMi'], en: ['NaMi'] },
      {
        key: 'Untertitel',
        file: 'subtitle',
        limit: 30,
        de: ['Für Leitende in der DPSG', 'Dein Stamm in der Hosentasche'],
        en: ['For DPSG leaders', 'Your DPSG group in your pocket'],
      },
      {
        key: 'Werbetext',
        file: 'promotional_text',
        limit: 170,
        de: [
          'Komplett neu für die NaMi 3.0: Mitglieder durchsuchen, Stufenwechsel planen und euren Stamm bundesweit vergleichen – übersichtlich und auch offline.',
          'Komplett neu für die NaMi 3.0: umfangreiche Statistiken, bundesweiter Vergleich, Erfolge und eigene Designs – und alle Mitglieder immer dabei, auch offline.',
        ],
        en: [
          'Completely rebuilt for NaMi 3.0: search members, plan section changes and compare your group nationwide – clear and available offline.',
          'Completely rebuilt for NaMi 3.0: detailed statistics, nationwide comparison, achievements and custom designs – with all members at hand, even offline.',
        ],
      },
      { key: 'Beschreibung', file: 'description', limit: 4000, ref: 'description' },
      { key: 'Neues in dieser Version', file: 'release_notes', limit: 4000, ref: 'whatsNew' },
      {
        key: 'Keywords',
        file: 'keywords',
        limit: 100,
        de: [
          'DPSG,Pfadfinder,NaMi,Stamm,Leiter,Mitglieder,Stufenwechsel,Wölflinge,Jungpfadfinder,Rover,Hitobito',
        ],
        en: [
          'scouts,scouting,Pfadfinder,NaMi,Stamm,scout group,members,section change,cubs,rovers,Hitobito',
        ],
      },
    ],
  },

  description: {
    de: `NaMi ist die App für Leitende in der DPSG. Sie bringt die Mitgliederdaten eures Stammes aus der NaMi aufs Smartphone – übersichtlich, schnell und auch ohne Netz.

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

KOSTENLOS IM KERN
Mitgliederverwaltung, Statistiken, Karten und Erinnerungen sind kostenlos. Wer die Entwicklung unterstützen möchte, kann Supporter-Pakete kaufen. Sie schalten Extras frei: die Qualifikationen-Übersicht mit Erinnerungen, zusätzliche Farbpaletten und Hintergründe, App-Icons und Supporter-Badges.

VORAUSSETZUNG
Du brauchst einen Zugang zur NaMi der DPSG. Die App zeigt nur die Daten, die du auch in der NaMi sehen darfst.

HINWEIS
Diese App wird privat und ehrenamtlich entwickelt. Sie steht in keinem Zusammenhang mit der DPSG und ist von ihr weder autorisiert noch unterstützt.

Feedback und Ideen sind jederzeit willkommen – direkt in der App oder auf GitHub.`,

    en: `NaMi is the app for leaders in the DPSG. It brings your Stamm's (scout group's) member data from NaMi to your smartphone – clear, fast and even without a connection.

Version 1.0 is a complete rebuild: the app now works with the new NaMi 3.0 and has been redesigned from the ground up.

NEW IN VERSION 1.0
• Detailed statistics: members, leaders and groups at a glance, age and gender distribution, a detail view for each group
• Nationwide comparison: see how your group compares with other groups. Only aggregated figures are shared, never names or individual data – and only if you agree.
• Achievements: collect badges from bronze to diamond. Your achievements stay on your device.
• Design options: light and dark mode, colour palettes, backgrounds for the member list and custom app icons
• Available in German and English

MEMBERS ALWAYS AT HAND
• Search, filter and sort all members of your group
• Pick sections such as Meute, Trupp or Runde with a tap
• Contact details, roles, membership and qualifications at a glance
• Call or email directly
• Edit member data – conflicts with changes in NaMi are resolved in a clear way
• Data stays available offline, for example at camp without reception

SECTION CHANGES AND MAP
• See who can move up to the next section by the cut-off date
• Adjust age limits and cut-off date to your group
• Diocese boundaries and DPSG groups across Germany on the map

MORE FEATURES
• Birthday reminders, optionally only for selected sections
• Switch the work context for district, diocese and national level
• App lock with Face ID or fingerprint

FREE AT ITS CORE
Member management, statistics, maps and reminders are free. If you would like to support development, you can buy supporter packs. They unlock extras: the qualifications overview with reminders, additional colour palettes and backgrounds, app icons and supporter badges.

REQUIREMENTS
You need an account for the DPSG's NaMi. The app only shows the data you are allowed to see in NaMi.

NOTE
This app is developed privately by volunteers. It is not affiliated with the DPSG and is neither authorised nor endorsed by it.

Feedback and ideas are always welcome – directly in the app or on GitHub.`,
  },

  whatsNew: {
    de: `Version 1.0 – komplett neu gebaut:
• Die App arbeitet jetzt mit der neuen NaMi 3.0
• Neues Design und schnellere Bedienung
• Umfangreiche Statistiken für euren Stamm
• Optionaler bundesweiter Vergleich mit anderen Stämmen
• Erfolge mit Abzeichen von Bronze bis Diamant
• Designvarianten: Farbpaletten, Hintergründe und App-Icons
• Auf Deutsch und Englisch

Wichtig: Nach dem Update ist eine neue Anmeldung nötig. Die Daten werden anschließend neu aus der NaMi geladen.`,

    en: `Version 1.0 – completely rebuilt:
• The app now works with the new NaMi 3.0
• New design and faster to use
• Detailed statistics for your group
• Optional nationwide comparison with other groups
• Achievements with badges from bronze to diamond
• Design options: colour palettes, backgrounds and app icons
• Available in German and English

Important: after the update you need to sign in again. Your data is then reloaded from NaMi.`,
  },
};
