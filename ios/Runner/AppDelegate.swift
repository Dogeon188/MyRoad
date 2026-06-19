import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = loadEnvKey("GOOGLE_PLACES_API_KEY") {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func loadEnvKey(_ name: String) -> String? {
    guard let path = Bundle.main.path(forResource: ".env", ofType: nil, inDirectory: "Frameworks/App.framework/flutter_assets")
          ?? Bundle.main.path(forResource: ".env", ofType: nil) else { return nil }
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
    for line in contents.split(separator: "\n") {
      let parts = line.split(separator: "=", maxSplits: 1)
      if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespaces) == name {
        return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    return nil
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
