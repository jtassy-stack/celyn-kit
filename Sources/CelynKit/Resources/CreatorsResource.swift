import Foundation

public struct CreatorsResource: Sendable {
    let client: CultureAPIClient

    /// `GET /creators/instagram?featured=true&vertical=...&limit=...`
    /// Returns the editorial Instagram-curator list, filterable by vertical.
    /// `featured` defaults server-side to `true` (only audited rows).
    public func instagram(
        featured: Bool? = nil,
        vertical: String? = nil,
        limit: Int? = nil
    ) async throws -> InstagramCreatorListResponse {
        var query: [String: String] = [:]
        if let featured { query["featured"] = featured ? "true" : "false" }
        if let vertical { query["vertical"] = vertical }
        if let limit    { query["limit"] = String(limit) }
        return try await client.get("creators/instagram", query: query)
    }
}
