import Foundation
@testable import CarLyrics

/// Sesión falsa: devuelve respuestas prefabricadas por URL, sin tocar la red.
final class StubHTTPSession: HTTPPerforming {
    struct Stub {
        let statusCode: Int
        let body: Data
    }

    /// Se busca por coincidencia de subcadena en la URL absoluta.
    var stubs: [(match: String, stub: Stub)] = []
    private(set) var requestedURLs: [String] = []

    func stub(_ match: String, json: String, statusCode: Int = 200) {
        stubs.append((match, Stub(statusCode: statusCode, body: Data(json.utf8))))
    }

    func stub(_ match: String, statusCode: Int) {
        stubs.append((match, Stub(statusCode: statusCode, body: Data())))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url?.absoluteString ?? ""
        requestedURLs.append(url)

        guard let entry = stubs.first(where: { url.contains($0.match) }) else {
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: entry.stub.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (entry.stub.body, response)
    }
}
