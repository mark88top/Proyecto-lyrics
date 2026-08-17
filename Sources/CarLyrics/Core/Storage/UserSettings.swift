import Foundation
import Combine

/// Preferencias del usuario. Se comparte entre la escena del iPhone y la de
/// CarPlay, así que es un singleton observable respaldado por `UserDefaults`.
@MainActor
final class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private enum Key {
        static let lyricsOffset = "settings.lyricsOffsetMilliseconds"
        static let fontScale = "settings.fontScale"
        static let hasSeenOnboarding = "settings.hasSeenOnboarding"
        static let carPlayLinesVisible = "settings.carPlayLinesVisible"
        static let showRomanization = "settings.showRomanization"
        static let keepScreenAwake = "settings.keepScreenAwake"
        static let hasEverTipped = "settings.hasEverTipped"
        static let tipPromptCount = "settings.tipPromptCount"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.lyricsOffset: 0,
            Key.fontScale: 1.0,
            Key.hasSeenOnboarding: false,
            Key.carPlayLinesVisible: 3,
            Key.showRomanization: false,
            Key.keepScreenAwake: true,
            Key.hasEverTipped: false,
            Key.tipPromptCount: 0
        ])
    }

    /// Ajuste fino de sincronía, en milisegundos. Positivo = la letra va
    /// adelantada y hay que atrasarla.
    var lyricsOffsetMilliseconds: Int {
        get { defaults.integer(forKey: Key.lyricsOffset) }
        set {
            objectWillChange.send()
            defaults.set(min(3000, max(-3000, newValue)), forKey: Key.lyricsOffset)
        }
    }

    var lyricsOffset: TimeInterval { TimeInterval(lyricsOffsetMilliseconds) / 1000 }

    var fontScale: Double {
        get { defaults.double(forKey: Key.fontScale) }
        set {
            objectWillChange.send()
            defaults.set(min(1.8, max(0.8, newValue)), forKey: Key.fontScale)
        }
    }

    var hasSeenOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasSeenOnboarding) }
        set { objectWillChange.send(); defaults.set(newValue, forKey: Key.hasSeenOnboarding) }
    }

    /// Cuántas líneas de contexto mostrar en CarPlay (1, 3 o 5).
    /// Menos líneas = menos texto que leer al volante.
    var carPlayLinesVisible: Int {
        get { defaults.integer(forKey: Key.carPlayLinesVisible) }
        set { objectWillChange.send(); defaults.set(min(5, max(1, newValue)), forKey: Key.carPlayLinesVisible) }
    }

    var keepScreenAwake: Bool {
        get { defaults.bool(forKey: Key.keepScreenAwake) }
        set { objectWillChange.send(); defaults.set(newValue, forKey: Key.keepScreenAwake) }
    }

    var hasEverTipped: Bool {
        get { defaults.bool(forKey: Key.hasEverTipped) }
        set { objectWillChange.send(); defaults.set(newValue, forKey: Key.hasEverTipped) }
    }

    var tipPromptCount: Int {
        get { defaults.integer(forKey: Key.tipPromptCount) }
        set { objectWillChange.send(); defaults.set(newValue, forKey: Key.tipPromptCount) }
    }
}
