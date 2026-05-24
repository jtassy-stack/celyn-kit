import Foundation

/// A multi-day editorial cluster of events — Rock en Seine, FIAC, Festival
/// d'Avignon… Maps culture-api's `festival_editions` row 1:1 (i.e. one
/// Festival = one year of a parent festival oeuvre — Cannes 2026 and
/// Cannes 2027 are two distinct Festivals).
///
/// A Festival is the parent entity; Events carry a nullable
/// `festivalEditionId` pointing back. Client surfaces (Sommaire, Carte,
/// EventDetail) use the link to collapse N child events into a single
/// editorial unit.
///
/// The decoder reads culture-api's edition shape (`editionId`,
/// `festivalTitle`, `startDate`, `siteCenterLat`, …) and remaps it onto the
/// canonical model. Editorial fields the server doesn't surface yet
/// (`vertical`, `isFeatured`, `mentionCount`, `curatedNote`, `posterUrl`,
/// `eventCount`) decode via `decodeIfPresent` with defaults — forward
/// compatible the day the API ships them.
public struct Festival: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let supabaseId: String?
    public let name: String
    public let slug: String
    public let description: String?
    public let imageUrl: String?
    public let posterUrl: String?
    public let sourceUrl: String?
    public let startsAt: Date
    public let endsAt: Date
    public let latitude: Double?
    public let longitude: Double?
    public let city: String?
    public let vertical: FestivalVertical
    public let isFeatured: Bool
    public let mentionCount: Int
    public let curatedNote: String?
    /// Count of child events. Computed server-side. May be 0 if the festival
    /// is referenced but has no published events yet.
    public let eventCount: Int

    public init(
        id: String,
        supabaseId: String? = nil,
        name: String,
        slug: String,
        description: String? = nil,
        imageUrl: String? = nil,
        posterUrl: String? = nil,
        sourceUrl: String? = nil,
        startsAt: Date,
        endsAt: Date,
        latitude: Double? = nil,
        longitude: Double? = nil,
        city: String? = nil,
        vertical: FestivalVertical = .mixed,
        isFeatured: Bool = false,
        mentionCount: Int = 0,
        curatedNote: String? = nil,
        eventCount: Int = 0
    ) {
        self.id = id
        self.supabaseId = supabaseId
        self.name = name
        self.slug = slug
        self.description = description
        self.imageUrl = imageUrl
        self.posterUrl = posterUrl
        self.sourceUrl = sourceUrl
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.vertical = vertical
        self.isFeatured = isFeatured
        self.mentionCount = mentionCount
        self.curatedNote = curatedNote
        self.eventCount = eventCount
    }

    /// Maps culture-api's `festival_editions` row shape onto Festival.
    /// Each CodingKey raw value is the server JSON key, NOT the property name.
    private enum CodingKeys: String, CodingKey {
        case id = "editionId"
        case name = "festivalTitle"
        case description = "festivalDescription"
        case imageUrl = "festivalImageUrl"
        case startsAt = "startDate"
        case endsAt = "endDate"
        case latitude = "siteCenterLat"
        case longitude = "siteCenterLng"
        case city
        case sourceUrl
        // Helpers used only to derive `slug` when the server doesn't ship one.
        case festivalId
        case year
        // Forward-compat — server may emit these in a later iteration.
        case slug
        case vertical
        case isFeatured
        case mentionCount
        case curatedNote
        case posterUrl
        case supabaseId
        case eventCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.supabaseId = try c.decodeIfPresent(String.self, forKey: .supabaseId)
        self.name = try c.decode(String.self, forKey: .name)
        // Slug is derived `<parentOeuvreId>-<year>` when absent — gives stable
        // deep-link tokens without requiring a DB column on culture-api.
        if let explicit = try c.decodeIfPresent(String.self, forKey: .slug) {
            self.slug = explicit
        } else {
            let parentId = try c.decodeIfPresent(String.self, forKey: .festivalId)
            let year = try c.decodeIfPresent(Int.self, forKey: .year)
            switch (parentId, year) {
            case let (.some(p), .some(y)): self.slug = "\(p)-\(y)"
            case let (.some(p), .none):    self.slug = p
            default:                       self.slug = self.id
            }
        }
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        self.posterUrl = try c.decodeIfPresent(String.self, forKey: .posterUrl)
        self.sourceUrl = try c.decodeIfPresent(String.self, forKey: .sourceUrl)
        self.startsAt = try c.decode(Date.self, forKey: .startsAt)
        self.endsAt = try c.decode(Date.self, forKey: .endsAt)
        self.latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        self.city = try c.decodeIfPresent(String.self, forKey: .city)
        self.vertical = try c.decodeIfPresent(FestivalVertical.self, forKey: .vertical) ?? .mixed
        self.isFeatured = try c.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        self.mentionCount = try c.decodeIfPresent(Int.self, forKey: .mentionCount) ?? 0
        self.curatedNote = try c.decodeIfPresent(String.self, forKey: .curatedNote)
        self.eventCount = try c.decodeIfPresent(Int.self, forKey: .eventCount) ?? 0
    }

    /// Encoding round-trips into the *server* shape (editionId/festivalTitle/…)
    /// for parity. Not used on the wire today — the API is read-only for
    /// festivals — but kept symmetric for tests and snapshot fixtures.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(supabaseId, forKey: .supabaseId)
        try c.encode(name, forKey: .name)
        try c.encode(slug, forKey: .slug)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try c.encodeIfPresent(posterUrl, forKey: .posterUrl)
        try c.encodeIfPresent(sourceUrl, forKey: .sourceUrl)
        try c.encode(startsAt, forKey: .startsAt)
        try c.encode(endsAt, forKey: .endsAt)
        try c.encodeIfPresent(latitude, forKey: .latitude)
        try c.encodeIfPresent(longitude, forKey: .longitude)
        try c.encodeIfPresent(city, forKey: .city)
        try c.encode(vertical, forKey: .vertical)
        try c.encode(isFeatured, forKey: .isFeatured)
        try c.encode(mentionCount, forKey: .mentionCount)
        try c.encodeIfPresent(curatedNote, forKey: .curatedNote)
        try c.encode(eventCount, forKey: .eventCount)
    }
}

/// Qualifies the dominant nature of the festival. Drives the editorial ink
/// (cf. KKTypology) so the Sommaire card colour matches the cluster's vibe.
public enum FestivalVertical: String, Codable, Sendable, CaseIterable {
    case music
    case art
    case cinema
    case theatre
    case literature
    case food
    case mixed

    /// Unknown values decode to `.mixed` rather than failing — same
    /// resilience pattern as the other CelynKit enums.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FestivalVertical(rawValue: raw) ?? .mixed
    }

    /// Maps to the typology family used for ink selection. Lets the
    /// Sommaire card and Carte pin reuse `KKTypology`'s palette without
    /// duplicating the colour logic.
    public var apiCategory: String {
        switch self {
        case .music:       return "concerts"
        case .art:         return "expos"
        case .cinema:      return "cinema"
        case .theatre:     return "theatre"
        case .literature:  return "livres"
        case .food:        return "restos"
        case .mixed:       return "festival"
        }
    }
}

/// Lightweight festival reference embedded inline on events
/// (`Event.festival`). Lets the client know an event belongs to a parent
/// festival edition without a second fetch.
///
/// `slug` is optional — the server's inline ref carries only id/name/
/// imageUrl/startsAt/endsAt; `slug` would only appear if a future API
/// iteration ships it.
public struct FestivalRef: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let slug: String?
    public let imageUrl: String?
    public let startsAt: Date
    public let endsAt: Date

    public init(
        id: String,
        name: String,
        slug: String? = nil,
        imageUrl: String? = nil,
        startsAt: Date,
        endsAt: Date
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.imageUrl = imageUrl
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
}

/// Wraps `GET /api/festivals`. The server returns `{ editions: [...] }`
/// (no count field); the decoder exposes the array under the canonical
/// `data` accessor for parity with other list responses.
public struct FestivalListResponse: Codable, Sendable {
    public let data: [Festival]
    public var count: Int { data.count }

    private enum CodingKeys: String, CodingKey {
        case data = "editions"
    }

    public init(data: [Festival]) {
        self.data = data
    }
}

/// Full festival detail response — includes the child events inline so a
/// single fetch hydrates the whole detail screen (no pagination needed; a
/// festival never has thousands of events).
public struct FestivalDetail: Codable, Sendable {
    public let festival: Festival
    public let events: [Event]

    private enum CodingKeys: String, CodingKey {
        case events
    }

    public init(from decoder: Decoder) throws {
        // The endpoint returns a flat shape: festival fields + `events` array.
        // Decode the Festival from the same container, then pull events separately.
        self.festival = try Festival(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.events = try c.decodeIfPresent([Event].self, forKey: .events) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        try festival.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(events, forKey: .events)
    }

    public init(festival: Festival, events: [Event] = []) {
        self.festival = festival
        self.events = events
    }
}

public extension Festival {
    /// Human window string, dispatcher-style. "26—30 août" or "12 juillet—4
    /// août" depending on whether the festival spans a single month.
    var windowLabel: String {
        let cal = Calendar.current
        let sameMonth = cal.isDate(startsAt, equalTo: endsAt, toGranularity: .month)
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        if sameMonth {
            let day = DateFormatter(); day.locale = Locale(identifier: "fr_FR"); day.dateFormat = "d"
            let month = DateFormatter(); month.locale = Locale(identifier: "fr_FR"); month.dateFormat = "MMMM"
            return "\(day.string(from: startsAt))–\(day.string(from: endsAt)) \(month.string(from: endsAt))"
        }
        f.dateFormat = "d MMM"
        return "\(f.string(from: startsAt))–\(f.string(from: endsAt))"
    }

    /// True when the festival window contains `date`. Used to know whether
    /// a Sommaire row should surface the festival card vs an autonomous event.
    func contains(_ date: Date) -> Bool {
        date >= startsAt && date <= endsAt
    }

    /// True when the festival hasn't yet started.
    var isUpcoming: Bool { startsAt > Date() }

    /// True when the festival is currently happening.
    var isOngoing: Bool {
        let now = Date()
        return now >= startsAt && now <= endsAt
    }
}
