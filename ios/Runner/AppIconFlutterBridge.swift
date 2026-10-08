import Flutter
import UIKit

/// Registers the com.namiapp/app_icon MethodChannel. Icon names match the
/// alternate Icon Composer bundles next to NamiAppIcon.icon (for example
/// "NachthimmelMorgen"); nil restores the primary icon.
enum AppIconFlutterBridge {
  static let channelName = "com.namiapp/app_icon"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
  }

  private static func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "isSupported":
      result(UIApplication.shared.supportsAlternateIcons)
    case "setIcon":
      let arguments = call.arguments as? [String: Any]
      let name = arguments?["name"] as? String
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(code: "unsupported", message: nil, details: nil))
        return
      }
      guard UIApplication.shared.alternateIconName != name else {
        result(nil)
        return
      }
      UIApplication.shared.setAlternateIconName(name) { error in
        if let error {
          result(
            FlutterError(
              code: "set_icon_failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
