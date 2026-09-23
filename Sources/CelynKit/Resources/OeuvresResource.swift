import Foundation

public struct OeuvresResource: Sendable {
    let client: CultureAPIClient

    public enum Sort: String, Sendable {
        /// Most recently discussed first; populates `Oeuvre.sourceCount`
        /// and `Oeuvre.lastMentionedAt`.
        case mentioned
    }

    public func list(type: OeuvreType? = nil, limit: Int? = nil, sort: Sort? = nil) async throws -> OeuvreListResponse {
        var query: [String: String] = [:]
        if let t = type { query["type"] = t.rawValue }
        if let l = limit { query["limit"] = String(l) }
        if let s = sort { query["sort"] = s.rawValue }
        return try await client.get("oeuvres", query: query)
    }

    public func get(id: String) async throws -> Oeuvre {
        try await client.get("oeuvres/\(id)")
    }

    // Opinions are embedded in the detail response — use `get(id:)`.
}
