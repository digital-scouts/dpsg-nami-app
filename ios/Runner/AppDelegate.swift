import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    excludeAppDataFromBackup()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Hive-Boxen und Kartencache (Documents) sowie App-, Traffic- und
  /// NaMi-AI-Logs (Application Support) gehoeren nicht in iCloud- oder
  /// lokale Backups (A-42). Der Ausschluss eines Ordners gilt auch fuer
  /// spaeter darin angelegte Dateien.
  private func excludeAppDataFromBackup() {
    let fileManager = FileManager.default
    let directories: [FileManager.SearchPathDirectory] = [
      .documentDirectory, .applicationSupportDirectory,
    ]
    for directory in directories {
      guard var url = fileManager.urls(for: directory, in: .userDomainMask).first else {
        continue
      }
      do {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
      } catch {
        NSLog("Backup-Ausschluss fehlgeschlagen fuer %@: %@", url.path, "\(error)")
      }
    }
  }
}
