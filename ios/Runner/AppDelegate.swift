import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Register the native blocking plugin (method channel: com.nashaat/blocking)
    BlockingPlugin.register(with: registrar(forPlugin: "BlockingPlugin")!)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
