import Foundation

/// One entry in the subscribable curator catalogue (`GET /curation/sources`) —
/// podcasts, Instagram/social accounts, venue-agenda feeds, or venue-linked
/// sources, whatever the server has an active `signal_sources` row for.
public struct CuratedSource: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let showName: String?
    public let station: String?
    public let sourceType: String
    public let category: String?
    public let city: String?
    public let imageUrl: String?
    public let featured: Bool?
    public let venueId: String?
    public let tier: String?
    public let credibilityScore: Double?

    public init(
        id: String,
        name: String,
        showName: String? = nil,
        station: String? = nil,
        sourceType: String,
        category: String? = nil,
        city: String? = nil,
        imageUrl: String? = nil,
        featured: Bool? = nil,
        venueId: String? = nil,
        tier: String? = nil,
        credibilityScore: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.showName = showName
        self.station = station
        self.sourceType = sourceType
        self.category = category
        self.city = city
        self.imageUrl = imageUrl
        self.featured = featured
        self.venueId = venueId
        self.tier = tier
        self.credibilityScore = credibilityScore
    }
}

public struct CuratedSourceListResponse: Codable, Sendable {
    public let data: [CuratedSource]
    public let count: Int
}
