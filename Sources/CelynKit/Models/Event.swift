import Foundation

/// API-shaped event DTO. App-specific event types should be mapped from this
/// rather than decoded directly — keeps the wire format isolated.
public struct Event: Identifiable, Codable, Sendable, Equatable {
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
    /// Flags arrive as `0` / `1` ints from the API. `nil` when omitted.
    public let isFree: Int?
    public let isSoldOut: Int?
    public let isActive: Int
    public let buyUrl: String?
    public let ageMin: Int?
    public let ageMax: Int?
    public let topics: [String]?
    public let venue: VenueRef?
    public let oeuvre: OeuvreRef?
    /// Authoritative server hint (see `Oeuvre.isKidFriendly`). `false`
    /// explicitly vetoes the heuristic — needed because some adult concerts
    /// arrive tagged with "scolaire" or "famille" topics by mistake.
    public let isKidFriendly: Bool?
    /// FK to the parent festival *edition* (i.e. one year of a festival —
    /// Cannes 2026, not the abstract "Cannes" oeuvre) when this event is
    /// part of a multi-day cluster. `nil` for autonomous events. The
    /// matching `FestivalRef` is also inlined as `festival` to avoid a
    /// second fetch on list surfaces.
    public let festivalEditionId: String?
    /// Lightweight festival reference. Present iff `festivalEditionId` is non-nil.
    public let festival: FestivalRef?

    public init(
        id: String,
        title: String,
        category: String,
        description: String? = nil,
        imageUrl: String? = nil,
        sourceUrl: String? = nil,
        ticketUrl: String? = nil,
        startTime: Date,
        endTime: Date? = nil,
        price: Double? = nil,
        isFree: Int? = nil,
        isSoldOut: Int? = nil,
        isActive: Int = 1,
        buyUrl: String? = nil,
        ageMin: Int? = nil,
        ageMax: Int? = nil,
        topics: [String]? = nil,
        venue: VenueRef? = nil,
        oeuvre: OeuvreRef? = nil,
        isKidFriendly: Bool? = nil,
        festivalEditionId: String? = nil,
        festival: FestivalRef? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.description = description
        self.imageUrl = imageUrl
        self.sourceUrl = sourceUrl
        self.ticketUrl = ticketUrl
        self.startTime = startTime
        self.endTime = endTime
        self.price = price
        self.isFree = isFree
        self.isSoldOut = isSoldOut
        self.isActive = isActive
        self.buyUrl = buyUrl
        self.ageMin = ageMin
        self.ageMax = ageMax
        self.topics = topics
        self.venue = venue
        self.oeuvre = oeuvre
        self.isKidFriendly = isKidFriendly
        self.festivalEditionId = festivalEditionId
        self.festival = festival
    }
}

public struct EventListResponse: Codable, Sendable {
    public let data: [Event]
    public let count: Int
}

public extension Event {
    /// Convenience: API ships 0/1 ints; this projects to a Swift Bool.
    var isFreeBool: Bool { (isFree ?? 0) == 1 }
    var isSoldOutBool: Bool { (isSoldOut ?? 0) == 1 }
    var isActiveBool: Bool { isActive == 1 }

    /// True when the event is tagged for children or school programmes.
    ///
    /// Two-step gate (same model as `Oeuvre.effectiveIsKidFriendly`):
    /// 1. Honour the explicit server hint (`isKidFriendly`) when present —
    ///    `false` is an authoritative veto.
    /// 2. Otherwise fall back to the on-device heuristic on topics + age cap.
    var effectiveIsKidFriendly: Bool {
        if let server = isKidFriendly { return server }
        // Concert events inherit the same unreliable kid-tagging seen on rap
        // albums — skip the badge for music to avoid an "Enfants" label next
        // to explicit-content artists.
        let cat = category.lowercased()
        if cat == "concert" || cat == "concerts" || cat == "music" || cat == "musique" {
            return false
        }
        let kidTopics: Set<String> = ["scolaire", "programme scolaire", "enfants", "famille", "jeunesse", "kids", "family"]
        if let topics, topics.contains(where: { kidTopics.contains($0.lowercased()) }) { return true }
        if let max = ageMax, max <= 12 { return true }
        return false
    }
}
