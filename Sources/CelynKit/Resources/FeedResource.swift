import Foundation

public struct FeedResource: Sendable {
    let client: CultureAPIClient

    /// "Le Fil" editorial feed, via the curation scorer. Geo-aware: pass the
    /// user's coordinates so the feed favours objects with events near them.
    public func list(
        lat: Double? = nil,
        lng: Double? = nil,
        radiusKm: Double? = nil,
        limit: Int? = nil
    ) async throws -> CurationFeedResponse {
        var query: [String: String] = [:]
        if let lat { query["lat"] = String(lat) }
        if let lng { query["lng"] = String(lng) }
        if let radiusKm { query["radius_km"] = String(radiusKm) }
        if let limit { query["limit"] = String(limit) }
        return try await client.get("curation/feed", query: query)
    }
}
