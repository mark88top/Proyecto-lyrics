import CarPlay
import UIKit

/// Punto de entrada de CarPlay.
///
/// iOS crea esta escena cuando el teléfono se conecta al auto, incluso si la
/// app nunca se abrió en el iPhone durante esta sesión. Por eso todo el
/// estado vive en `AppEnvironment.shared` y acá sólo montamos la UI.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var coordinator: CarPlayCoordinator?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        Log.carplay.info("CarPlay conectado")

        let coordinator = CarPlayCoordinator(
            interfaceController: interfaceController,
            environment: AppEnvironment.shared
        )
        self.coordinator = coordinator
        coordinator.start()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        Log.carplay.info("CarPlay desconectado")
        coordinator?.stop()
        coordinator = nil
    }
}
