import Foundation

public struct Venue: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let supabaseId: String?
    public let name: String
    public let address: String?
    public let city: String?
    public let latitude: Double?
    public let longitude: Double?
    public let venueType: VenueType
    public let website: String?
    public let geofenceRadius: Double?
    public let mentionCount: Int

    public init(
        id: String,
        supabaseId: String? = nil,
        name: String,
        address: String? = nil,
        city: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        venueType: VenueType,
        website: String? = nil,
        geofenceRadius: Double? = nil,
        mentionCount: Int = 0
    ) {
        self.id = id
        self.supabaseId = supabaseId
        self.name = name
        self.address = address
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.venueType = venueType
        self.website = website
        self.geofenceRadius = geofenceRadius
        self.mentionCount = mentionCount
    }
}

/// Lightweight venue reference embedded in events.
public struct VenueRef: Codable, Sendable, Equatable {
    public let id: String
    public let supabaseId: String?
    public let name: String
    public let address: String?
    public let city: String?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        id: String,
        supabaseId: String? = nil,
        name: String,
        address: String? = nil,
        city: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.supabaseId = supabaseId
        self.name = name
        self.address = address
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct VenueListResponse: Codable, Sendable {
    public let data: [Venue]
    public let count: Int
}
