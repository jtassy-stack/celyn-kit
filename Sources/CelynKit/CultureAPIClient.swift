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
        timeout: TimeInterval = 15
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

        // One-shot retry on transient network failures (timeouts, dropped TLS,
        // network lost). celyn.io occasionally drops connections under load.
        let (data, response) = try await Self.dataWithRetry(session: session, request: request, logger: logger)
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

    /// Performs a POST with a JSON body and decodes the response. Mirrors
    /// `get` for headers, retries, and decoding strategy. No retry on the
    /// transport error itself — POSTs aren't idempotent at the request
    /// layer and a duplicate insert is worse than surfacing the failure.
    public func post<Req: Encodable, Res: Decodable>(
        _ path: String,
        body: Req
    ) async throws -> Res {
        guard !apiKey.isEmpty else {
            throw CultureAPIError.missingAPIKey
        }

        let sanitized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = baseURL.appendingPathComponent(sanitized)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let payload = try encoder.encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.assumesHTTP3Capable = false

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CultureAPIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("POST \(url.path) → \(http.statusCode): \(body)")
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
            return try decoder.decode(Res.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("POST \(url.path) decode error: \(error) — body: \(body)")
            throw error
        }
    }

    /// One retry after a short backoff for transient network errors.
    /// Covers timeouts (-1001), connection lost (-1005), and DNS (-1003) —
    /// the kinds of failures we see on celyn.io under parallel load.
    private static func dataWithRetry(
        session: URLSession,
        request: URLRequest,
        logger: Logger
    ) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where Self.isTransient(error) {
            logger.notice("retry transient \(error.code.rawValue) \(request.url?.path ?? "")")
            try await Task.sleep(for: .milliseconds(400))
            return try await session.data(for: request)
        }
    }

    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}
