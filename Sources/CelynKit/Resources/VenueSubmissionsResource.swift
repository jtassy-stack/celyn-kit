import Foundation

/// User-suggested venues pending editorial review.
///
/// Anonymous — `deviceIdHash` is computed on-device from a UUID that
/// resets on reinstall. Used by the server only to rate-limit
/// (5/day/device). See `culture-api`'s `POST /venues/submissions`.
public struct VenueSubmissionsResource: Sendable {
    let client: CultureAPIClient

    /// Categories the picker offers. The free-form `category` column
    /// server-side accepts any string — we keep this enum tight on the
    /// client to constrain the UX; the moderator maps it to the canonical
    /// `VenueType` when promoting an approved submission.
    public enum Category: String, Sendable, CaseIterable, Codable {
        case restaurant
        case bar
        case museum
        case theatre
        case cinema
        case concertHall = "concert_hall"
        case bookshop
        case other

        public var frenchLabel: String {
            switch self {
            case .restaurant:  return "Restaurant"
            case .bar:         return "Bar"
            case .museum:      return "Musée"
            case .theatre:     return "Théâtre"
            case .cinema:      return "Cinéma"
            case .concertHall: return "Salle de concert"
            case .bookshop:    return "Librairie"
            case .other:       return "Autre"
            }
        }
    }

    public struct Submission: Sendable, Encodable {
        public var name: String
        public var category: Category
        public var address: String
        public var lat: Double
        public var lng: Double
        public var description: String?
        public var pressUrl: String?
        public var editorialNote: String?
        public var deviceIdHash: String

        public init(
            name: String,
            category: Category,
            address: String,
            lat: Double,
            lng: Double,
            description: String? = nil,
            pressUrl: String? = nil,
            editorialNote: String? = nil,
            deviceIdHash: String
        ) {
            self.name = name
            self.category = category
            self.address = address
            self.lat = lat
            self.lng = lng
            self.description = description
            self.pressUrl = pressUrl
            self.editorialNote = editorialNote
            self.deviceIdHash = deviceIdHash
        }
    }

    public struct Receipt: Sendable, Decodable {
        public let id: String
        public let status: String
    }

    /// Posts a venue suggestion. On success returns the server-assigned id
    /// and the row's initial status (`"pending"`). On rate-limit the
    /// client receives a 429 — surfaced as `CultureAPIError.httpError` with
    /// statusCode 429 so callers can render a French "Réessayez plus tard"
    /// hint without parsing the body shape.
    public func submit(_ submission: Submission) async throws -> Receipt {
        try await client.post("venues/submissions", body: submission)
    }
}
