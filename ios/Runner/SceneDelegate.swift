import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // Reference to the custom deep link plugin (registered on the app delegate)
  private var deepLinkPlugin: DeepLinkPlugin? {
    (UIApplication.shared.delegate as? AppDelegate)?.deepLinkPlugin
  }

  // Handle deep links delivered while the app is launching (cold start).
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    // Process URL scheme based deep links delivered at launch
    for context in connectionOptions.urlContexts {
      deepLinkPlugin?.handleDeepLink(context.url.absoluteString)
    }

    // Process Universal Links delivered at launch
    if let userActivity = connectionOptions.userActivities.first,
       userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let incomingURL = userActivity.webpageURL {
      deepLinkPlugin?.handleDeepLink(incomingURL.absoluteString)
    }
  }

  // Handle Universal Links while the app is running
  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let incomingURL = userActivity.webpageURL {
      deepLinkPlugin?.handleDeepLink(incomingURL.absoluteString)
      return
    }

    // Let Flutter plugins handle other activities - Firebase Auth will work here
    super.scene(scene, continue: userActivity)
  }

  // Support URL scheme-based redirects for Firebase Auth
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      deepLinkPlugin?.handleDeepLink(context.url.absoluteString)
    }

    // Let Flutter plugins handle the URL - important for Firebase Auth
    super.scene(scene, openURLContexts: URLContexts)
  }
}
