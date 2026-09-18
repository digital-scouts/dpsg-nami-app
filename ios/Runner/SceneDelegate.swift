import Flutter
import UIKit

@available(iOS 13.0, *)
@objc class SceneDelegate: FlutterSceneDelegate {
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

    NamiAiFlutterBridge.register(with: messenger)
  }
}
