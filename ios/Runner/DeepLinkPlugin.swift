import Flutter
import UIKit

public class DeepLinkPlugin: NSObject, FlutterPlugin {
    private var deepLinkMethodChannel: FlutterMethodChannel?
    private var initialDeepLink: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = DeepLinkPlugin()
        instance.deepLinkMethodChannel = FlutterMethodChannel(name: "com.keisan.app/deep_links",
                                                              binaryMessenger: registrar.messenger())

        // Handle getInitialDeepLink method calls
        instance.deepLinkMethodChannel?.setMethodCallHandler { [weak instance] (call, result) in
            guard let instance = instance else { return }
            if call.method == "getInitialDeepLink" {
                result(instance.initialDeepLink)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // Store the plugin instance in the app delegate
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.deepLinkPlugin = instance
        }
    }

    public func handleDeepLink(_ linkString: String) {
        // If this is the first time, store it as initial deep link
        if initialDeepLink == nil {
            initialDeepLink = linkString
        }

        // Send the deep link to Flutter using the method channel
        deepLinkMethodChannel?.invokeMethod("handleDeepLink", arguments: linkString)
    }
}