import Foundation

/// Deterministic, model-free pre-filter for explicit write intents (specs/nami-ai-roadmap.md
/// section 3.7: "deterministischer Vorfilter ... für explizite Schreibverben → sofortige feste
/// Antwort"). Runs before LanguageModelSession is ever invoked, so it stays testable without
/// FoundationModels/a device and never spends a model call on a request that is going to be
/// rejected anyway. Deliberately small and pragmatic like the glossary added in 3.3 — plain
/// substring matching, no lemmatization/NLP. Known gap: German separable-prefix verbs (trennbare
/// Verben) split apart in natural word order ("trage mich für die Fahrt ein"), so only their
/// infinitive/participle forms ("eintragen", "eingetragen") are listed, not the split imperative
/// ("trage ... ein") — catching that would need real tokenization, out of scope for this filter.
enum NamiAiWriteIntentFilter {
  private static let writeVerbPhrases: [String] = [
    "erstelle", "erstellen", "anlegen",
    "hinzufügen", "hinzugefügt",
    "ändere", "ändern", "geändert",
    "aktualisiere", "aktualisieren", "aktualisiert",
    "bearbeite", "bearbeiten", "bearbeitet",
    "lösche", "löschen", "gelöscht",
    "entferne", "entfernen", "entfernt",
    "eintragen", "eingetragen",
    "speichere", "speichern", "gespeichert",
    "anmelden", "angemeldet",
    "abmelden", "abgemeldet",
    "verschiebe", "verschieben", "verschoben",
    "importiere", "importieren", "importiert",
    "exportiere", "exportieren", "exportiert",
  ]

  static func matches(_ prompt: String) -> Bool {
    let normalized = prompt.lowercased()
    return writeVerbPhrases.contains { normalized.contains($0) }
  }
}
