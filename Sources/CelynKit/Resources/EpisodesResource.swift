import Foundation

/// TV episodes of series / anime (culture-api migration 0135) — not podcast
/// episodes (see `podcasts`).
public struct EpisodesResource: Sendable {
    let client: CultureAPIClient

    /// Episodes airing in `[from, to]` (server default: today → today + 7,
    /// Europe/Paris; window capped at 60 days), ordered by air date.
    /// - Parameter providers: FR streaming platform ids or slugs (any of),
    ///   same semantics as `oeuvres.list(providers:)`.
    /// - Parameter anime: `true` only anime, `false` exclude anime.
    public func upcoming(
        from: Date? = nil,
        to: Date? = nil,
        providers: [String] = [],
        anime: Bool? = nil,
        limit: Int? = nil
    ) async throws -> EpisodeListResponse {
        try await client.get("episodes/upcoming", query: Self.upcomingQuery(from: from, to: to, providers: providers, anime: anime, limit: limit))
    }

    /// Query builder for `upcoming`, exposed for tests. Dates are sent as
    /// Europe/Paris calendar days (`YYYY-MM-DD`).
    public static func upcomingQuery(
        from: Date? = nil,
        to: Date? = nil,
        providers: [String] = [],
        anime: Bool? = nil,
        limit: Int? = nil
    ) -> [String: String] {
        var query: [String: String] = [:]
        if let f = from { query["from"] = parisDay(f) }
        if let t = to { query["to"] = parisDay(t) }
        let p = providers.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !p.isEmpty { query["provider"] = p.joined(separator: ",") }
        if let a = anime { query["anime"] = a ? "true" : "false" }
        if let l = limit { query["limit"] = String(l) }
        return query
    }

    static func parisDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
