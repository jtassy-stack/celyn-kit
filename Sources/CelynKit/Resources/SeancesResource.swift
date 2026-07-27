import Foundation

public struct SeancesResource: Sendable {
    let client: CultureAPIClient

    public func list(
        venueId: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        radiusKm: Double? = nil,
        from: Date? = nil,
        to: Date? = nil,
        limit: Int? = nil
    ) async throws -> SeanceListResponse {
        var query: [String: String] = [:]
        if let venueId = venueId { query["venue_id"] = venueId }
        if let lat = lat { query["lat"] = String(lat) }
        if let lng = lng { query["lng"] = String(lng) }
        if let r = radiusKm { query["radius_km"] = String(r) }
        if let f = from { query["from"] = ISO8601DateFormatter().string(from: f) }
        if let t = to { query["to"] = ISO8601DateFormatter().string(from: t) }
        if let l = limit { query["limit"] = String(l) }
        return try await client.get("seances", query: query)
    }

    public func get(id: String) async throws -> Seance {
        try await client.get("seances/\(id)")
    }
}
