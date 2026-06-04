import Foundation

enum APIError: Error, LocalizedError {
    case backendNotConfigured
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "Backend base URL is not configured."
        case .invalidResponse:
            return "The backend returned an invalid response."
        case .serverError(let statusCode):
            return "Backend request failed with status \(statusCode)."
        }
    }
}

struct AppConfiguration {
    static var backendBaseURL: URL? {
        if let value = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
           let url = URL(string: value),
           !value.isEmpty {
            return url
        }

        if let value = UserDefaults.standard.string(forKey: "BACKEND_BASE_URL"),
           let url = URL(string: value),
           !value.isEmpty {
            return url
        }

        return nil
    }
}

final class APIClient {
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    func request<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        token: String? = nil,
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil
    ) async throws -> Response {
        guard let baseURL = AppConfiguration.backendBaseURL else {
            throw APIError.backendNotConfigured
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try jsonEncoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        return try jsonDecoder.decode(Response.self, from: data)
    }
}

struct EmptyResponse: Codable {}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

