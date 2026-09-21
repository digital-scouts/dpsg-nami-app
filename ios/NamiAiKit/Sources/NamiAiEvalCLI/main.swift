import Foundation
import NamiAiEvalKit
import NamiAiKit

/// Local, UI-free eval harness for the NaMi AI chat (specs/nami-ai-roadmap.md section 3.8/3.11:
/// end-to-end answer quality can't run in CI/simulator, since FoundationModels needs a real,
/// Apple-Intelligence-enabled device/Mac). Exercises the exact same production entry points the
/// Flutter chat UI uses (startSession -> streamRespond per turn -> endSession, never the
/// one-shot respond(to:)), against chat_ai/eval/eval_questions.json and
/// chat_ai/eval/eval_conversations.json, and writes one structured JSONL log line per turn -
/// replacing the manual "type answers into a new Markdown file" step of the previous runbook
/// for everything that's now objectively checkable (citations, guardrail behavior, consistency
/// across repeats). See chat_ai/eval/README.md for when to still fall back to the manual runbook.
let repoRoot = EvalCLIRuntime.repoRootURL()
let runId = EvalCLIRuntime.newRunId()

do {
  let cliArguments = try EvalCLIArguments.parse(
    Array(CommandLine.arguments.dropFirst()), repoRoot: repoRoot, runId: runId)

  if cliArguments.showHelp {
    print(EvalCLIArguments.usage)
    exit(0)
  }

  NamiAiAssistant.configure(corpusFileURL: cliArguments.corpusURL)

  // Fail fast on unavailable Apple Intelligence instead of failing the same way on every single
  // fixture - checkAvailability() already runs this exact check internally on every call, but
  // there's no point paying for dozens of doomed calls to find that out.
  if let availabilityError = NamiAiAssistant.checkAvailability() {
    FileHandle.standardError.write(
      Data("Apple Intelligence nicht verfuegbar: \(availabilityError.userMessage)\n".utf8))
    exit(1)
  }

  let titleIndex: EvalCorpusTitleIndex
  do {
    titleIndex = try EvalCorpusTitleIndex(corpusFileURL: cliArguments.corpusURL)
  } catch {
    FileHandle.standardError.write(
      Data("Korpus-Titel-Index konnte nicht gebaut werden: \(error)\n".utf8))
    exit(1)
  }

  var questions: [EvalQuestionFixture] = []
  if !cliArguments.skipQuestions {
    do {
      questions = try EvalQuestionsLoader.load(from: cliArguments.questionsURL).questions
    } catch {
      FileHandle.standardError.write(Data("Fragen konnten nicht geladen werden: \(error)\n".utf8))
      exit(1)
    }
  }

  var conversations: [EvalConversationFixture] = []
  if !cliArguments.skipConversations {
    do {
      conversations = try EvalConversationsLoader.load(from: cliArguments.conversationsURL)
        .conversations
    } catch EvalConversationsLoaderError.fileNotFound {
      print(
        "Hinweis: keine Konversationsdatei unter \(cliArguments.conversationsURL.path) gefunden - wird uebersprungen."
      )
    } catch {
      FileHandle.standardError.write(
        Data("Konversationen konnten nicht geladen werden: \(error)\n".utf8))
      exit(1)
    }
  }

  if let only = cliArguments.only {
    questions = questions.filter { only.contains($0.id) }
    conversations = conversations.filter { only.contains($0.id) }
  }
  if let categories = cliArguments.filterCategories {
    questions = questions.filter { categories.contains($0.category) }
    conversations = conversations.filter { categories.contains($0.category) }
  }

  let config = EvalRunConfig(
    runId: runId, repeatCount: cliArguments.repeatCount,
    defaultSelfCorrectionEnabled: cliArguments.selfCorrectionEnabled)
  let driver = LiveEvalSessionDriver(
    timeoutSeconds: cliArguments.timeoutSeconds, verbose: cliArguments.verbose)

  print(
    "NaMi-AI-Eval-Run \(runId): \(questions.count) Frage(n), \(conversations.count) Konversation(en), --repeat \(cliArguments.repeatCount)"
  )

  var totalEntries = 0
  var failedFixtureIds: [String] = []

  // Sequential on purpose: a LanguageModelSession is a real, stateful resource, and running
  // fixtures concurrently would both compete for it and misrepresent how the app is actually
  // used (one session, one conversation at a time).
  for question in questions {
    let entries = await EvalTurnOrchestrator.runQuestion(
      question, driver: driver, titleIndex: titleIndex, config: config)
    for entry in entries {
      try EvalLogWriter.append(entry, to: cliArguments.outputURL)
      totalEntries += 1
      if !(entry.sourceMatch && entry.guardrailMatch) {
        failedFixtureIds.append("\(question.id)#\(entry.repeatIndex)")
      }
    }
    print("- [question] \(question.id): \(entries.map { $0.outcome }.joined(separator: ", "))")
  }

  for conversation in conversations {
    let entries = await EvalTurnOrchestrator.runConversation(
      conversation, driver: driver, titleIndex: titleIndex, config: config)
    for entry in entries {
      try EvalLogWriter.append(entry, to: cliArguments.outputURL)
      totalEntries += 1
      if !(entry.sourceMatch && entry.guardrailMatch) {
        failedFixtureIds.append("\(conversation.id)#\(entry.repeatIndex)/turn\(entry.turnIndex)")
      }
    }
    print(
      "- [conversation] \(conversation.id): \(entries.map { $0.outcome }.joined(separator: ", "))"
    )
  }

  print("\nFertig: \(totalEntries) Log-Zeile(n) geschrieben nach \(cliArguments.outputURL.path)")
  if !failedFixtureIds.isEmpty {
    print(
      "Auffaellig (sourceMatch/guardrailMatch nicht erfuellt): \(failedFixtureIds.joined(separator: ", "))"
    )
  }
  print(
    "Report erzeugen: python3 chat_ai/eval/report_eval_run.py summarize \(cliArguments.outputURL.path)"
  )
} catch {
  FileHandle.standardError.write(Data("\(error)\n\n\(EvalCLIArguments.usage)\n".utf8))
  exit(2)
}
