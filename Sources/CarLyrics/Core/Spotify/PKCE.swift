import Foundation
import CryptoKit
import Security

/// Generación del par verifier/challenge para OAuth PKCE (RFC 7636).
///
/// Usamos PKCE en vez del flujo con client secret porque una app de iPhone
/// no puede guardar un secreto: cualquiera puede extraerlo del binario.
enum PKCE {
    struct Pair {
        let verifier: String
        let challenge: String
    }

    static func generate() -> Pair {
        let verifier = randomVerifier()
        return Pair(verifier: verifier, challenge: challenge(for: verifier))
    }

    static func randomVerifier(length: Int = 64) -> String {
        let allowed = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { allowed[Int($0) % allowed.count] })
    }

    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

extension Data {
    /// Base64 URL-safe sin padding, como pide el RFC.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
