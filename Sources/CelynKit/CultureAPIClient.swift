import Foundation
import os

/// HTTP client for the celyn culture-api at https://celyn.io.
///
/// Generic over the response type — callers decode into their own model types.
/// `Sendable` because all stored properties are immutable value types.
///
/// JSON decoding runs off the main thread on the cooperative pool (the `get`
/// method is `nonisolated async`). Dates accept ISO8601, fractional ISO8601,
/// or PostgreSQL timestamp formats via `CultureAPIDateParsing.parse`.
public final class CultureAPIClient: Sendable {

    public let baseURL: URL
    public let apiKey: String
    public let timeout: TimeInterval

    // Dedicated session avoids the nw_connection stale-pool issue that hits
    // URLSession.shared when multiple parallel requests fire on cellular.
    private let session: URLSession
    private let logger = Logger(subsystem: "io.celyn.kit", category: "CultureAPIClient")

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://celyn.io/api")!,
        timeout: TimeInterval = 10
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.timeout = timeout

        let config = URLSessionConfiguration.default
        // Don't wait indefinitely for connectivity — fail fast and let the
        // caller surface an error rather than blocking for the full timeout.
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        // Cap at 2 to avoid saturating the server with parallel TLS handshakes,
        // which causes nw_endpoint_flow failures on cellular/weak wifi.
        config.httpMaximumConnectionsPerHost = 2
        self.session = URLSession(configuration: config)
    }

    /// True when an API key has been provided. Calling `get` without a key
    /// throws `CultureAPIError.missingAPIKey`.
    public var isConfigured: Bool { !apiKey.isEmpty }

    /// Performs a GET request and decodes the response.
    public func get<T: Decodable>(
        _ path: String,
        query: [String: String] = [:]
    ) async throws -> T {
        guard !apiKey.isEmpty else {
            throw CultureAPIError.missingAPIKey
        }

        let sanitized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(sanitized),
            resolvingAgainstBaseURL: false
        ) else {
            throw CultureAPIError.invalidResponse
        }

        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw CultureAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = timeout
        // celyn.io doesn't support QUIC — skip the Connection refused + TLS
        // fallback round-trip that adds ~200ms on every cold start.
        request.assumesHTTP3Capable = false

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CultureAPIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("GET \(url.path) → \(http.statusCode): \(body)")
            throw CultureAPIError.httpError(statusCode: http.statusCode, body: body)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = CultureAPIDateParsing.parse(str) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date string '\(str)'"
            )
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("GET \(url.path) decode error: \(error) — body: \(body)")
            throw error
        }
    }
}
