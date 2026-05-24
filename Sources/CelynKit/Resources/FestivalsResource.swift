import Foundation

public struct FestivalsResource: Sendable {
    let client: CultureAPIClient

    /// Filter set kept for forward-compat with the original spec — culture-api
    /// today honours only `limit` on `GET /api/festivals` (it always returns
    /// upcoming editions, no geo/vertical filtering yet). The remaining
    /// params are sent transparently so the iOS call sites don't need to
    /// change once server support lands.
    public struct ListParams: Sendable {
        public var lat: Double?
        public var lng: Double?
        public var radiusKm: Double?
        public var from: Date?
        public var to: Date?
        public var vertical: FestivalVertical?
        public var featured: Bool?
        public var city: String?
        public var limit: Int?
        public var includePast: Bool?

        public init(
            lat: Double? = nil,
            lng: Double? = nil,
            radiusKm: Double? = nil,
            from: Date? = nil,
            to: Date? = nil,
            vertical: FestivalVertical? = nil,
            featured: Bool? = nil,
            city: String? = nil,
            limit: Int? = nil,
            includePast: Bool? = nil
        ) {
            self.lat = lat
            self.lng = lng
            self.radiusKm = radiusKm
            self.from = from
            self.to = to
            self.vertical = vertical
            self.featured = featured
            self.city = city
            self.limit = limit
            self.includePast = includePast
        }
    }

    public func list(_ params: ListParams = .init()) async throws -> FestivalListResponse {
        var query: [String: String] = [:]
        if let lat = params.lat { query["lat"] = String(lat) }
        if let lng = params.lng { query["lng"] = String(lng) }
        if let r = params.radiusKm { query["radius_km"] = String(r) }
        if let f = params.from { query["from"] = ISO8601DateFormatter().string(from: f) }
        if let t = params.to { query["to"] = ISO8601DateFormatter().string(from: t) }
        if let v = params.vertical { query["vertical"] = v.rawValue }
        if let f = params.featured { query["featured"] = f ? "true" : "false" }
        if let c = params.city { query["city"] = c }
        if let l = params.limit { query["limit"] = String(l) }
        if params.includePast == true { query["include_past"] = "true" }
        return try await client.get("festivals", query: query)
    }

    /// Fetches festival detail by edition id (UUID). The server splits the
    /// detail across `GET /festivals/:editionId/lineup` (festival fields +
    /// lineup grid) and `GET /festivals/:editionId/events` (programme stream
    /// for festivals fed by the events bridge — Feria de Dax, Bayonne…). We
    /// fan both out in parallel and assemble `FestivalDetail` client-side.
    public func getDetail(editionId: String) async throws -> FestivalDetail {
        async let lineup: LineupEnvelope = client.get("festivals/\(editionId)/lineup")
        async let events: EventsEnvelope = client.get("festivals/\(editionId)/events")
        let (l, e) = try await (lineup, events)
        let ref = FestivalRef(
            id: l.edition.id,
            name: l.edition.name,
            slug: l.edition.slug,
            imageUrl: l.edition.imageUrl,
            startsAt: l.edition.startsAt,
            endsAt: l.edition.endsAt
        )
        let richEvents = e.events.map { $0.toEvent(festivalRef: ref) }
        return FestivalDetail(festival: l.edition, events: richEvents)
    }

    /// Backward-compat: when `idOrSlug` is a UUID, route to `getDetail`.
    /// Slugs are not supported by the server today and would 404.
    @available(*, deprecated, message: "Use getDetail(editionId:) — slug routing is not implemented server-side.")
    public func get(idOrSlug: String) async throws -> FestivalDetail {
        try await getDetail(editionId: idOrSlug)
    }
}

// MARK: - Wire envelopes (internal to the resource)

/// Server payload of `GET /festivals/:editionId/lineup`. `edition` decodes
/// as a Festival via the custom decoder (server keys → canonical shape).
/// `stages` and `entries` are present on the wire but not consumed yet —
/// `FestivalDetailView` reads programme stats from the events array.
private struct LineupEnvelope: Decodable, Sendable {
    let edition: Festival
}

/// Server payload of `GET /festivals/:editionId/events`. The shape is flat
/// (`venueName`/`venueCity`/…) rather than the rich `Event` shape used by
/// `/api/events` — see `FestivalEventLite`.
private struct EventsEnvelope: Decodable, Sendable {
    let events: [FestivalEventLite]
}

/// Reflects exactly what `GET /api/festivals/:editionId/events` returns
/// today: a compact event row with flat venue fields. Distinct from `Event`
/// so the shape difference is honest at the type level — `FestivalDetailView`
/// reads only what's actually shipped.
public struct FestivalEventLite: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let category: String
    public let description: String?
    public let imageUrl: String?
    public let sourceUrl: String?
    public let ticketUrl: String?
    public let startTime: Date
    public let endTime: Date?
    public let price: Double?
    public let isFree: Int?
    public let venueId: String?
    public let venueName: String?
    public let venueCity: String?
    public let venueLat: Double?
    public let venueLng: Double?
}

public extension FestivalEventLite {
    /// Maps the lite shape onto Event so `FestivalDetail.events` stays
    /// `[Event]` and `FestivalDetailView` doesn't need a parallel codepath.
    /// Drops fields the lite shape doesn't carry (`isSoldOut`, `topics`,
    /// `oeuvre`, …); the synthesised inline VenueRef has no address or
    /// supabaseId since the route doesn't ship them.
    func toEvent(festivalRef: FestivalRef?) -> Event {
        let venue: VenueRef? = venueId.map { id in
            VenueRef(
                id: id,
                name: venueName ?? "",
                city: venueCity,
                latitude: venueLat,
                longitude: venueLng
            )
        }
        return Event(
            id: id,
            title: title,
            category: category,
            description: description,
            imageUrl: imageUrl,
            sourceUrl: sourceUrl,
            ticketUrl: ticketUrl,
            startTime: startTime,
            endTime: endTime,
            price: price,
            isFree: isFree,
            venue: venue,
            festivalEditionId: festivalRef?.id,
            festival: festivalRef
        )
    }
}
