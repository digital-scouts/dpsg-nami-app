import Flutter
import UIKit

#if canImport(AppleIntelligence)
  import AppleIntelligence
#endif

@available(iOS 13.0, *)
@objc class SceneDelegate: FlutterSceneDelegate {
  private let namiAiChannelName = "com.namiapp/nami_ai"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let messenger = (window?.rootViewController as? FlutterViewController)?.binaryMessenger
    else {
      return
    }

    let channel = FlutterMethodChannel(name: namiAiChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(handleNamiAiMethodCall)
  }

  private func handleNamiAiMethodCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
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
      generateReply(prompt: prompt, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func generateReply(
    prompt: String,
    result: @escaping FlutterResult
  ) {
    if #available(iOS 17.0, *) {
      #if canImport(AppleIntelligence)
        // TODO: Replace placeholder logic with real Apple Foundation AI calls once the SDK symbols are available.
        result("Apple-On-Device-AI ist verfügbar. Native AI-Antwort folgt später.")
      #else
        result(
          FlutterError(
            code: "ai_api_missing",
            message: "Die Apple-On-Device-AI-API ist im aktuellen Build nicht verfügbar.",
            details: nil
          ))
      #endif
    } else {
      result(
        FlutterError(
          code: "unsupported_ios",
          message: "Apple-On-Device-AI erfordert iOS 17 oder neuer.",
          details: nil
        ))
    }
  }
}
