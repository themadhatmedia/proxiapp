import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins first, then let FlutterAppDelegate / Firebase Messaging set up
    // UNUserNotificationCenter forwarding. Assigning UNUserNotificationCenter.delegate here
    // (before plugins) can interfere with firebase_messaging's swizzling integration.
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Ensures custom schemes (e.g. proxiapp://billing/success) reach Flutter / app_links.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return super.application(app, open: url, options: options)
  }
}
