import Foundation

public struct EventsResource: Sendable {
    let client: CultureAPIClient

    public struct ListParams: Sendable {
        public var lat: Double?
        public var lng: Double?
        public var radiusKm: Double?
        public var from: Date?
        public var to: Date?
        public var happeningNow: Bool?
        public var category: String?
        public var limit: Int?

        public init(
            lat: Double? = nil,
            lng: Double? = nil,
            radiusKm: Double? = nil,
            from: Date? = nil,
            to: Date? = nil,
            happeningNow: Bool? = nil,
            category: String? = nil,
            limit: Int? = nil
        ) {
            self.lat = lat
            self.lng = lng
            self.radiusKm = radiusKm
            self.from = from
            self.to = to
            self.happeningNow = happeningNow
            self.category = category
            self.limit = limit
        }
    }

    public func list(_ params: ListParams = .init()) async throws -> EventListResponse {
        var query: [String: String] = [:]
        if let lat = params.lat { query["lat"] = String(lat) }
        if let lng = params.lng { query["lng"] = String(lng) }
        if let r = params.radiusKm { query["radius_km"] = String(r) }
        if let f = params.from { query["from"] = ISO8601DateFormatter().string(from: f) }
        if let t = params.to { query["to"] = ISO8601DateFormatter().string(from: t) }
        if params.happeningNow == true { query["happening_now"] = "true" }
        if let c = params.category { query["category"] = c }
        if let l = params.limit { query["limit"] = String(l) }
        return try await client.get("events", query: query)
    }

    public func get(id: String) async throws -> Event {
        try await client.get("events/\(id)")
    }
}
