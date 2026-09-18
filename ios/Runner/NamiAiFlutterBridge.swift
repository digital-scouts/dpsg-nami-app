import Flutter
import NamiAiKit

/// Only file in the Runner target that touches both Flutter and NamiAiKit. Registers the
/// existing com.namiapp/nami_ai MethodChannel and translates calls into NamiAiKit's plain
/// Swift API. All actual AI logic lives in the NamiAiKit package.
enum NamiAiFlutterBridge {
  static let channelName = "com.namiapp/nami_ai"

  static func register(with messenger: FlutterBinaryMessenger) {
    configureCorpus()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
    let streamChannel = FlutterEventChannel(
      name: NamiAiStreamHandler.channelName, binaryMessenger: messenger)
    streamChannel.setStreamHandler(NamiAiStreamHandler())
  }

  /// Resolves the shared corpus asset (single source of truth, specs/nami-ai-roadmap.md
  /// section 3.2) and hands the path to NamiAiKit, which has no Flutter dependency of its own.
  /// If resolution fails, NamiAiKit simply reports contextMissing on the next request instead
  /// of crashing here.
  private static func configureCorpus() {
    let assetKey = FlutterDartProject.lookupKey(
      forAsset: "assets/ai_kontext/nami_ai_corpus_v1.json")
    guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
      return
    }
    NamiAiAssistant.configure(corpusFileURL: URL(fileURLWithPath: path))
  }

  private static func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "checkAvailability":
      if let error = NamiAiAssistant.checkAvailability() {
        result(["available": false, "reason": error.flutterErrorCode])
      } else {
        result(["available": true])
      }
    case "startChatSession":
      NamiAiAssistant.startSession { outcome in
        DispatchQueue.main.async {
          switch outcome {
          case .success(let sessionId):
            result(["sessionId": sessionId])
          case .failure(let error):
            result(
              FlutterError(code: error.flutterErrorCode, message: error.userMessage, details: nil)
            )
          }
        }
      }
    case "endChatSession":
      guard let args = call.arguments as? [String: Any],
        let sessionId = args["sessionId"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing sessionId for NaMi AI.",
            details: nil
          ))
        return
      }
      NamiAiAssistant.endSession(sessionId: sessionId)
      result(nil)
    case "generateReply":
      guard let args = call.arguments as? [String: Any],
        let prompt = args["prompt"] as? String,
        let sessionId = args["sessionId"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing prompt/sessionId for NaMi AI.",
            details: nil
          ))
        return
      }
      NamiAiAssistant.respond(sessionId: sessionId, to: prompt) { outcome in
        DispatchQueue.main.async {
          switch outcome {
          case .success(let answer):
            result([
              "answer": answer.text,
              "contextChunks": answer.contextChunks,
              "sources": answer.sources.map {
                [
                  "docTitle": $0.docTitle,
                  "sectionNumber": $0.sectionNumber,
                  "docStand": $0.docStand,
                ]
              },
              "unclear": answer.unclear,
              "contextTruncated": answer.contextTruncated,
            ])
          case .failure(let error):
            result(
              FlutterError(
                code: error.flutterErrorCode,
                message: error.userMessage,
                details: nil
              ))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
