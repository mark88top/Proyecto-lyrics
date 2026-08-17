import Foundation

/// Tokens de Spotify. `expiresAt` se calcula al recibirlos para no depender
/// del reloj del servidor.
struct SpotifyTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var scope: String

    /// Consideramos el token vencido 60 s antes: una petición que sale justo
    /// en el límite igual falla, y en el auto reintentar cuesta caro.
    var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
}

/// Persistencia de tokens en Keychain.
struct SpotifyTokenStore {
    private let keychain: Keychain
    private let account = "spotify.tokens"

    init(keychain: Keychain = Keychain()) {
        self.keychain = keychain
    }

    func load() -> SpotifyTokens? { keychain.decode(SpotifyTokens.self, for: account) }
    func save(_ tokens: SpotifyTokens) { keychain.encode(tokens, for: account) }
    func clear() { keychain.remove(account) }
}
