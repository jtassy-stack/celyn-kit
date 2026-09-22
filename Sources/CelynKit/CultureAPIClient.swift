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
private struct CKEmptyBody: Encodable {}

public final class CultureAPIClient: Sendable {

    public let baseURL: URL
    public let apiKey: String

    /// Marketing version of the running app, sent as `x-app-version` on every
    /// request.
    ///
    /// The server had no way to tell one client build from another, so any
    /// change to a response shape had to stay backward-compatible forever, or
    /// break every phone still running an older version. `/me/contacts/match`
    /// is the case that forced this: it returns each match's full phone number
    /// purely because installed clients use it as a display fallback, and that
    /// is exactly what makes the endpoint worth enumerating. With a version on
    /// the request the server can stop sending the field to clients that no
    /// longer need it, instead of waiting for the last old install to die.
    ///
    /// Empty string rather than a fake version when the bundle has no
    /// `CFBundleShortVersionString` (unit tests, SPM consumers): the server
    /// must read "unknown, assume oldest", never a version that doesn't exist.
    static let appVersion: String =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""

    /// Sent as `Accept-Language` on every request so the server returns
    /// localized titles/descriptions/critic opinions for non-French users
    /// instead of always defaulting to French. BCP-47 (e.g. "en-US"), read
    /// from the device's preferred languages.
    static let acceptLanguage: String =
        Locale.preferredLanguages.first ?? Locale.current.identifier
    public let timeout: TimeInterval

    /// Supplies the current end-user session token (phone-auth). Read per
    /// request so login/logout take effect without rebuilding the client; nil
    /// or empty → no `Authorization` header (anonymous, x-api-key only).
    private let bearerProvider: (@Sendable () -> String?)?

    // Dedicated session avoids the nw_connection stale-pool issue that hits
    // URLSession.shared when multiple parallel requests fire on cellular.
    private let session: URLSession
    private let logger = Logger(subsystem: "io.celyn.kit", category: "CultureAPIClient")

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://celyn.io/api")!,
        timeout: TimeInterval = 15,
        bearerProvider: (@Sendable () -> String?)? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.timeout = timeout
        self.bearerProvider = bearerProvider

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
        request.setValue(Self.appVersion, forHTTPHeaderField: "x-app-version")
        request.setValue(Self.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        if let token = bearerProvider?(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
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

        do {
            return try Self.jsonDecoder().decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("GET \(url.path) decode error: \(error) — body: \(body)")
            throw error
        }
    }

    /// JSON decoder configured for the API's wire format (custom date parsing +
    /// snake_case → camelCase). Shared by `get` and `getPublic`.
    private static func jsonDecoder() -> JSONDecoder {
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
        return decoder
    }

    /// Host-root (no `/api`) base for the public, un-authenticated feeds mounted
    /// outside `/api/*` — currently the embeddings + curator sync. Derived from
    /// `baseURL` so a custom base (tests, staging) carries through.
    private var publicBaseURL: URL { baseURL.deletingLastPathComponent() }

    /// GET a public endpoint (mounted at the host root, e.g.
    /// `/public/embeddings/...`). No `x-api-key` is required — these feeds are
    /// identical for every caller and edge-cached. Same decoding + retry as `get`.
    public func getPublic<T: Decodable>(
        _ path: String,
        query: [String: String] = [:]
    ) async throws -> T {
        let sanitized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(
            url: publicBaseURL.appendingPathComponent(sanitized),
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
        request.timeoutInterval = timeout
        request.assumesHTTP3Capable = false

        let (data, response) = try await Self.dataWithRetry(session: session, request: request, logger: logger)
        guard let http = response as? HTTPURLResponse else {
            throw CultureAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("GET \(url.path) → \(http.statusCode): \(body)")
            throw CultureAPIError.httpError(statusCode: http.statusCode, body: body)
        }
        do {
            return try Self.jsonDecoder().decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("GET \(url.path) decode error: \(error) — body: \(body)")
            throw error
        }
    }

    /// Performs a POST with a JSON body and decodes the response.
    public func post<Req: Encodable, Res: Decodable>(
        _ path: String,
        body: Req
    ) async throws -> Res {
        try await sendBody("POST", path, body: body)
    }

    /// Performs a PUT with a JSON body and decodes the response. Used for
    /// idempotent upserts (e.g. /me/sync).
    public func put<Req: Encodable, Res: Decodable>(
        _ path: String,
        body: Req
    ) async throws -> Res {
        try await sendBody("PUT", path, body: body)
    }

    /// Performs a DELETE and decodes the response. Sends an empty JSON body
    /// (harmless; the server ignores it) so it can share the body-request path.
    public func delete<Res: Decodable>(_ path: String) async throws -> Res {
        try await sendBody("DELETE", path, body: CKEmptyBody())
    }

    /// Shared body-request impl. Mirrors `get` for headers and decoding. No
    /// retry on the transport error itself — a duplicate write is worse than
    /// surfacing the failure.
    private func sendBody<Req: Encodable, Res: Decodable>(
        _ method: String,
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
        request.httpMethod = method
        request.httpBody = payload
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.appVersion, forHTTPHeaderField: "x-app-version")
        request.setValue(Self.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        if let token = bearerProvider?(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.assumesHTTP3Capable = false

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CultureAPIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("\(method) \(url.path) → \(http.statusCode): \(body)")
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
            logger.error("\(method) \(url.path) decode error: \(error) — body: \(body)")
            throw error
        }
    }

    /// One retry after a short backoff for transient network errors.
    /// Covers connection lost (-1005) and DNS (-1003) — the kinds of failures
    /// we see on celyn.io under parallel load.
    ///
    /// Deliberately NOT timeouts. A timeout means the server took longer than
    /// `timeout` seconds, and celyn.io's slow endpoints are slow in the tens of
    /// seconds (p95 25s on /events, 33.7s on /podcasts/episodes), so a retry
    /// nearly always burns a second full timeout and then fails anyway — the
    /// user waits ~30s instead of ~15s for the same nothing, and the retry
    /// piles more load onto the box that was already the reason for the
    /// timeout. Raising the timeout instead would be worse: a 33.7s p95 would
    /// still fail, just after holding the UI even longer.
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
        // `.notConnectedToInternet` is excluded alongside `.timedOut`: it is a
        // device-state answer, not a flaky one, and 400ms later the device is
        // still offline.
        case .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
