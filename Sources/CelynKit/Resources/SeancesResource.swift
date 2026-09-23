import Foundation

public struct SeancesResource: Sendable {
    let client: CultureAPIClient

    /// - Parameter oeuvreId: restrict to screenings of one œuvre
    ///   ("où le voir"). Maps to `oeuvre_id`.
    public func list(
        venueId: String? = nil,
        oeuvreId: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        radiusKm: Double? = nil,
        from: Date? = nil,
        to: Date? = nil,
        limit: Int? = nil
    ) async throws -> SeanceListResponse {
        let query = Self.listQuery(
            venueId: venueId, oeuvreId: oeuvreId, lat: lat, lng: lng,
            radiusKm: radiusKm, from: from, to: to, limit: limit
        )
        return try await client.get("seances", query: query)
    }

    static func listQuery(
        venueId: String? = nil,
        oeuvreId: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        radiusKm: Double? = nil,
        from: Date? = nil,
        to: Date? = nil,
        limit: Int? = nil
    ) -> [String: String] {
        var query: [String: String] = [:]
        if let venueId = venueId { query["venue_id"] = venueId }
        if let oeuvreId = oeuvreId { query["oeuvre_id"] = oeuvreId }
        if let lat = lat { query["lat"] = String(lat) }
        if let lng = lng { query["lng"] = String(lng) }
        if let r = radiusKm { query["radius_km"] = String(r) }
        if let f = from { query["from"] = ISO8601DateFormatter().string(from: f) }
        if let t = to { query["to"] = ISO8601DateFormatter().string(from: t) }
        if let l = limit { query["limit"] = String(l) }
        return query
    }

    public func get(id: String) async throws -> Seance {
        try await client.get("seances/\(id)")
    }
}
