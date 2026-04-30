import Foundation

public struct VenuesResource: Sendable {
    let client: CultureAPIClient

    public struct ListParams: Sendable {
        public var lat: Double?
        public var lng: Double?
        public var radiusKm: Double?
        public var city: String?
        public var venueType: VenueType?
        public var hasMentions: Bool?
        public var limit: Int?

        public init(
            lat: Double? = nil,
            lng: Double? = nil,
            radiusKm: Double? = nil,
            city: String? = nil,
            venueType: VenueType? = nil,
            hasMentions: Bool? = nil,
            limit: Int? = nil
        ) {
            self.lat = lat
            self.lng = lng
            self.radiusKm = radiusKm
            self.city = city
            self.venueType = venueType
            self.hasMentions = hasMentions
            self.limit = limit
        }
    }

    public func list(_ params: ListParams = .init()) async throws -> VenueListResponse {
        var query: [String: String] = [:]
        if let lat = params.lat { query["lat"] = String(lat) }
        if let lng = params.lng { query["lng"] = String(lng) }
        if let r = params.radiusKm { query["radius_km"] = String(r) }
        if let c = params.city { query["city"] = c }
        if let t = params.venueType { query["venue_type"] = t.rawValue }
        if params.hasMentions == true { query["has_mentions"] = "true" }
        if let l = params.limit { query["limit"] = String(l) }
        return try await client.get("venues", query: query)
    }

    public func get(id: String) async throws -> Venue {
        try await client.get("venues/\(id)")
    }
}
