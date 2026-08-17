import XCTest
@testable import CarLyrics

final class PKCETests: XCTestCase {
    func testChallengeMatchesKnownVector() {
        // Vector del RFC 7636, apéndice B.
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expected = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

        XCTAssertEqual(PKCE.challenge(for: verifier), expected)
    }

    func testGeneratedVerifierIsURLSafeAndLongEnough() {
        let pair = PKCE.generate()

        // El RFC exige entre 43 y 128 caracteres del set no reservado.
        XCTAssertGreaterThanOrEqual(pair.verifier.count, 43)
        XCTAssertLessThanOrEqual(pair.verifier.count, 128)

        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        XCTAssertTrue(pair.verifier.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    func testChallengeHasNoBase64Padding() {
        let challenge = PKCE.generate().challenge
        XCTAssertFalse(challenge.contains("="))
        XCTAssertFalse(challenge.contains("+"))
        XCTAssertFalse(challenge.contains("/"))
    }

    func testVerifiersAreUnique() {
        let values = Set((0..<50).map { _ in PKCE.generate().verifier })
        XCTAssertEqual(values.count, 50)
    }
}
