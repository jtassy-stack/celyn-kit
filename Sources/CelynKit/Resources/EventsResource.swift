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
        /// Only the events linked to this oeuvre (`oeuvre_id`). Works with or
        /// without `lat`/`lng`: without a location, every upcoming date of the
        /// work (running exhibitions included), ordered by start time.
        public var oeuvreId: String?

        public init(
            lat: Double? = nil,
            lng: Double? = nil,
            radiusKm: Double? = nil,
            from: Date? = nil,
            to: Date? = nil,
            happeningNow: Bool? = nil,
            category: String? = nil,
            limit: Int? = nil,
            oeuvreId: String? = nil
        ) {
            self.lat = lat
            self.lng = lng
            self.radiusKm = radiusKm
            self.from = from
            self.to = to
            self.happeningNow = happeningNow
            self.category = category
            self.limit = limit
            self.oeuvreId = oeuvreId
        }

        /// Query string sent to `GET /events` (snake_case, as the API expects).
        var queryItems: [String: String] {
            var query: [String: String] = [:]
            if let lat { query["lat"] = String(lat) }
            if let lng { query["lng"] = String(lng) }
            if let radiusKm { query["radius_km"] = String(radiusKm) }
            if let from { query["from"] = ISO8601DateFormatter().string(from: from) }
            if let to { query["to"] = ISO8601DateFormatter().string(from: to) }
            if happeningNow == true { query["happening_now"] = "true" }
            if let category { query["category"] = category }
            if let limit { query["limit"] = String(limit) }
            if let oeuvreId, !oeuvreId.isEmpty { query["oeuvre_id"] = oeuvreId }
            return query
        }
    }

    public func list(_ params: ListParams = .init()) async throws -> EventListResponse {
        try await client.get("events", query: params.queryItems)
    }

    public func get(id: String) async throws -> Event {
        try await client.get("events/\(id)")
    }
}
