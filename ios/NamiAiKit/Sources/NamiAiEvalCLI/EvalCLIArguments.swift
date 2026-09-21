import Foundation

/// Parsed `swift run nami-ai-eval` invocation. Deliberately hand-rolled (no swift-argument-
/// parser dependency) - the flag set here is small and this tool isn't shipped, so a manual
/// parser stays the smaller, more focused change (see root CLAUDE.md).
struct EvalCLIArguments {
  var corpusURL: URL
  var questionsURL: URL
  var conversationsURL: URL
  var skipQuestions: Bool
  var skipConversations: Bool
  var only: Set<String>?
  var filterCategories: Set<String>?
  var repeatCount: Int
  var selfCorrectionEnabled: Bool
  var timeoutSeconds: Double
  var outputURL: URL
  var verbose: Bool
  var showHelp: Bool

  static let usage = """
    Verwendung: swift run nami-ai-eval [optionen]

      --corpus <path>                  default: assets/ai_kontext/nami_ai_corpus_v1.json
      --questions <path>               default: chat_ai/eval/eval_questions.json
      --conversations <path>           default: chat_ai/eval/eval_conversations.json
      --skip-questions                 nur Konversationen ausfuehren
      --skip-conversations             nur Einzelfragen ausfuehren
      --only <id[,id...]>              nur diese question-/conversation-ids
      --filter-category <c[,c...]>     nur diese Kategorien
      --repeat <n>                     default 1
      --self-correction <true|false>   default false
      --timeout-seconds <n>            default 120
      --output <path>                  default: chat_ai/eval/results/runs/<runId>.jsonl
      --verbose                        zusaetzlich Partial-Text-Fortschritt
      --help
    """

  static func parse(_ arguments: [String], repoRoot: URL, runId: String) throws
    -> EvalCLIArguments
  {
    var corpusPath = "assets/ai_kontext/nami_ai_corpus_v1.json"
    var questionsPath = "chat_ai/eval/eval_questions.json"
    var conversationsPath = "chat_ai/eval/eval_conversations.json"
    var skipQuestions = false
    var skipConversations = false
    var only: Set<String>?
    var filterCategories: Set<String>?
    var repeatCount = 1
    var selfCorrectionEnabled = false
    var timeoutSeconds = 120.0
    var outputPath = "chat_ai/eval/results/runs/\(runId).jsonl"
    var verbose = false
    var showHelp = false

    var iterator = arguments.makeIterator()
    while let flag = iterator.next() {
      switch flag {
      case "--help", "-h":
        showHelp = true
      case "--corpus":
        corpusPath = try Self.nextValue(&iterator, for: flag)
      case "--questions":
        questionsPath = try Self.nextValue(&iterator, for: flag)
      case "--conversations":
        conversationsPath = try Self.nextValue(&iterator, for: flag)
      case "--skip-questions":
        skipQuestions = true
      case "--skip-conversations":
        skipConversations = true
      case "--only":
        only = Set(try Self.nextValue(&iterator, for: flag).split(separator: ",").map(String.init))
      case "--filter-category":
        filterCategories = Set(
          try Self.nextValue(&iterator, for: flag).split(separator: ",").map(String.init))
      case "--repeat":
        let raw = try Self.nextValue(&iterator, for: flag)
        guard let value = Int(raw), value >= 1 else {
          throw EvalCLIArgumentsError.invalidValue(flag: flag, value: raw)
        }
        repeatCount = value
      case "--self-correction":
        let raw = try Self.nextValue(&iterator, for: flag)
        guard let value = Bool(raw) else {
          throw EvalCLIArgumentsError.invalidValue(flag: flag, value: raw)
        }
        selfCorrectionEnabled = value
      case "--timeout-seconds":
        let raw = try Self.nextValue(&iterator, for: flag)
        guard let value = Double(raw), value > 0 else {
          throw EvalCLIArgumentsError.invalidValue(flag: flag, value: raw)
        }
        timeoutSeconds = value
      case "--output":
        outputPath = try Self.nextValue(&iterator, for: flag)
      case "--verbose":
        verbose = true
      default:
        throw EvalCLIArgumentsError.unknownFlag(flag)
      }
    }

    return EvalCLIArguments(
      corpusURL: Self.resolve(corpusPath, against: repoRoot),
      questionsURL: Self.resolve(questionsPath, against: repoRoot),
      conversationsURL: Self.resolve(conversationsPath, against: repoRoot),
      skipQuestions: skipQuestions, skipConversations: skipConversations, only: only,
      filterCategories: filterCategories, repeatCount: repeatCount,
      selfCorrectionEnabled: selfCorrectionEnabled, timeoutSeconds: timeoutSeconds,
      outputURL: Self.resolve(outputPath, against: repoRoot), verbose: verbose,
      showHelp: showHelp)
  }

  private static func nextValue(
    _ iterator: inout IndexingIterator<[String]>, for flag: String
  ) throws -> String {
    guard let value = iterator.next() else {
      throw EvalCLIArgumentsError.missingValue(flag)
    }
    return value
  }

  /// Relative paths resolve against the repo root (so defaults work regardless of the caller's
  /// working directory), absolute paths pass through unchanged.
  private static func resolve(_ path: String, against repoRoot: URL) -> URL {
    if path.hasPrefix("/") {
      return URL(fileURLWithPath: path)
    }
    return repoRoot.appendingPathComponent(path)
  }
}

enum EvalCLIArgumentsError: Error, CustomStringConvertible {
  case unknownFlag(String)
  case missingValue(String)
  case invalidValue(flag: String, value: String)

  var description: String {
    switch self {
    case .unknownFlag(let flag):
      return "Unbekannte Option: \(flag)"
    case .missingValue(let flag):
      return "Fehlender Wert fuer Option: \(flag)"
    case .invalidValue(let flag, let value):
      return "Ungueltiger Wert '\(value)' fuer Option: \(flag)"
    }
  }
}
