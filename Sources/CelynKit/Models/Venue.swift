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

public extension VenueRef {
    /// Promote a lightweight reference to a full Venue using only the fields
    /// available on the ref. `venueType` isn't carried by `VenueRef` at all,
    /// so callers must supply it — `.cinema` is right for every current call
    /// site (cinema showtime groupings), but this is NOT a safe silent
    /// default for a future caller with a different venue kind.
    /// `website`/`geofenceRadius`/`mentionCount` are missing too — fine for a
    /// detail sheet that re-fetches the full `Venue` on appear and only uses
    /// this to seed the header before that resolves.
    func asVenue(venueType: VenueType) -> Venue {
        Venue(
            id: id,
            supabaseId: supabaseId,
            name: name,
            address: address,
            city: city,
            latitude: latitude,
            longitude: longitude,
            venueType: venueType
        )
    }
}
