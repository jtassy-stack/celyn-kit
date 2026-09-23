import Foundation

public struct OeuvresResource: Sendable {
    let client: CultureAPIClient

    public enum Sort: String, Sendable {
        /// Most recently discussed first; populates `Oeuvre.sourceCount`
        /// and `Oeuvre.lastMentionedAt`.
        case mentioned
        /// "Bientôt en salle": films whose French theatrical release falls
        /// within the next `withinDays` (server default 60), trailer first
        /// then soonest. Populates the `releaseDate*` fields and `nowShowing`.
        case upcoming
    }

    public func list(
        type: OeuvreType? = nil,
        limit: Int? = nil,
        sort: Sort? = nil,
        withinDays: Int? = nil
    ) async throws -> OeuvreListResponse {
        try await client.get("oeuvres", query: Self.listQuery(type: type, limit: limit, sort: sort, withinDays: withinDays))
    }

    /// Query builder for `list`, exposed for tests.
    public static func listQuery(
        type: OeuvreType? = nil,
        limit: Int? = nil,
        sort: Sort? = nil,
        withinDays: Int? = nil
    ) -> [String: String] {
        var query: [String: String] = [:]
        if let t = type { query["type"] = t.rawValue }
        if let l = limit { query["limit"] = String(l) }
        if let s = sort { query["sort"] = s.rawValue }
        if let w = withinDays { query["within_days"] = String(w) }
        return query
    }

    public func get(id: String) async throws -> Oeuvre {
        try await client.get("oeuvres/\(id)")
    }

    // Opinions are embedded in the detail response — use `get(id:)`.
}
