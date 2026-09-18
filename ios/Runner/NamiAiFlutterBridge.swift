import Flutter
import NamiAiKit

/// Only file in the Runner target that touches both Flutter and NamiAiKit. Registers the
/// existing com.namiapp/nami_ai MethodChannel and translates calls into NamiAiKit's plain
/// Swift API. All actual AI logic lives in the NamiAiKit package.
enum NamiAiFlutterBridge {
  static let channelName = "com.namiapp/nami_ai"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
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
    case "generateReply":
      guard let args = call.arguments as? [String: Any],
        let prompt = args["prompt"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing prompt for NaMi AI.",
            details: nil
          ))
        return
      }
      NamiAiAssistant.respond(to: prompt) { outcome in
        DispatchQueue.main.async {
          switch outcome {
          case .success(let answer):
            result(["answer": answer.text, "contextChunks": answer.contextChunks])
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
