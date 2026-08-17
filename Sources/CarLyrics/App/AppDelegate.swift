import UIKit

/// Ciclo de vida UIKit en vez de `SwiftUI.App`.
///
/// CarPlay necesita una `CPTemplateApplicationScene` declarada en el
/// Info.plist con su propio delegate. Con el ciclo de vida de SwiftUI eso
/// obliga a puentes frágiles; con `UIApplicationDelegate` la selección de
/// escena es explícita y estable. La UI del teléfono sigue siendo SwiftUI,
/// montada dentro de un `UIHostingController`.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Tocar el environment acá garantiza que los servicios existan antes
        // de que cualquier escena (incluida la de CarPlay) se conecte.
        _ = AppEnvironment.shared
        AppEnvironment.shared.startIfNeeded()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            return UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
        }
        return UISceneConfiguration(name: "Phone", sessionRole: connectingSceneSession.role)
    }
}
