import UIKit
import SwiftUI

/// Escena del iPhone/iPad: hospeda la UI SwiftUI.
@MainActor
final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let environment = AppEnvironment.shared
        let root = RootView()
            .environmentObject(environment)
            .environmentObject(environment.settings)
            .environmentObject(environment.auth)
            .environmentObject(environment.playback)
            .environmentObject(environment.lyrics)
            .environmentObject(environment.tipJar)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        self.window = window

        applyIdleTimerPolicy()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppEnvironment.shared.startIfNeeded()
        applyIdleTimerPolicy()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Nunca dejamos el idle timer deshabilitado en background: sería una
        // forma silenciosa de comerse la batería del usuario.
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// Con la letra en pantalla el usuario no toca nada durante minutos, así
    /// que iOS apagaría la pantalla. Sólo lo evitamos si el usuario lo pidió.
    private func applyIdleTimerPolicy() {
        UIApplication.shared.isIdleTimerDisabled = AppEnvironment.shared.settings.keepScreenAwake
    }
}
