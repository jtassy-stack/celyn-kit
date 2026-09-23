import Foundation

public struct OeuvresResource: Sendable {
    let client: CultureAPIClient

    public enum Sort: String, Sendable {
        /// Most recently discussed first; populates `Oeuvre.sourceCount`
        /// and `Oeuvre.lastMentionedAt` (+ `awards` / `latestAwardAt` on
        /// books with a literary prize selection).
        case mentioned
        /// "Bientôt en salle": films whose French theatrical release falls
        /// within the next `withinDays` (server default 60), trailer first
        /// then soonest. Populates the `releaseDate*` fields and `nowShowing`.
        case upcoming
    }

    /// - Parameter award: only oeuvres with a literary prize selection/win
    ///   for this prize slug (e.g. "goncourt"); `awarded: true` = any prize.
    /// - Parameter providers: FR streaming platform ids or slugs (any of),
    ///   matching offers included with the service (never rent/buy).
    /// - Parameter anime: `true` only anime, `false` exclude anime.
    /// - Parameter platforms: game platform slugs (any of) — games only.
    ///   With `type: .game, sort: .upcoming` = upcoming game releases.
    public func list(
        type: OeuvreType? = nil,
        limit: Int? = nil,
        sort: Sort? = nil,
        withinDays: Int? = nil,
        award: String? = nil,
        awarded: Bool? = nil,
        providers: [String] = [],
        anime: Bool? = nil,
        platforms: [String] = []
    ) async throws -> OeuvreListResponse {
        try await client.get("oeuvres", query: Self.listQuery(type: type, limit: limit, sort: sort, withinDays: withinDays, award: award, awarded: awarded, providers: providers, anime: anime, platforms: platforms))
    }

    /// French streaming platforms with at least one included offer, most
    /// oeuvres first (the "mes plateformes" picker).
    public func providers(minCount: Int? = nil) async throws -> StreamingPlatformListResponse {
        var query: [String: String] = [:]
        if let m = minCount { query["min_count"] = String(m) }
        return try await client.get("oeuvres/providers", query: query)
    }

    /// Game platforms (ps5, switch-2, pc, …) with game / upcoming counts
    /// (the "mes consoles" picker).
    public func gamePlatforms() async throws -> GamePlatformListResponse {
        try await client.get("oeuvres/game-platforms", query: [:])
    }

    /// Query builder for `list`, exposed for tests.
    public static func listQuery(
        type: OeuvreType? = nil,
        limit: Int? = nil,
        sort: Sort? = nil,
        withinDays: Int? = nil,
        award: String? = nil,
        awarded: Bool? = nil,
        providers: [String] = [],
        anime: Bool? = nil,
        platforms: [String] = []
    ) -> [String: String] {
        var query: [String: String] = [:]
        if let t = type { query["type"] = t.rawValue }
        if let l = limit { query["limit"] = String(l) }
        if let s = sort { query["sort"] = s.rawValue }
        if let w = withinDays { query["within_days"] = String(w) }
        if let a = award { query["award"] = a }
        if awarded == true { query["awarded"] = "true" }
        let p = providers.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !p.isEmpty { query["provider"] = p.joined(separator: ",") }
        if let a = anime { query["anime"] = a ? "true" : "false" }
        let gp = platforms.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !gp.isEmpty { query["platform"] = gp.joined(separator: ",") }
        return query
    }

    public func get(id: String) async throws -> Oeuvre {
        try await client.get("oeuvres/\(id)")
    }

    // Opinions are embedded in the detail response — use `get(id:)`.
}
