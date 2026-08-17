import Foundation

enum HTTPError: Error, Equatable, LocalizedError {
    case invalidURL
    case notFound
    case rateLimited(retryAfter: TimeInterval?)
    case status(Int)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida"
        case .notFound: return "No encontrado"
        case .rateLimited: return "Demasiadas solicitudes"
        case .status(let code): return "Error HTTP \(code)"
        case .transport(let message): return message
        case .decoding(let message): return "Respuesta inesperada: \(message)"
        }
    }
}

/// Cliente HTTP mínimo, con `URLSession` inyectable para poder testear sin red.
protocol HTTPPerforming: AnyObject {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPPerforming {}

/// `@unchecked` porque todo su estado es inmutable tras el init y
/// `URLSession` ya es segura entre hilos.
final class HTTPClient: @unchecked Sendable {
    private let session: HTTPPerforming
    private let userAgent: String
    private let decoder: JSONDecoder

    init(session: HTTPPerforming = URLSession.shared, userAgent: String = AppConfiguration.current.userAgent) {
        self.session = session
        self.userAgent = userAgent
        self.decoder = JSONDecoder()
    }

    func get<T: Decodable>(
        _ type: T.Type,
        url: URL,
        query: [String: String] = [:],
        headers: [String: String] = [:]
    ) async throws -> T {
        let data = try await getData(url: url, query: query, headers: headers)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPError.decoding(String(describing: error))
        }
    }

    func getData(url: URL, query: [String: String] = [:], headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: try Self.url(url, query: query))
        request.httpMethod = "GET"
        return try await perform(request, headers: headers)
    }

    func post<T: Decodable>(
        _ type: T.Type,
        url: URL,
        form: [String: String],
        headers: [String: String] = [:]
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(form)

        let data = try await perform(request, headers: headers)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPError.decoding(String(describing: error))
        }
    }

    // MARK: - Interno

    private func perform(_ request: URLRequest, headers: [String: String]) async throws -> Data {
        var request = request
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw HTTPError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HTTPError.transport("Respuesta sin cabecera HTTP")
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 404:
            throw HTTPError.notFound
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw HTTPError.rateLimited(retryAfter: retry)
        default:
            throw HTTPError.status(http.statusCode)
        }
    }

    private static func url(_ base: URL, query: [String: String]) throws -> URL {
        guard !query.isEmpty else { return base }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw HTTPError.invalidURL
        }
        components.queryItems = query
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw HTTPError.invalidURL }
        return url
    }

    private static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = fields
            .sorted { $0.key < $1.key }
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
        return Data(encoded.utf8)
    }
}
