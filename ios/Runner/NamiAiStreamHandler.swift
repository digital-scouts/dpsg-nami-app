import Flutter
import NamiAiKit

/// Streams NaMi AI answers incrementally over com.namiapp/nami_ai_stream instead of waiting for
/// the full answer (specs/nami-ai-roadmap.md section 3.7). Emits a growing-text "partial" event
/// per chunk, then exactly one "done" event carrying the grounding-gate-verified final answer -
/// the same fields generateReply's MethodChannel response carries, so both channels stay easy to
/// keep in sync on the Dart side.
final class NamiAiStreamHandler: NSObject, FlutterStreamHandler {
  static let channelName = "com.namiapp/nami_ai_stream"

  func onListen(
    withArguments arguments: Any?,
    eventSink: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard let args = arguments as? [String: Any],
      let sessionId = args["sessionId"] as? String,
      let prompt = args["prompt"] as? String
    else {
      return FlutterError(
        code: "invalid_arguments",
        message: "Missing sessionId/prompt for NaMi AI streaming.",
        details: nil
      )
    }

    NamiAiAssistant.streamRespond(
      sessionId: sessionId,
      to: prompt,
      onPartial: { text in
        DispatchQueue.main.async {
          eventSink(["type": "partial", "text": text])
        }
      },
      onComplete: { outcome in
        DispatchQueue.main.async {
          switch outcome {
          case .success(let answer):
            eventSink([
              "type": "done",
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
            eventSink(FlutterEndOfEventStream)
          case .failure(let error):
            eventSink(
              FlutterError(code: error.flutterErrorCode, message: error.userMessage, details: nil)
            )
          }
        }
      }
    )
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    // No explicit task cancellation yet: FoundationModels doesn't expose a documented way to
    // cancel an in-flight streamResponse from here, so a turn already in progress keeps running
    // to completion even if the Dart side stops listening (e.g. user navigates away). It simply
    // has no more listener to deliver events to.
    nil
  }
}
