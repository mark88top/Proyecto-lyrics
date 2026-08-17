import Foundation
import AuthenticationServices
import Combine
import UIKit

enum SpotifyAuthError: LocalizedError {
    case notConfigured
    case cancelled
    case invalidCallback
    case denied(String)
    case tokenExchange(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return L10n.errorNotConfigured
        case .cancelled: return L10n.errorLoginCancelled
        case .invalidCallback: return L10n.errorLoginInvalid
        case .denied(let reason): return reason
        case .tokenExchange(let reason): return reason
        }
    }
}

/// Login con Spotify usando Authorization Code + PKCE.
///
/// Corre en `ASWebAuthenticationSession`, que reutiliza la sesión de Safari:
/// si el usuario ya está logueado en Spotify, es un tap y listo.
@MainActor
final class SpotifyAuthManager: NSObject, ObservableObject {
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var lastError: String?

    /// Permisos mínimos. `app-remote-control` habilita el SDK nativo;
    /// los `user-read-*` habilitan el respaldo vía Web API.
    static let scopes = [
        "user-read-playback-state",
        "user-read-currently-playing",
        "app-remote-control"
    ]

    private let configuration: AppConfiguration
    private let store: SpotifyTokenStore
    private let client: HTTPClient
    private var tokens: SpotifyTokens?
    private var session: ASWebAuthenticationSession?
    private var refreshTask: Task<String, Error>?

    init(
        configuration: AppConfiguration = .current,
        store: SpotifyTokenStore = SpotifyTokenStore(),
        client: HTTPClient = HTTPClient()
    ) {
        self.configuration = configuration
        self.store = store
        self.client = client
        super.init()

        tokens = store.load()
        isAuthorized = tokens != nil
    }

    var isConfigured: Bool { configuration.isSpotifyConfigured }

    // MARK: - Login

    func signIn() async throws {
        guard configuration.isSpotifyConfigured else { throw SpotifyAuthError.notConfigured }

        let pkce = PKCE.generate()
        let state = PKCE.randomVerifier(length: 16)
        let callback = try await authorize(pkce: pkce, state: state)
        let code = try extractCode(from: callback, expectedState: state)
        let tokens = try await exchange(code: code, verifier: pkce.verifier)

        store.save(tokens)
        self.tokens = tokens
        isAuthorized = true
        lastError = nil
    }

    func signOut() {
        store.clear()
        tokens = nil
        isAuthorized = false
    }

    /// Devuelve un access token válido, refrescándolo si hace falta.
    /// Las llamadas concurrentes comparten el mismo refresh.
    func validAccessToken() async throws -> String {
        guard let current = tokens else { throw SpotifyAuthError.notConfigured }
        if !current.isExpired { return current.accessToken }

        if let running = refreshTask { return try await running.value }

        let task = Task<String, Error> { [weak self] in
            guard let self else { throw SpotifyAuthError.notConfigured }
            return try await self.performRefresh(current)
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    // MARK: - Interno

    private func authorize(pkce: PKCE.Pair, state: String) async throws -> URL {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.spotifyClientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: configuration.spotifyRedirectURI.absoluteString),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: Self.scopes.joined(separator: " "))
        ]

        guard let url = components.url else { throw SpotifyAuthError.invalidCallback }
        let scheme = configuration.spotifyRedirectURI.scheme ?? "carlyrics"

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: SpotifyAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: SpotifyAuthError.denied(error.localizedDescription))
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: SpotifyAuthError.invalidCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }
    }

    private func extractCode(from url: URL, expectedState: String) throws -> String {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            throw SpotifyAuthError.invalidCallback
        }
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw SpotifyAuthError.denied(error)
        }
        guard items.first(where: { $0.name == "state" })?.value == expectedState else {
            // Defensa contra CSRF: si el state no coincide, la respuesta no
            // es de la petición que iniciamos.
            throw SpotifyAuthError.invalidCallback
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw SpotifyAuthError.invalidCallback
        }
        return code
    }

    private func exchange(code: String, verifier: String) async throws -> SpotifyTokens {
        do {
            let response = try await client.post(
                TokenResponse.self,
                url: URL(string: "https://accounts.spotify.com/api/token")!,
                form: [
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": configuration.spotifyRedirectURI.absoluteString,
                    "client_id": configuration.spotifyClientID,
                    "code_verifier": verifier
                ]
            )
            return response.tokens(previousRefreshToken: nil)
        } catch {
            throw SpotifyAuthError.tokenExchange(error.localizedDescription)
        }
    }

    private func performRefresh(_ current: SpotifyTokens) async throws -> String {
        guard let refreshToken = current.refreshToken else {
            signOut()
            throw SpotifyAuthError.notConfigured
        }

        do {
            let response = try await client.post(
                TokenResponse.self,
                url: URL(string: "https://accounts.spotify.com/api/token")!,
                form: [
                    "grant_type": "refresh_token",
                    "refresh_token": refreshToken,
                    "client_id": configuration.spotifyClientID
                ]
            )
            // Spotify rota el refresh token a veces; si no manda uno nuevo,
            // conservamos el anterior.
            let updated = response.tokens(previousRefreshToken: refreshToken)
            store.save(updated)
            tokens = updated
            isAuthorized = true
            return updated.accessToken
        } catch {
            Log.auth.error("Refresh falló: \(error.localizedDescription, privacy: .public)")
            // Un refresh token revocado no se recupera: hay que re-loguear.
            if let httpError = error as? HTTPError,
               case .status(let code) = httpError,
               code == 400 || code == 401 {
                signOut()
            }
            throw SpotifyAuthError.tokenExchange(error.localizedDescription)
        }
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let token_type: String
        let expires_in: Double
        let refresh_token: String?
        let scope: String?

        func tokens(previousRefreshToken: String?) -> SpotifyTokens {
            SpotifyTokens(
                accessToken: access_token,
                refreshToken: refresh_token ?? previousRefreshToken,
                expiresAt: Date().addingTimeInterval(expires_in),
                scope: scope ?? ""
            )
        }
    }
}

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        return window ?? ASPresentationAnchor()
    }
}
