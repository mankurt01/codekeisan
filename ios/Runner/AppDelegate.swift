import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Reference to the custom deep link plugin
  var deepLinkPlugin: DeepLinkPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Register the custom deep link plugin using the implicit engine bridge
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeepLinkPlugin") {
      DeepLinkPlugin.register(with: registrar)
    }
  }
}
